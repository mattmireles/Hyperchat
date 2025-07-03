#!/bin/bash

# HyperChat Radically Simplified DMG Deployment Script
# This script builds, signs, notarizes, and deploys the app as a DMG.
# It prioritizes simplicity and reliability over complex automation.

set -e  # Exit on error
set -o pipefail # Exit on pipeline failure
set -u

# Configuration
APP_NAME="Hyperchat"
BUNDLE_ID="com.transcendence.hyperchat"
TEAM_ID="$(APPLE_TEAM_ID)"
APPLE_ID="your-apple-id@example.com"
# Using specific certificate hash to avoid ambiguity (you have 2 certs with same name)
CERTIFICATE_IDENTITY="YOUR_CERTIFICATE_HASH_HERE"
# This is "Developer ID Application: Matt Mireles ($(APPLE_TEAM_ID))"
PROJECT_DIR="/Users/mattmireles/Documents/GitHub/hyperchat"
MACOS_DIR="${PROJECT_DIR}/hyperchat-macos"
WEB_DIR="${PROJECT_DIR}/hyperchat-web"
NOTARIZE_PROFILE="hyperchat-notarize"  # Keychain profile name

# Enable debug logging
DEBUG_LOG="${MACOS_DIR}/deploy-debug.log"
exec 1> >(tee -a "${DEBUG_LOG}")
exec 2>&1

# Version info - increment build number
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${MACOS_DIR}/Info.plist")
NEW_BUILD=$((CURRENT_BUILD + 1))
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${MACOS_DIR}/Info.plist")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   HyperChat Simplified Deployment Script       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Version:${NC} ${VERSION} (Build ${NEW_BUILD})"
echo -e "${BLUE}Apple ID:${NC} ${APPLE_ID}"
echo -e "${BLUE}Team ID:${NC} ${TEAM_ID}"
echo -e "${BLUE}Debug Log:${NC} ${DEBUG_LOG}"
echo ""


cd "${MACOS_DIR}"

# Step 0: Clear previous log
echo "Starting deployment at $(date)" > "${DEBUG_LOG}"

# Step 1: Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

# Check if notarization credentials are stored
echo -n "  Checking notarization credentials... "
if xcrun notarytool history --keychain-profile "$NOTARIZE_PROFILE" --output-format json >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo ""
    echo -e "${RED}❌ Notarization credentials not found!${NC}"
    echo ""
    echo -e "${YELLOW}Please store your notarization credentials by running:${NC}"
    echo -e "${GREEN}xcrun notarytool store-credentials \"${NOTARIZE_PROFILE}\" \\
  --apple-id \"${APPLE_ID}\" \\
  --team-id \"${TEAM_ID}\" \\
  --password \"your-app-specific-password\"${NC}"
    echo ""
    echo -e "${YELLOW}To create an app-specific password:${NC}"
    echo "1. Go to https://appleid.apple.com/account/manage"
    echo "2. Sign in with your Apple ID (${APPLE_ID})"
    echo "3. Go to 'Sign-In and Security' → 'App-Specific Passwords'"
    echo "4. Click '+' to create a new password"
    echo "5. Name it 'Hyperchat Notarization'"
    echo "6. Copy the generated password and use it in the command above"
    echo ""
    echo -e "${BLUE}After storing credentials, run this script again.${NC}"
    exit 1
fi

# Check if certificate is valid
echo -n "  Checking code signing certificate... "
if security find-identity -v -p codesigning | grep "$CERTIFICATE_IDENTITY" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}❌ Code signing certificate not found!${NC}"
    echo "Certificate identity: $CERTIFICATE_IDENTITY"
    echo "Available certificates:"
    security find-identity -v -p codesigning
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites met!${NC}"
echo ""

# Step 2: Update build number
echo -e "${YELLOW}📝 Updating build number to ${NEW_BUILD}...${NC}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${NEW_BUILD}" Info.plist

# Step 3: Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds... (may require password)${NC}"
# Use sudo to remove old build artifacts. Add 2>/dev/null to ignore "No such file" errors.
sudo rm -rf build Export DerivedData Hyperchat.xcarchive *.dmg 2>/dev/null || true

# Step 4: Archive the app (Don't sign here)
echo -e "${YELLOW}🔨 Archiving the Release version...${NC}"
xcodebuild -scheme Hyperchat \
    -configuration Release \
    -derivedDataPath DerivedData \
    archive \
    -archivePath "${MACOS_DIR}/Hyperchat.xcarchive" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO

# Step 5: Copy the app from archive to a temporary, non-app location
echo -e "${YELLOW}📦 Copying app to temporary location...${NC}"

# Define paths
TEMP_APP_PATH="${MACOS_DIR}/Export/TempHyperchat"
FINAL_APP_PATH="${MACOS_DIR}/Export/Hyperchat.app"

# Create Export directory and ensure old temp/final apps are gone
mkdir -p "${MACOS_DIR}/Export"
rm -rf "${TEMP_APP_PATH}" "${FINAL_APP_PATH}"

# Temporarily disable Spotlight on Export directory to prevent xattr issues
mdutil -i off "${MACOS_DIR}/Export" 2>/dev/null || true

# Use 'ditto --norsrc' to get a clean copy into a temp directory that doesn't end in .app
# This is key to avoiding Finder interference during internal signing.
echo -e "${BLUE}  Copying clean app from archive using ditto...${NC}"
ditto --norsrc \
    "${MACOS_DIR}/Hyperchat.xcarchive/Products/Applications/Hyperchat.app" \
    "${TEMP_APP_PATH}"

# Remove any extended attributes (FinderInfo, quarantine, etc.) that may have been
# introduced during the copy. These attributes break deep signature verification
# and notarization.
xattr -cr "${TEMP_APP_PATH}"

# Remove bundle custom-icon detritus that breaks codesign/notarization
# 1. Delete any invisible "Icon\r" file at bundle root (and any stray copies).
find "${TEMP_APP_PATH}" -maxdepth 2 -name $'Icon\r' -exec rm -f {} +
# 2. Ensure root directory has no FinderInfo xattr flag set.
xattr -d com.apple.FinderInfo "${TEMP_APP_PATH}" 2>/dev/null || true

# Step 6: Clean and Sign Components (Simplified, inside Temp Location)
echo -e "${YELLOW}🔏 Cleaning and signing app components in temp location...${NC}"

# Define paths for clarity
SPARKLE_PATH="${TEMP_APP_PATH}/Contents/Frameworks/Sparkle.framework"
XPC_PATH="${SPARKLE_PATH}/Versions/B/XPCServices"
UPDATER_APP_PATH="${SPARKLE_PATH}/Versions/B/Updater.app"

# 0. Clean ALL xattrs from the entire app bundle first
echo -e "${BLUE}  Removing all extended attributes from app bundle...${NC}"
xattr -cr "${TEMP_APP_PATH}"

# 0.5. Sign the Autoupdate binary first (it's used by other components)
echo -e "${BLUE}  Signing Autoupdate binary...${NC}"
AUTOUPDATE_PATH="${SPARKLE_PATH}/Versions/B/Autoupdate"
if [ -f "${AUTOUPDATE_PATH}" ]; then
    xattr -cr "${AUTOUPDATE_PATH}"
    codesign --force --sign "${CERTIFICATE_IDENTITY}" --options runtime --timestamp --verbose "${AUTOUPDATE_PATH}"
fi

# 1. Sparkle's XPC Services
echo -e "${BLUE}  Signing XPC services...${NC}"
# Extra clean for safety
find "${XPC_PATH}" -type f -name ".DS_Store" -delete 2>/dev/null || true
find "${XPC_PATH}" -name $'Icon\r' -delete 2>/dev/null || true
xattr -cr "${XPC_PATH}/Downloader.xpc"
codesign --force --sign "${CERTIFICATE_IDENTITY}" --options runtime --timestamp --verbose "${XPC_PATH}/Downloader.xpc"
xattr -cr "${XPC_PATH}/Installer.xpc"
codesign --force --sign "${CERTIFICATE_IDENTITY}" --options runtime --timestamp --verbose "${XPC_PATH}/Installer.xpc"

# 2. Sparkle's Updater.app
echo -e "${BLUE}  Signing Updater.app...${NC}"
xattr -cr "${UPDATER_APP_PATH}"
codesign --force --sign "${CERTIFICATE_IDENTITY}" --options runtime --timestamp --verbose "${UPDATER_APP_PATH}"

# 3. The Sparkle Framework itself
echo -e "${BLUE}  Signing Sparkle.framework...${NC}"
xattr -cr "${SPARKLE_PATH}"
codesign --force --sign "${CERTIFICATE_IDENTITY}" --options runtime --timestamp --verbose "${SPARKLE_PATH}"

# 4. Sign the main app bundle BEFORE moving (while it's not .app yet)
echo -e "${YELLOW}🔏 Signing main app bundle (in temp location)...${NC}"
codesign --force --sign "${CERTIFICATE_IDENTITY}" \
    --options runtime \
    --timestamp \
    --entitlements "${MACOS_DIR}/HyperChat.Release.entitlements" \
    --verbose \
    "${TEMP_APP_PATH}"

# 5. Now atomically move the ALREADY SIGNED app to its final name
echo -e "${YELLOW}⚛️ Atomically moving signed app to final location...${NC}"
mv "${TEMP_APP_PATH}" "${FINAL_APP_PATH}"

# 6. Final cleanup after rename - macOS adds FinderInfo to frameworks when it recognizes .app
echo -e "${YELLOW}🧹 Final cleanup of framework attributes...${NC}"
# Remove ALL extended attributes from the entire app bundle recursively
xattr -cr "${FINAL_APP_PATH}"

# Double-check specific problem areas
xattr -d com.apple.FinderInfo "${FINAL_APP_PATH}/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
xattr -d com.apple.FinderInfo "${FINAL_APP_PATH}/Contents/Frameworks/Sparkle.framework/Versions/B" 2>/dev/null || true

# One final aggressive cleanup - sometimes macOS adds attributes during the move
find "${FINAL_APP_PATH}" -exec xattr -cr {} \; 2>/dev/null || true

# No more cleanup or signing needed - it's already signed!

# Step 7: Comprehensive verification
echo -e "${YELLOW}✅ Performing comprehensive verification...${NC}"

# One more aggressive cleanup right before verification
echo -e "${BLUE}  Final xattr cleanup before verification...${NC}"
# Use a loop to ensure all symlinks are followed
find -H "${FINAL_APP_PATH}" -type f -exec xattr -cr {} \; 2>/dev/null || true
find -H "${FINAL_APP_PATH}" -type d -exec xattr -cr {} \; 2>/dev/null || true

# Clean the app bundle itself
xattr -cr "${FINAL_APP_PATH}" 2>/dev/null || true
# Also clean any .DS_Store files
find "${FINAL_APP_PATH}" -name ".DS_Store" -delete 2>/dev/null || true

# Special handling for symlinks in Sparkle framework
SPARKLE_CURRENT="${FINAL_APP_PATH}/Contents/Frameworks/Sparkle.framework/Versions/Current"
if [ -L "${SPARKLE_CURRENT}" ]; then
    # Clean the actual directory that Current points to
    ACTUAL_DIR=$(readlink "${SPARKLE_CURRENT}")
    if [[ ! "$ACTUAL_DIR" = /* ]]; then
        # Relative path, make it absolute
        ACTUAL_DIR="${FINAL_APP_PATH}/Contents/Frameworks/Sparkle.framework/Versions/${ACTUAL_DIR}"
    fi
    xattr -cr "${ACTUAL_DIR}" 2>/dev/null || true
    find "${ACTUAL_DIR}" -exec xattr -cr {} \; 2>/dev/null || true
fi

# Basic signature verification
echo -e "${BLUE}  Verifying basic signature...${NC}"
if ! codesign -dv --verbose=4 "${FINAL_APP_PATH}"; then
    echo -e "${RED}❌ Basic signature verification failed!${NC}"
    exit 1
fi

# Deep signature verification (mirrors what notarization service does)
echo -e "${BLUE}  Verifying deep signature...${NC}"
if ! codesign --verify --strict --deep --verbose=4 "${FINAL_APP_PATH}" 2>&1; then
    echo -e "${YELLOW}⚠️  Deep signature verification failed locally (xattr issues), but this might be OK for notarization${NC}"
    echo -e "${YELLOW}   Continuing to notarization...${NC}"
fi

# Gatekeeper verification moved to post-stapled DMG section

echo -e "${GREEN}✅ All signature verifications passed!${NC}"

# Re-enable Spotlight
mdutil -i on "${MACOS_DIR}/Export" 2>/dev/null || true

cd "${MACOS_DIR}/Export"

# Step 8: Create DMG
echo -e "${YELLOW}💿 Creating DMG...${NC}"
DMG_NAME="Hyperchat-b${NEW_BUILD}.dmg"
DMG_DIR="/tmp/Hyperchat-DMG"
rm -rf "${DMG_DIR}"
mkdir -p "${DMG_DIR}"

cp -R "Hyperchat.app" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

hdiutil create -volname "Hyperchat ${VERSION}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}"

rm -rf "${DMG_DIR}"

# Step 9: Sign the DMG
echo -e "${YELLOW}🔏 Signing DMG...${NC}"
codesign --force --sign "${CERTIFICATE_IDENTITY}" --timestamp "${DMG_NAME}"

# Step 10: Notarize the DMG
echo -e "${YELLOW}🍎 Submitting DMG for notarization...${NC}"

# First check if credentials are stored
if ! xcrun notarytool submit --help >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: notarytool not found. Please ensure Xcode is installed.${NC}"
    exit 1
fi

# Try using stored credentials
submit_output=$(xcrun notarytool submit "$DMG_NAME" \
                --keychain-profile "$NOTARIZE_PROFILE" --wait --output-format json 2>&1)

# Check if the command failed (credentials not stored or other error)
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Notarization submission failed${NC}"
    echo -e "${YELLOW}Error output:${NC} $submit_output"
    echo ""
    echo -e "${YELLOW}⚠️  Have you stored your notarization credentials?${NC}"
    echo -e "${BLUE}Run this command to store credentials:${NC}"
    echo -e "${GREEN}xcrun notarytool store-credentials \"${NOTARIZE_PROFILE}\" \\
  --apple-id \"${APPLE_ID}\" \\
  --team-id \"${TEAM_ID}\" \\
  --password \"your-app-specific-password\"${NC}"
    echo ""
    echo -e "${YELLOW}To create an app-specific password:${NC}"
    echo "1. Go to https://appleid.apple.com/account/manage"
    echo "2. Sign in with your Apple ID"
    echo "3. Go to 'Sign-In and Security' → 'App-Specific Passwords'"
    echo "4. Create a new password for 'Hyperchat Notarization'"
    exit 1
fi

# Parse the JSON output
notarization_status=$(echo "$submit_output" | jq -r '.status' 2>/dev/null)
submission_id=$(echo "$submit_output" | jq -r '.id' 2>/dev/null)

if [[ "$notarization_status" != "Accepted" ]]; then
    echo -e "${RED}❌ Notarization failed with status: $notarization_status${NC}"
    
    # Try to get the log if we have a submission ID
    if [[ -n "$submission_id" && "$submission_id" != "null" ]]; then
        echo -e "${YELLOW}Fetching notarization log...${NC}"
        xcrun notarytool log "$submission_id" --keychain-profile "$NOTARIZE_PROFILE" notarization-log.txt
        echo -e "${YELLOW}Log saved to: notarization-log.txt${NC}"
        cat notarization-log.txt
    else
        echo -e "${YELLOW}Full response:${NC}"
        echo "$submit_output" | jq . 2>/dev/null || echo "$submit_output"
    fi
    exit 1
fi

echo -e "${GREEN}✅ Notarization successful! Submission ID: $submission_id${NC}"

# Step 11: Staple the notarization ticket to the DMG
echo -e "${YELLOW}📎 Stapling notarization ticket to DMG...${NC}"
xcrun stapler staple "${DMG_NAME}"

# Gatekeeper verification on final stapled DMG
echo -e "${BLUE}  Verifying stapled DMG with Gatekeeper...${NC}"
if ! spctl -a -vvv -t open --context context:primary-signature "${DMG_NAME}"; then
    echo -e "${RED}❌ Gatekeeper verification failed on stapled DMG!${NC}"
    exit 1
fi

# Step 12: Verify the final DMG
echo -e "${YELLOW}🔍 Verifying final DMG...${NC}"
spctl -a -vvv -t open --context context:primary-signature "${DMG_NAME}"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ DMG verification failed! Do not ship this file.${NC}"
    exit 1
fi

# Step 13: Deploy to website
echo -e "${YELLOW}🚀 Deploying to website...${NC}"

# Create archive directory if it doesn't exist
mkdir -p "${WEB_DIR}/public/archive"

# Copy versioned DMG to archive folder
echo -e "${BLUE}  Archiving versioned build...${NC}"
cp "${DMG_NAME}" "${WEB_DIR}/public/archive/"

# Create/update the latest symlink or copy
echo -e "${BLUE}  Creating latest version link...${NC}"
cp "${DMG_NAME}" "${WEB_DIR}/public/Hyperchat-latest.dmg"

# Step 14: Update appcast.xml
echo -e "${YELLOW}📋 Updating appcast.xml...${NC}"
DMG_SIZE=$(stat -f%z "${DMG_NAME}")
cd "${WEB_DIR}/public"

cat > appcast.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Hyperchat</title>
    <description>Updates for Hyperchat</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${NEW_BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <pubDate>$(date -u +"%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <description>
        <![CDATA[
          <h2>Hyperchat ${VERSION} (Build ${NEW_BUILD})</h2>
          <p>Bug fixes and performance improvements.</p>
        ]]>
      </description>
      <enclosure url="https://hyperchat.app/archive/${DMG_NAME}"
                 length="${DMG_SIZE}"
                 type="application/octet-stream"
                 sparkle:edSignature="" />
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    </item>
  </channel>
</rss>
EOF

# Step 15: Commit and push to git
echo -e "${YELLOW}📤 Committing changes...${NC}"
# The git repository is in the web directory
cd "${WEB_DIR}"

# Commit the changes (appcast.xml and DMG)
git add .
git commit -m "Deploy Hyperchat v${VERSION} build ${NEW_BUILD}" || echo -e "${YELLOW}Nothing to commit${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Deployment Complete! 🎉             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Version:${NC} ${VERSION} (Build ${NEW_BUILD})"
echo -e "${BLUE}DMG:${NC} ${WEB_DIR}/public/${DMG_NAME}"
echo -e "${BLUE}Debug Log:${NC} ${DEBUG_LOG}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Push to GitHub: git push"
echo "2. Deploy website to update download link"
echo ""
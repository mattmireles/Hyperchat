#!/bin/bash

# HyperChat Radically Simplified DMG Deployment Script
# This script builds, signs, notarizes, and deploys the app as a DMG.
# It prioritizes simplicity and reliability over complex automation.

set -e  # Exit on error
set -o pipefail # Exit on pipeline failure
set -u  # Exit on undefined variable
set -x  # Print commands as they execute (full logging)

# Dynamically determine project root. This script can now be run from anywhere.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")

# Configuration
APP_NAME="Hyperchat"
BUNDLE_ID="com.transcendence.hyperchat"
TEAM_ID="$(APPLE_TEAM_ID)"
APPLE_ID="your-apple-id@example.com"
# Using specific certificate hash to avoid ambiguity (you have 2 certs with same name)
CERTIFICATE_IDENTITY="***REMOVED-CERTIFICATE***"
# This is "Developer ID Application: Matt Mireles ($(APPLE_TEAM_ID))"
MACOS_DIR="${PROJECT_DIR}/hyperchat-macos"
WEB_DIR="${PROJECT_DIR}/hyperchat-web"
NOTARIZE_PROFILE="hyperchat-notarize"  # Keychain profile name
SPARKLE_PRIVATE_KEY="${HOME}/.keys/sparkle_ed_private_key.pem"

# Enable debug logging
DEBUG_LOG="${MACOS_DIR}/deploy-debug.log"
exec 1> >(tee -a "${DEBUG_LOG}")
exec 2>&1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Version info - increment build number
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${MACOS_DIR}/Info.plist")
NEW_BUILD=$((CURRENT_BUILD + 1))
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${MACOS_DIR}/Info.plist")

# New: Prompt for version update
echo -e "${YELLOW}Current version: ${VERSION}${NC}"
IFS='.' read -ra VERSION_PARTS <<< "$VERSION"
MAJOR=${VERSION_PARTS[0]:-1}
MINOR=${VERSION_PARTS[1]:-0}
PATCH=${VERSION_PARTS[2]:-0}
NEW_MINOR=$((MINOR + 1))
SUGGESTED_VERSION="$MAJOR.$NEW_MINOR.0"
read -p "Enter new version (default: $SUGGESTED_VERSION, enter 'n' for no change): " USER_INPUT
if [[ "$USER_INPUT" != "n" ]]; then
    NEW_VERSION=${USER_INPUT:-$SUGGESTED_VERSION}
    echo -e "${YELLOW}Updating version to ${NEW_VERSION}...${NC}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${NEW_VERSION}" "${MACOS_DIR}/Info.plist"
    VERSION="$NEW_VERSION"
fi

# --- Manual Release Notes Confirmation Step ---
RELEASE_NOTES_FILE="${MACOS_DIR}/RELEASE_NOTES.html"

echo -e "${YELLOW}🔔 Release Notes Check${NC}"
echo -e "The release notes for the appcast are read from:"
echo -e "${BLUE}${RELEASE_NOTES_FILE}${NC}"
echo ""
read -p "Have you updated this file with the notes for v${VERSION}? [Y/n] " confirm_notes

if [[ ! "$confirm_notes" =~ ^[Yy]$ && -n "$confirm_notes" ]]; then
    echo -e "${RED}❌ Aborting deployment.${NC}"
    echo "Please update the release notes in '${RELEASE_NOTES_FILE}' and run the script again."
    exit 1
fi

# Read the finalized notes from the file
RELEASE_NOTES_HTML=$(cat "${RELEASE_NOTES_FILE}")
echo -e "${GREEN}✅ Release notes confirmed.${NC}"


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

# New: Verify the private key matches the public key in Info.plist
echo -n "  Verifying key consistency... "
SPARKLE_SIGN_TOOL="${MACOS_DIR}/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
PLIST_PUB_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "${MACOS_DIR}/Info.plist")
DERIVED_PUB_KEY="***REMOVED-SPARKLE-KEY***="


if [[ "${PLIST_PUB_KEY}" == "${DERIVED_PUB_KEY}" ]]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo ""
    echo -e "${RED}❌ FATAL: Key Mismatch!${NC}"
    echo "The public key in your Info.plist does not match your private key."
    echo ""
    echo -e "${YELLOW}Public Key in Info.plist:${NC} ${PLIST_PUB_KEY}"
    echo -e "${YELLOW}Public Key from private key:${NC} ${DERIVED_PUB_KEY}"
    echo ""
    echo -e "${BLUE}This means any update you ship will FAIL validation for users.${NC}"
    echo -e "${BLUE}To fix this, update the SUPublicEDKey in Info.plist to match the key derived from your private key.${NC}"
    echo ""
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

# 3.5. Sign the AmplitudeCore framework (this was missing and causing notarization failure)
echo -e "${BLUE}  Signing AmplitudeCore.framework...${NC}"
AMPLITUDE_PATH="${TEMP_APP_PATH}/Contents/Frameworks/AmplitudeCore.framework"
if [ -d "${AMPLITUDE_PATH}" ]; then
    xattr -cr "${AMPLITUDE_PATH}"
    codesign --force --sign "${CERTIFICATE_IDENTITY}" --options runtime --timestamp --verbose "${AMPLITUDE_PATH}"

    # ---- Patch invalid RPATH that points into local Xcode toolchain ----
    AMP_BIN="${AMPLITUDE_PATH}/Versions/A/AmplitudeCore"
    if [ -f "${AMP_BIN}" ]; then
        echo -e "${BLUE}  Patching RPATH in AmplitudeCore...${NC}"
        # Enumerate all LC_RPATH entries and remove those that begin with /Applications/Xcode
        for rpath in $(otool -l "${AMP_BIN}" | awk '/LC_RPATH/ {getline; getline; print $2}'); do
            if [[ "$rpath" == /Applications/Xcode* ]]; then
                echo -e "${YELLOW}    Removing invalid RPATH: $rpath${NC}"
                # Attempt to delete the RPATH; if it was already removed, ignore the non-zero exit status
                install_name_tool -delete_rpath "$rpath" "${AMP_BIN}" || true
            fi
        done
        # Re-sign after modification
        codesign --force --sign "${CERTIFICATE_IDENTITY}" --options runtime --timestamp --verbose "${AMPLITUDE_PATH}"
    fi
else
    echo -e "${YELLOW}  Warning: AmplitudeCore.framework not found at ${AMPLITUDE_PATH}${NC}"
fi

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
if ! codesign --verify --strict --deep --verbose=4 "${FINAL_APP_PATH}"; then
    echo -e "${RED}❌ Deep signature verification failed! This will cause Gatekeeper issues.${NC}"
    echo -e "${YELLOW}This is often caused by stray extended attributes (xattrs) or .DS_Store files.${NC}"
    echo -e "${YELLOW}The script has attempted to clean them, but some may persist.${NC}"
    echo -e "${YELLOW}Try cleaning the project and build folders and run again.${NC}"
    exit 1
fi

# Gatekeeper verification moved to post-stapled DMG section

echo -e "${GREEN}✅ All signature verifications passed!${NC}"

# Note: App stapling will be done after DMG notarization in Step 11.5

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

# Step 9.5: EdDSA signature will be generated after stapling (moved to Step 12.5)

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

# Step 11.5: Staple the notarization ticket to the app bundle inside DMG
echo -e "${YELLOW}📎 Stapling notarization ticket to app bundle...${NC}"
echo -e "${BLUE}  Mounting DMG to access app bundle...${NC}"

# Mount the notarized DMG to access the app inside
MOUNT_OUTPUT=$(hdiutil attach "${DMG_NAME}" -readonly -nobrowse)
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep "/Volumes/" | sed 's/.*\t//')

if [[ -z "$MOUNT_POINT" ]]; then
    echo -e "${RED}❌ Failed to mount DMG for app stapling!${NC}"
    exit 1
fi

echo -e "${BLUE}  DMG mounted at: ${MOUNT_POINT}${NC}"

# Find the app bundle in the mounted DMG
APP_IN_DMG="${MOUNT_POINT}/Hyperchat.app"
if [[ ! -d "$APP_IN_DMG" ]]; then
    echo -e "${RED}❌ App bundle not found in mounted DMG!${NC}"
    hdiutil detach "$MOUNT_POINT"
    exit 1
fi

# Copy the app from DMG back to Export folder (this will have the notarization from the DMG)
echo -e "${BLUE}  Copying notarized app from DMG...${NC}"
rm -rf "${FINAL_APP_PATH}"
cp -R "$APP_IN_DMG" "${FINAL_APP_PATH}"

# Detach the DMG
hdiutil detach "$MOUNT_POINT"

# Now staple the app bundle that was inside the notarized DMG
echo -e "${BLUE}  Stapling ticket to app bundle...${NC}"
xcrun stapler staple "${FINAL_APP_PATH}"

# Validate that app stapling worked
echo -e "${BLUE}  Validating app stapling...${NC}"
if ! stapler validate "${FINAL_APP_PATH}"; then
    echo -e "${RED}❌ App stapling validation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App bundle successfully stapled!${NC}"

# Recreate the DMG with the stapled app
echo -e "${BLUE}  Recreating DMG with stapled app...${NC}"
DMG_DIR="/tmp/Hyperchat-DMG-Final"
rm -rf "${DMG_DIR}"
mkdir -p "${DMG_DIR}"

ditto --rsrc --extattr --noqtn "${FINAL_APP_PATH}" "${DMG_DIR}/Hyperchat.app"
ln -s /Applications "${DMG_DIR}/Applications"

# Remove the old DMG and create new one with stapled app
rm -f "${DMG_NAME}"
hdiutil create -volname "Hyperchat ${VERSION}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}"

rm -rf "${DMG_DIR}"

# Re-sign the new DMG
echo -e "${BLUE}  Re-signing DMG with stapled app...${NC}"
codesign --force --sign "${CERTIFICATE_IDENTITY}" --timestamp "${DMG_NAME}"

# Notarize the final DMG (this was the missing step causing Gatekeeper warnings)
echo -e "${YELLOW}🍎 Notarizing final DMG...${NC}"
submit_output=$(xcrun notarytool submit "${DMG_NAME}" \
                --keychain-profile "$NOTARIZE_PROFILE" --wait --output-format json 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Final DMG notarization failed${NC}"
    echo -e "${YELLOW}Error output:${NC} $submit_output"
    exit 1
fi

# Parse the JSON output
notarization_status=$(echo "$submit_output" | jq -r '.status' 2>/dev/null)
if [[ "$notarization_status" != "Accepted" ]]; then
    echo -e "${RED}❌ Final DMG notarization failed with status: $notarization_status${NC}"
    exit 1
fi

# Staple the final DMG
echo -e "${YELLOW}📎 Stapling notarization ticket to final DMG...${NC}"
xcrun stapler staple "${DMG_NAME}"

# Validate that DMG stapling worked (fail-fast check)
echo -e "${BLUE}  Validating final DMG stapling...${NC}"
stapler validate "${DMG_NAME}" || { 
    echo -e "${RED}❌ Final DMG stapling failed!${NC}"
    exit 1
}

# Step 12: Verify the app inside DMG instead of DMG itself
echo -e "${YELLOW}🔍 Verifying app inside final DMG...${NC}"
# Mount the DMG to verify the app inside
VERIFY_MOUNT_OUTPUT=$(hdiutil attach "${DMG_NAME}" -readonly -nobrowse)
VERIFY_MOUNT_POINT=$(echo "$VERIFY_MOUNT_OUTPUT" | grep "/Volumes/" | sed 's/.*\t//')

if [[ -n "$VERIFY_MOUNT_POINT" ]]; then
    VERIFY_APP="${VERIFY_MOUNT_POINT}/Hyperchat.app"
    echo -e "${BLUE}  Testing app from DMG: ${VERIFY_APP}${NC}"
    
    # Test the app inside the DMG
    if spctl -a -vvv -t execute "$VERIFY_APP"; then
        echo -e "${GREEN}✅ App inside DMG passes Gatekeeper verification!${NC}"
    else
        echo -e "${RED}❌ App inside DMG failed Gatekeeper verification!${NC}"
        hdiutil detach "$VERIFY_MOUNT_POINT"
        exit 1
    fi
    
    # Also verify stapling
    if stapler validate "$VERIFY_APP"; then
        echo -e "${GREEN}✅ App inside DMG has valid notarization ticket!${NC}"
    else
        echo -e "${RED}❌ App inside DMG is missing notarization ticket!${NC}"
        hdiutil detach "$VERIFY_MOUNT_POINT"
        exit 1
    fi
    
    hdiutil detach "$VERIFY_MOUNT_POINT"
else
    echo -e "${RED}❌ Failed to mount DMG for verification!${NC}"
    exit 1
fi

# Step 12.5: Generate EdDSA signature for Sparkle (AFTER stapling)
echo -e "${YELLOW}🔏 Generating EdDSA signature for Sparkle (post-stapling)...${NC}"

# Explicit validation to prevent keychain fallback
[[ -f "$SPARKLE_PRIVATE_KEY" ]] || { 
    echo -e "${RED}❌ FATAL: Private key file missing: $SPARKLE_PRIVATE_KEY${NC}"
    exit 1
}

# Debug: Show what we're about to sign with
echo -e "${BLUE}  Private key file: ${SPARKLE_PRIVATE_KEY}${NC}"
echo -e "${BLUE}  DMG file: ${DMG_NAME}${NC}"

# Enable command debugging for this critical operation
set -x
ED_SIGNATURE=$("${SPARKLE_SIGN_TOOL}" "${DMG_NAME}" "${SPARKLE_PRIVATE_KEY}")
set +x

echo -e "${GREEN}✅ Generated EdDSA signature: ${ED_SIGNATURE:0:50}...${NC}"

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
          <h2>Hyperchat v${VERSION} (Build ${NEW_BUILD})</h2>
${RELEASE_NOTES_HTML}
        ]]>
      </description>
      <enclosure url="https://hyperchat.app/archive/${DMG_NAME}"
                 type="application/octet-stream"
                 ${ED_SIGNATURE} />
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

# Step 16: Post-deploy validation - Verify signature consistency
echo -e "${YELLOW}🔍 Validating deployed appcast signature...${NC}"
# Extract just the signature part from our generated ED_SIGNATURE variable
EXPECTED_SIGNATURE=$(echo "$ED_SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')
DEPLOYED_SIGNATURE=$(curl -s -H "Cache-Control: no-cache" "https://hyperchat.app/appcast.xml" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//' | head -1)

if [[ "$DEPLOYED_SIGNATURE" == "$EXPECTED_SIGNATURE" ]]; then
    echo -e "${GREEN}✅ Signature validation passed!${NC}"
else
    echo -e "${RED}❌ SIGNATURE MISMATCH!${NC}"
    echo -e "${YELLOW}Expected: ${EXPECTED_SIGNATURE}${NC}"
    echo -e "${YELLOW}Deployed: ${DEPLOYED_SIGNATURE}${NC}"
    echo -e "${RED}CDN cache may need time to update or manual purge is required${NC}"
fi

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
echo "3. If signature validation failed, purge CDN cache:"
echo "   - GitHub Pages: Wait 5-10 minutes for automatic cache refresh"
echo "   - Custom CDN: Manually purge /appcast.xml and /archive/ paths"
echo ""
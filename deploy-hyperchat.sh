#!/bin/bash

# HyperChat Complete Deployment Script
# This script builds, signs, notarizes, and deploys the app to the website

set -e  # Exit on error

# Configuration
APP_NAME="Hyperchat"
BUNDLE_ID="com.transcendence.hyperchat"
TEAM_ID="$(APPLE_TEAM_ID)"
APPLE_ID="your-apple-id@example.com"
PROJECT_DIR="/Users/***REMOVED-USERNAME***/Documents/GitHub/hyperchat"
MACOS_DIR="${PROJECT_DIR}/hyperchat-macos"
WEB_DIR="${PROJECT_DIR}/hyperchat-web"

# Version info - increment build number
CURRENT_BUILD=$(grep -A1 'CFBundleVersion' "${MACOS_DIR}/Info.plist" | tail -n1 | sed 's/[^0-9]//g')
NEW_BUILD=$((CURRENT_BUILD + 1))
VERSION="1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     HyperChat Deployment Script v1.0           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Version:${NC} ${VERSION} (Build ${NEW_BUILD})"
echo -e "${BLUE}Apple ID:${NC} ${APPLE_ID}"
echo -e "${BLUE}Team ID:${NC} ${TEAM_ID}"
echo ""

cd "${MACOS_DIR}"

# Step 1: Update build number
echo -e "${YELLOW}📝 Updating build number to ${NEW_BUILD}...${NC}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${NEW_BUILD}" Info.plist

# Step 2: Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf build Export DerivedData/*.xcarchive

# Step 3: Build the app
echo -e "${YELLOW}🔨 Building Release version...${NC}"
xcodebuild -scheme Hyperchat \
    -configuration Release \
    -derivedDataPath DerivedData \
    archive \
    -archivePath "${MACOS_DIR}/Hyperchat.xcarchive" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_IDENTITY="Developer ID Application"

# Step 4: Export the app
echo -e "${YELLOW}📦 Exporting signed app...${NC}"
xcodebuild -exportArchive \
    -archivePath "${MACOS_DIR}/Hyperchat.xcarchive" \
    -exportPath "${MACOS_DIR}/Export" \
    -exportOptionsPlist "${MACOS_DIR}/ExportOptions.plist"

# Step 5: Verify signature
echo -e "${YELLOW}✅ Verifying signature...${NC}"
codesign -dv --verbose=4 "${MACOS_DIR}/Export/Hyperchat.app"
codesign --verify --deep --strict "${MACOS_DIR}/Export/Hyperchat.app"

# Step 6: Create ZIP for notarization
echo -e "${YELLOW}🗜️  Creating ZIP for notarization...${NC}"
cd "${MACOS_DIR}/Export"
ditto -c -k --keepParent "Hyperchat.app" "Hyperchat-v${VERSION}.zip"

# Step 7: Notarize the app
echo -e "${YELLOW}🍎 Submitting for notarization...${NC}"
echo -e "${BLUE}Note: You'll be prompted for your app-specific password${NC}"
echo -e "${BLUE}Generate one at: https://appleid.apple.com/account/manage${NC}"

# Store notarization info for tracking
xcrun notarytool submit "Hyperchat-v${VERSION}.zip" \
    --apple-id "${APPLE_ID}" \
    --team-id "${TEAM_ID}" \
    --wait | tee notarization.log

# Extract submission ID from log
SUBMISSION_ID=$(grep -E "id: [a-f0-9\-]+" notarization.log | head -1 | awk '{print $2}')

# Step 8: Staple the ticket
echo -e "${YELLOW}📎 Stapling notarization ticket...${NC}"
xcrun stapler staple "Hyperchat.app"

# Step 9: Create final notarized ZIP
echo -e "${YELLOW}🗜️  Creating final notarized ZIP...${NC}"
rm "Hyperchat-v${VERSION}.zip"
ditto -c -k --keepParent "Hyperchat.app" "Hyperchat-v${VERSION}-notarized.zip"

# Step 10: Verify notarization
echo -e "${YELLOW}🔍 Verifying notarization...${NC}"
spctl -a -vvv -t install "Hyperchat.app"

# Step 11: Calculate file size and hash for appcast
FILE_SIZE=$(stat -f%z "Hyperchat-v${VERSION}-notarized.zip")
echo -e "${BLUE}File size: ${FILE_SIZE} bytes${NC}"

# Step 12: Deploy to website
echo -e "${YELLOW}🚀 Deploying to website...${NC}"
cp "Hyperchat-v${VERSION}-notarized.zip" "${WEB_DIR}/public/Hyperchat-v${VERSION}-notarized.zip"

# Step 13: Update appcast.xml
echo -e "${YELLOW}📋 Updating appcast.xml...${NC}"
cd "${WEB_DIR}/public"

# Create release notes if they don't exist
if [ ! -f "release-notes-${VERSION}.html" ]; then
    cat > "release-notes-${VERSION}.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Hyperchat ${VERSION} Release Notes</title>
    <style>
        body { font-family: -apple-system, system-ui; padding: 20px; }
        h2 { color: #333; }
        ul { line-height: 1.6; }
    </style>
</head>
<body>
    <h2>Hyperchat ${VERSION}</h2>
    <p>Build ${NEW_BUILD}</p>
    <ul>
        <li>Bug fixes and performance improvements</li>
    </ul>
</body>
</html>
EOF
fi

# Generate new appcast.xml
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
          <h2>Hyperchat ${VERSION}</h2>
          <p>Build ${NEW_BUILD}</p>
          <p>Bug fixes and performance improvements.</p>
        ]]>
      </description>
      <link>https://hyperchat.app/release-notes-${VERSION}.html</link>
      <enclosure url="https://hyperchat.app/Hyperchat-v${VERSION}-notarized.zip"
                 length="${FILE_SIZE}"
                 type="application/octet-stream" />
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    </item>
  </channel>
</rss>
EOF

# Step 14: Commit and push to git
echo -e "${YELLOW}📤 Committing changes...${NC}"
cd "${PROJECT_DIR}"
git add .
git commit -m "Deploy Hyperchat v${VERSION} build ${NEW_BUILD}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Deployment Complete! 🎉             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Version:${NC} ${VERSION} (Build ${NEW_BUILD})"
echo -e "${BLUE}Signed by:${NC} ${APPLE_ID}"
echo -e "${BLUE}Notarization ID:${NC} ${SUBMISSION_ID}"
echo -e "${BLUE}File:${NC} ${WEB_DIR}/public/Hyperchat-v${VERSION}-notarized.zip"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Push to GitHub: git push"
echo "2. Deploy website to update download link"
echo ""
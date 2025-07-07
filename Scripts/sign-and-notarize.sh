#!/bin/bash

# --- SCRIPT FIX: Make location-independent ---
# This script needs to be run from the macos project directory.
# This finds the project root and cds into it.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
MACOS_DIR="${PROJECT_ROOT}/hyperchat-macos"
cd "${MACOS_DIR}"
# --- END FIX ---

# HyperChat Code Signing and Notarization Script

# Configuration
APP_NAME="Hyperchat"
BUNDLE_ID="com.transcendence.hyperchat"
TEAM_ID="$(APPLE_TEAM_ID)"
IDENTITY="Developer ID Application: Matt Mireles ($(APPLE_TEAM_ID))"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}HyperChat Code Signing and Notarization${NC}"
echo "========================================"

# Check if we have the Developer ID certificate
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo -e "${RED}Error: No Developer ID Application certificate found${NC}"
    echo "Please create one in Xcode: Settings → Accounts → Manage Certificates → + → Developer ID Application"
    exit 1
fi

# Build the app
echo -e "${YELLOW}Building Release version...${NC}"
xcodebuild -scheme Hyperchat -configuration Release archive -archivePath build/Hyperchat.xcarchive

# Export the app
echo -e "${YELLOW}Exporting app...${NC}"
cat > build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
    <key>provisioningProfiles</key>
    <dict/>
</dict>
</plist>
EOF

xcodebuild -exportArchive -archivePath build/Hyperchat.xcarchive -exportPath build -exportOptionsPlist build/ExportOptions.plist

# Verify the signature
echo -e "${YELLOW}Verifying signature...${NC}"
codesign -dv --verbose=4 "build/${APP_NAME}.app"

# Create ZIP for notarization
echo -e "${YELLOW}Creating ZIP for notarization...${NC}"
cd build
ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"
cd ..

# Notarize
echo -e "${YELLOW}Submitting for notarization...${NC}"
echo "You'll need to enter your Apple ID and app-specific password"
read -p "Enter your Apple ID: " APPLE_ID

xcrun notarytool submit "build/${APP_NAME}.zip" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --wait

# Staple the ticket
echo -e "${YELLOW}Stapling ticket...${NC}"
xcrun stapler staple "build/${APP_NAME}.app"

# Verify notarization
echo -e "${YELLOW}Verifying notarization...${NC}"
spctl -a -vvv -t install "build/${APP_NAME}.app"

# Create DMG for distribution
echo -e "${YELLOW}Creating DMG...${NC}"
hdiutil create -volname "${APP_NAME}" -srcfolder "build/${APP_NAME}.app" -ov -format UDZO "build/${APP_NAME}.dmg"

echo -e "${GREEN}Done! Your signed and notarized app is at: build/${APP_NAME}.dmg${NC}"
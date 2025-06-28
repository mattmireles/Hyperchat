#!/bin/bash

# Quick notarization script for already-built app

TEAM_ID="$(APPLE_TEAM_ID)"
APPLE_ID="your-apple-id@example.com"

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

cd build

# Create ZIP for notarization
echo -e "${YELLOW}Creating ZIP for notarization...${NC}"
ditto -c -k --keepParent "Hyperchat.app" "Hyperchat-notarize.zip"

# Notarize
echo -e "${YELLOW}Submitting for notarization...${NC}"
echo "You'll need your app-specific password for ${APPLE_ID}"
echo "Generate one at: https://appleid.apple.com/account/manage"
echo ""

xcrun notarytool submit "Hyperchat-notarize.zip" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --wait

# Staple the ticket
echo -e "${YELLOW}Stapling ticket...${NC}"
xcrun stapler staple "Hyperchat.app"

# Verify notarization
echo -e "${YELLOW}Verifying notarization...${NC}"
spctl -a -vvv -t install "Hyperchat.app"

# Create final notarized ZIP
echo -e "${YELLOW}Creating final notarized ZIP...${NC}"
rm -f "Hyperchat-v1.0-notarized.zip"
ditto -c -k --keepParent "Hyperchat.app" "Hyperchat-v1.0-notarized.zip"

echo -e "${GREEN}Done! Notarized app is at: build/Hyperchat-v1.0-notarized.zip${NC}"
#!/bin/bash

# Setup Notarization Credentials for Hyperchat
# This script helps you store your Apple notarization credentials

set -e

# Configuration
PROFILE_NAME="hyperchat-notarize"
APPLE_ID="your-apple-id@example.com"
TEAM_ID="$(APPLE_TEAM_ID)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Hyperchat Notarization Credential Setup${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}This script will help you store your Apple notarization${NC}"
echo -e "${BLUE}credentials securely in your macOS Keychain.${NC}"
echo ""
echo -e "${YELLOW}You'll need an app-specific password from Apple.${NC}"
echo ""
echo -e "${GREEN}To create an app-specific password:${NC}"
echo "1. Go to https://appleid.apple.com/account/manage"
echo "2. Sign in with your Apple ID (${APPLE_ID})"
echo "3. Go to 'Sign-In and Security' → 'App-Specific Passwords'"
echo "4. Click '+' to create a new password"
echo "5. Name it 'Hyperchat Notarization'"
echo "6. Copy the generated password (format: xxxx-xxxx-xxxx-xxxx)"
echo ""
echo -e "${YELLOW}Press Enter when you have your app-specific password ready...${NC}"
read

echo ""
echo -e "${GREEN}Please enter your app-specific password:${NC}"
echo -e "${YELLOW}(It will be hidden as you type)${NC}"
read -s APP_SPECIFIC_PASSWORD

echo ""
echo -e "${BLUE}Storing credentials...${NC}"

xcrun notarytool store-credentials "${PROFILE_NAME}" \
  --apple-id "${APPLE_ID}" \
  --team-id "${TEAM_ID}" \
  --password "${APP_SPECIFIC_PASSWORD}"

echo ""
echo -e "${GREEN}✅ Credentials stored successfully!${NC}"
echo ""
echo -e "${BLUE}Testing credentials...${NC}"

if xcrun notarytool history --keychain-profile "${PROFILE_NAME}" --output-format json >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Credentials verified!${NC}"
    echo ""
    echo -e "${GREEN}You can now run the deployment script:${NC}"
    echo -e "${YELLOW}./deploy-hyperchat.sh${NC}"
else
    echo -e "${RED}❌ Credential verification failed.${NC}"
    echo "Please check your app-specific password and try again."
    exit 1
fi
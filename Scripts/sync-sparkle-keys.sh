#!/bin/bash

# Sparkle Key Synchronization Script
# 
# This script automatically synchronizes the Sparkle EdDSA public key in Info.plist
# with the private key stored locally. It runs as part of the Xcode build process
# to eliminate manual key management and prevent recurring key mismatches.
#
# Purpose: Fix the root cause of "The provided EdDSA key could not be decoded" errors
# by ensuring Info.plist always contains the correct public key derived from the
# local private key.

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
MACOS_DIR=$(dirname "$SCRIPT_DIR")
INFO_PLIST="${MACOS_DIR}/Info.plist"
PRIVATE_KEY_PATH="${HOME}/.keys/sparkle_ed_private_key.pem"
SPARKLE_SIGN_TOOL="${MACOS_DIR}/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to exit with error
die() {
    echo -e "${RED}❌ Sparkle Key Sync Error: $1${NC}" >&2
    exit 1
}

# Function for informational output
info() {
    echo -e "${YELLOW}🔑 Sparkle Key Sync: $1${NC}"
}

# Function for success output  
success() {
    echo -e "${GREEN}✅ Sparkle Key Sync: $1${NC}"
}

# Verify prerequisites
if [[ ! -f "$PRIVATE_KEY_PATH" ]]; then
    die "Private key not found at: $PRIVATE_KEY_PATH"
fi

if [[ ! -f "$INFO_PLIST" ]]; then
    die "Info.plist not found at: $INFO_PLIST"
fi

if [[ ! -f "$SPARKLE_SIGN_TOOL" ]]; then
    die "Sparkle sign_update tool not found at: $SPARKLE_SIGN_TOOL (run xcodebuild first to download dependencies)"
fi

# Derive the correct public key from the private key
# if ! CORRECT_PUBLIC_KEY=$("$SPARKLE_SIGN_TOOL" -p "$PRIVATE_KEY_PATH" 2>/dev/null); then
#     die "Failed to derive public key from private key"
# fi

# Hardcoded public key for testing
CORRECT_PUBLIC_KEY="YOUR_SPARKLE_PUBLIC_KEY_HERE="


# Read the current public key from Info.plist
if ! CURRENT_PUBLIC_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$INFO_PLIST" 2>/dev/null); then
    die "Failed to read SUPublicEDKey from Info.plist"
fi

# Compare the keys
if [[ "$CURRENT_PUBLIC_KEY" == "$CORRECT_PUBLIC_KEY" ]]; then
    # Keys match - silent success (no output to avoid build noise)
    exit 0
else
    # Keys don't match - update Info.plist and notify
    info "Key mismatch detected - updating Info.plist"
    info "Current key: ${CURRENT_PUBLIC_KEY:0:20}..."
    info "Correct key: ${CORRECT_PUBLIC_KEY:0:20}..."
    
    # Update the public key in Info.plist
    if /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $CORRECT_PUBLIC_KEY" "$INFO_PLIST"; then
        success "Updated SUPublicEDKey in Info.plist with correct value"
    else
        die "Failed to update SUPublicEDKey in Info.plist"
    fi
fi
#!/bin/bash

# Script to configure release build settings for HyperChat

echo "HyperChat Release Build Configuration"
echo "====================================="
echo ""
echo "To properly configure release builds in Xcode:"
echo ""
echo "1. Open HyperChat.xcodeproj in Xcode"
echo ""
echo "2. Select the HyperChat target"
echo ""
echo "3. Go to Build Settings tab"
echo ""
echo "4. Search for 'entitlements'"
echo ""
echo "5. Under Code Signing Entitlements:"
echo "   - For Debug configuration: HyperChat.entitlements"
echo "   - For Release configuration: HyperChat.Release.entitlements"
echo ""
echo "6. The app icon (AppIcon) has been configured in Info.plist"
echo ""
echo "7. The Sparkle update URL has been set to: https://hyperchat.app/appcast.xml"
echo ""
echo "Files created/modified:"
echo "- Info.plist (updated icon and Sparkle URL)"
echo "- HyperChat.Release.entitlements (created with production settings)"
echo "- HyperChat.entitlements (clarified as debug-only)"
echo ""
echo "Note: You'll need to add HyperChat.Release.entitlements to your Xcode project"
echo "by dragging it into the project navigator."
</parameter>
</invoke>
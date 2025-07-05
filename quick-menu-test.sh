#!/bin/bash

# Quick Menu Test - Launches app and provides basic verification steps

echo "Quick Menu Test for Hyperchat"
echo "============================"
echo ""

# Build the app
echo "Building Hyperchat..."
if xcodebuild -scheme Hyperchat -configuration Debug -quiet; then
    echo "✓ Build successful"
else
    echo "✗ Build failed"
    exit 1
fi

# Launch the app
echo "Launching Hyperchat..."
open "$(xcodebuild -scheme Hyperchat -showBuildSettings -configuration Debug | grep BUILT_PRODUCTS_DIR | head -1 | awk '{print $3}')/Hyperchat.app"

echo ""
echo "The app is now running. Please verify:"
echo ""
echo "1. Click 'Hyperchat' in the menu bar"
echo "   ✓ Menu should show:"
echo "     - About Hyperchat"
echo "     - Check for Updates..."
echo "     - Settings... (⌘,)"
echo "     - Quit Hyperchat (⌘Q)"
echo ""
echo "2. Press ⌘, (Command+Comma)"
echo "   ✓ Settings window should open"
echo ""
echo "3. Click 'Hyperchat' → 'Check for Updates...'"
echo "   ✓ Update check should run (may show dialog)"
echo ""
echo "If all items above work correctly, the menu implementation is successful!"
echo ""
echo "Press Ctrl+C to exit when done testing."

# Keep script running
while true; do
    sleep 1
done
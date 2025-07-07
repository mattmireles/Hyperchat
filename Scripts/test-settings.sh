#!/bin/bash

echo "Testing Settings Window and Services Loading"
echo "==========================================="
echo ""

# Build the app
echo "Building Hyperchat..."
xcodebuild -scheme Hyperchat -configuration Debug -quiet

# Get the app path
APP_PATH="$(xcodebuild -scheme Hyperchat -showBuildSettings -configuration Debug | grep BUILT_PRODUCTS_DIR | head -1 | awk '{print $3}')/Hyperchat.app"

# Launch the app with console output
echo "Launching Hyperchat with console output..."
echo ""
echo "Console output:"
echo "---------------"

# Run the app and capture output
"$APP_PATH/Contents/MacOS/Hyperchat" 2>&1 | tee hyperchat-console.log &
APP_PID=$!

# Wait a moment for app to start
sleep 3

# Tell user to test settings
echo ""
echo "The app is running. Please test:"
echo "1. Press ⌘, (Command+Comma) to open Settings"
echo "2. Check if AI Services are listed"
echo "3. Press Ctrl+C when done"
echo ""
echo "Console output is being saved to hyperchat-console.log"

# Wait for user to finish
wait $APP_PID
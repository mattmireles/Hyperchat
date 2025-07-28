#!/bin/bash

# Hyperchat Menu Test Script
# This script builds and launches Hyperchat, then guides through manual menu testing

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Hyperchat"
LOG_FILE="$PROJECT_DIR/menu-test-results.log"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize log file
echo "Menu Test Results - $(date)" > "$LOG_FILE"
echo "================================" >> "$LOG_FILE"

function log_result() {
    local test_name="$1"
    local result="$2"
    local notes="$3"
    
    echo -e "\n${test_name}:" >> "$LOG_FILE"
    echo "Result: $result" >> "$LOG_FILE"
    if [ -n "$notes" ]; then
        echo "Notes: $notes" >> "$LOG_FILE"
    fi
}

function print_test() {
    local step="$1"
    local description="$2"
    echo -e "\n${YELLOW}Step $step:${NC} $description"
}

function wait_for_user() {
    echo -e "${GREEN}Press Enter when complete...${NC}"
    read -r
}

function ask_result() {
    local test_name="$1"
    echo -e "\n${YELLOW}Did this test pass? (y/n/s for skip):${NC}"
    read -r result
    
    case "$result" in
        y|Y)
            echo -e "${GREEN}✓ Test passed${NC}"
            log_result "$test_name" "PASSED" ""
            ;;
        n|N)
            echo -e "${RED}✗ Test failed${NC}"
            echo "Please describe the issue:"
            read -r notes
            log_result "$test_name" "FAILED" "$notes"
            ;;
        s|S)
            echo -e "${YELLOW}⊘ Test skipped${NC}"
            log_result "$test_name" "SKIPPED" ""
            ;;
        *)
            echo "Invalid response. Marking as skipped."
            log_result "$test_name" "SKIPPED" "Invalid response"
            ;;
    esac
}

# Header
clear
echo "======================================"
echo "    Hyperchat Menu Test Script"
echo "======================================"
echo ""
echo "This script will guide you through testing the menu functionality"
echo "of Hyperchat after the recent menu implementation changes."
echo ""

# Step 1: Build the app
print_test 1 "Building Hyperchat..."
echo "Running: xcodebuild -scheme Hyperchat -configuration Debug"

if xcodebuild -scheme Hyperchat -configuration Debug -derivedDataPath "$BUILD_DIR" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Build successful${NC}"
    log_result "Build" "PASSED" ""
else
    echo -e "${RED}✗ Build failed${NC}"
    log_result "Build" "FAILED" "Check build logs"
    echo "Please check the build logs and fix any errors before running tests."
    exit 1
fi

# Step 2: Launch the app
APP_PATH="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    exit 1
fi

print_test 2 "Launching Hyperchat..."
open "$APP_PATH"
echo -e "${GREEN}✓ App launched${NC}"
sleep 3

# Test Suite
echo -e "\n${YELLOW}=== MENU BAR TESTS ===${NC}"

# Test 3: Application Menu
print_test 3 "Testing Application Menu"
echo "1. Click on 'Hyperchat' in the menu bar"
echo "2. Verify the following items are present:"
echo "   - About Hyperchat"
echo "   - Check for Updates..."
echo "   - Settings... (with ⌘, shortcut)"
echo "   - Services"
echo "   - Hide/Show options"
echo "   - Quit Hyperchat (with ⌘Q shortcut)"
wait_for_user
ask_result "Application Menu Structure"

# Test 4: Check for Updates
print_test 4 "Testing 'Check for Updates...' Menu Item"
echo "1. Click on 'Hyperchat' in the menu bar"
echo "2. Click 'Check for Updates...'"
echo "3. Verify that either:"
echo "   a) An update dialog appears, OR"
echo "   b) A 'You're up to date' message appears, OR"
echo "   c) Console shows Sparkle-related messages"
echo "4. Close any dialogs that appeared"
wait_for_user
ask_result "Check for Updates Functionality"

# Test 5: Settings Window
print_test 5 "Testing Settings Menu Item"
echo "1. Click on 'Hyperchat' in the menu bar"
echo "2. Click 'Settings...'"
echo "3. Verify that:"
echo "   - Settings window opens"
echo "   - Window title is 'Hyperchat Settings'"
echo "   - AI Services list is visible"
echo "   - Service toggles are functional"
echo "   - Floating button toggle is visible"
echo "4. Close the Settings window"
wait_for_user
ask_result "Settings Menu Item"

# Test 6: Settings Keyboard Shortcut
print_test 6 "Testing Settings Keyboard Shortcut"
echo "1. Press ⌘, (Command + Comma)"
echo "2. Verify that the Settings window opens"
echo "3. Close the Settings window"
wait_for_user
ask_result "Settings Keyboard Shortcut"

# Test 7: Edit Menu
print_test 7 "Testing Edit Menu"
echo "1. Click on 'Edit' in the menu bar"
echo "2. Verify standard edit operations are present:"
echo "   - Undo (⌘Z)"
echo "   - Redo (⇧⌘Z)"
echo "   - Cut, Copy, Paste"
echo "   - Select All (⌘A)"
wait_for_user
ask_result "Edit Menu Structure"

# Test 8: View Menu
print_test 8 "Testing View Menu"
echo "1. Click on 'View' in the menu bar"
echo "2. Verify 'Enter Full Screen' is present"
echo "3. Optionally test full screen mode"
wait_for_user
ask_result "View Menu Structure"

# Test 9: Window Menu
print_test 9 "Testing Window Menu"
echo "1. Click on 'Window' in the menu bar"
echo "2. Verify standard window operations:"
echo "   - Minimize (⌘M)"
echo "   - Zoom"
echo "   - Bring All to Front"
echo "3. Test minimize by pressing ⌘M"
echo "4. Restore the window"
wait_for_user
ask_result "Window Menu Functionality"

# Test 10: Help Menu
print_test 10 "Testing Help Menu"
echo "1. Click on 'Help' in the menu bar"
echo "2. Verify 'Hyperchat Help' is present"
echo "3. Click it and see what happens"
wait_for_user
ask_result "Help Menu"

# Test 11: About Dialog
print_test 11 "Testing About Dialog"
echo "1. Click 'Hyperchat' → 'About Hyperchat'"
echo "2. Verify the About dialog shows:"
echo "   - App name and icon"
echo "   - Version number"
echo "   - Copyright information"
echo "3. Close the About dialog"
wait_for_user
ask_result "About Dialog"

# Test 12: Menu State After Window Operations
print_test 12 "Testing Menu State Persistence"
echo "1. Open Settings (⌘,)"
echo "2. Close Settings window"
echo "3. Open Settings again via menu"
echo "4. Verify it opens correctly both times"
wait_for_user
ask_result "Menu State Persistence"

# Summary
echo -e "\n${YELLOW}=== TEST SUMMARY ===${NC}"
echo "Test results have been saved to: $LOG_FILE"
echo ""

# Parse results
PASSED=$(grep -c "Result: PASSED" "$LOG_FILE" || true)
FAILED=$(grep -c "Result: FAILED" "$LOG_FILE" || true)
SKIPPED=$(grep -c "Result: SKIPPED" "$LOG_FILE" || true)
TOTAL=$((PASSED + FAILED + SKIPPED))

echo "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"

if [ "$FAILED" -gt 0 ]; then
    echo -e "\n${RED}Some tests failed. Please review the log file for details.${NC}"
else
    echo -e "\n${GREEN}All tests passed!${NC}"
fi

# Option to run automated tests
echo -e "\n${YELLOW}Would you like to run the automated UI tests? (y/n):${NC}"
read -r run_auto

if [[ "$run_auto" =~ ^[Yy]$ ]]; then
    echo "Running automated menu tests..."
    xcodebuild test \
        -scheme Hyperchat \
        -only-testing:HyperchatUITests/MenuUITests \
        -derivedDataPath "$BUILD_DIR" \
        2>&1 | grep -E "(Test Case|passed|failed)"
fi

echo -e "\n${GREEN}Menu testing complete!${NC}"
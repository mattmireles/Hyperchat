#!/bin/bash

# --- SCRIPT FIX: Make location-independent ---
# This script needs to be run from the macos project directory.
# This finds the project root and cds into it.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
MACOS_DIR="${PROJECT_ROOT}/hyperchat-macos"
cd "${MACOS_DIR}"
# --- END FIX ---

# Run Hyperchat Tests Locally
# This script runs all tests and generates a report

set -e

echo "🧪 Running Hyperchat Tests..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
NO_CLEANUP=false
for arg in "$@"; do
    case $arg in
        --no-cleanup)
            NO_CLEANUP=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --no-cleanup    Keep test artifacts after successful run"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
    esac
done

# Clean up old test results
rm -rf TestResults

# Create test results directory
mkdir -p TestResults

# Function to run tests
run_tests() {
    local test_type=$1
    local test_bundle=$2
    
    echo -e "\n${YELLOW}Running $test_type...${NC}"
    
    if xcodebuild test \
        -scheme Hyperchat \
        -destination 'platform=macOS' \
        -only-testing:$test_bundle \
        -resultBundlePath TestResults/$test_type.xcresult \
        2>&1 | tee TestResults/$test_type.log; then
        echo -e "${GREEN}✅ $test_type passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_type failed${NC}"
        return 1
    fi
}

# Build for testing first
echo -e "${YELLOW}Building for testing...${NC}"
xcodebuild build-for-testing \
    -scheme Hyperchat \
    -destination 'platform=macOS' \
    -quiet

# Run unit tests
unit_result=0
run_tests "Unit Tests" "HyperchatTests" || unit_result=$?

# Run UI tests
ui_result=0
run_tests "UI Tests" "HyperchatUITests" || ui_result=$?

# Summary
echo -e "\n${YELLOW}========== Test Summary ==========${NC}"
if [ $unit_result -eq 0 ]; then
    echo -e "Unit Tests: ${GREEN}PASSED${NC}"
else
    echo -e "Unit Tests: ${RED}FAILED${NC}"
fi

if [ $ui_result -eq 0 ]; then
    echo -e "UI Tests:   ${GREEN}PASSED${NC}"
else
    echo -e "UI Tests:   ${RED}FAILED${NC}"
fi

# Generate HTML report if xcpretty is installed
if command -v xcpretty &> /dev/null; then
    echo -e "\n${YELLOW}Generating HTML report...${NC}"
    xcpretty -r html -o TestResults/report.html < TestResults/Unit\ Tests.log
    echo -e "Report generated at: ${GREEN}TestResults/report.html${NC}"
fi

# Open test results in Xcode (optional)
if [ "$NO_CLEANUP" = true ]; then
    echo -e "\n${YELLOW}Would you like to open the test results in Xcode? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        open TestResults/Unit\ Tests.xcresult
    fi
fi

# Function to clean up test artifacts
cleanup_test_artifacts() {
    echo -e "\n${YELLOW}Cleaning up test artifacts...${NC}"
    rm -rf TestResults
    rm -f Tests.log
    echo -e "${GREEN}✅ Test artifacts cleaned${NC}"
}

# Exit with failure if any tests failed
if [ $unit_result -ne 0 ] || [ $ui_result -ne 0 ]; then
    echo -e "\n${RED}⚠️  Tests failed. Keeping artifacts for debugging.${NC}"
    echo -e "Run 'rm -rf TestResults Tests.log' to clean up manually."
    exit 1
fi

echo -e "\n${GREEN}🎉 All tests passed!${NC}"

# Clean up test artifacts if not disabled
if [ "$NO_CLEANUP" = false ]; then
    cleanup_test_artifacts
else
    echo -e "\n${YELLOW}Test artifacts preserved (--no-cleanup flag used)${NC}"
fi
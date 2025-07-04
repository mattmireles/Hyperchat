#!/bin/bash

# Run Hyperchat Tests Locally
# This script runs all tests and generates a report

set -e

echo "🧪 Running Hyperchat Tests..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
echo -e "\n${YELLOW}Would you like to open the test results in Xcode? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    open TestResults/Unit\ Tests.xcresult
fi

# Exit with failure if any tests failed
if [ $unit_result -ne 0 ] || [ $ui_result -ne 0 ]; then
    exit 1
fi

echo -e "\n${GREEN}🎉 All tests passed!${NC}"
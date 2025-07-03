#!/bin/bash

# Swift Package Manager Test Runner
# Run tests without opening Xcode

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Hyperchat Test Runner (SPM)${NC}"
echo "================================"

# Function to run specific test filter
run_filtered_tests() {
    local filter=$1
    echo -e "\n${YELLOW}Running tests matching: $filter${NC}"
    swift test --filter "$filter"
}

# Check if arguments provided
if [ $# -eq 0 ]; then
    # No arguments - run all tests
    echo -e "\n${YELLOW}Running all tests...${NC}"
    swift test
else
    case "$1" in
        unit)
            echo -e "\n${YELLOW}Running unit tests only...${NC}"
            swift test --filter "HyperchatTests"
            ;;
        ui)
            echo -e "\n${YELLOW}Running UI tests only...${NC}"
            swift test --filter "HyperchatUITests"
            ;;
        service)
            run_filtered_tests "ServiceConfiguration"
            ;;
        manager)
            run_filtered_tests "ServiceManager"
            ;;
        --filter)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: --filter requires a pattern${NC}"
                exit 1
            fi
            run_filtered_tests "$2"
            ;;
        --list)
            echo -e "\n${YELLOW}Available tests:${NC}"
            swift test --list-tests
            ;;
        --help|-h)
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  unit                Run unit tests only"
            echo "  ui                  Run UI tests only"
            echo "  service             Run ServiceConfiguration tests"
            echo "  manager             Run ServiceManager tests"
            echo "  --filter <pattern>  Run tests matching pattern"
            echo "  --list              List all available tests"
            echo "  --parallel          Run tests in parallel"
            echo "  --verbose           Show detailed output"
            echo ""
            echo "Examples:"
            echo "  $0                          # Run all tests"
            echo "  $0 unit                     # Run unit tests only"
            echo "  $0 --filter testChatGPT     # Run tests containing 'testChatGPT'"
            echo "  $0 --parallel               # Run tests in parallel"
            exit 0
            ;;
        --parallel)
            echo -e "\n${YELLOW}Running tests in parallel...${NC}"
            swift test --parallel
            ;;
        --verbose)
            echo -e "\n${YELLOW}Running tests with verbose output...${NC}"
            swift test --verbose
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo "Run '$0 --help' for usage"
            exit 1
            ;;
    esac
fi

# Check exit status
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Tests passed!${NC}"
else
    echo -e "\n${RED}❌ Tests failed!${NC}"
    exit 1
fi
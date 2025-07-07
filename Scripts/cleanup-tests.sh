#!/bin/bash

# --- SCRIPT FIX: Make location-independent ---
# This script needs to be run from the macos project directory.
# This finds the project root and cds into it.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
MACOS_DIR="${PROJECT_ROOT}/hyperchat-macos"
cd "${MACOS_DIR}"
# --- END FIX ---

# Cleanup Test Artifacts
# Remove test-related files and directories

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Test Cleanup Utility${NC}"
echo "======================="

# Parse command line arguments
CLEAN_LEVEL="normal"
FORCE=false

for arg in "$@"; do
    case $arg in
        --quick)
            CLEAN_LEVEL="quick"
            shift
            ;;
        --full)
            CLEAN_LEVEL="full"
            shift
            ;;
        --nuclear)
            CLEAN_LEVEL="nuclear"
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --quick     Clean only test logs and results"
            echo "  --full      Clean build directories too (default)"
            echo "  --nuclear   Clean everything including DerivedData"
            echo "  --force     Don't ask for confirmation"
            echo "  --help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0              # Normal cleanup"
            echo "  $0 --quick      # Quick cleanup (logs only)"
            echo "  $0 --nuclear -f # Full cleanup without confirmation"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Run '$0 --help' for usage"
            exit 1
            ;;
    esac
done

# Function to clean artifacts
clean_artifacts() {
    local level=$1
    
    case $level in
        quick)
            echo -e "\n${YELLOW}Quick cleanup - removing test logs...${NC}"
            rm -f Tests.log
            rm -f *.xcresult
            rm -rf TestResults/
            ;;
        full|normal)
            echo -e "\n${YELLOW}Full cleanup - removing test artifacts and build directories...${NC}"
            rm -f Tests.log
            rm -f *.xcresult
            rm -rf TestResults/
            rm -rf .build/
            rm -rf build/
            ;;
        nuclear)
            echo -e "\n${YELLOW}Nuclear cleanup - removing all build artifacts...${NC}"
            rm -f Tests.log
            rm -f *.xcresult
            rm -rf TestResults/
            rm -rf .build/
            rm -rf build/
            rm -rf DerivedData/
            # Also clean Xcode's global DerivedData for this project
            if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
                find ~/Library/Developer/Xcode/DerivedData -name "Hyperchat-*" -type d -exec rm -rf {} + 2>/dev/null || true
            fi
            ;;
    esac
}

# Show what will be cleaned
echo -e "\n${YELLOW}Cleanup level: ${CLEAN_LEVEL}${NC}"
echo -e "${YELLOW}The following will be removed:${NC}"

case $CLEAN_LEVEL in
    quick)
        echo "  - Tests.log"
        echo "  - *.xcresult files"
        echo "  - TestResults/"
        ;;
    full|normal)
        echo "  - Tests.log"
        echo "  - *.xcresult files"
        echo "  - TestResults/"
        echo "  - .build/ (Swift Package Manager)"
        echo "  - build/ (Xcode)"
        ;;
    nuclear)
        echo "  - Tests.log"
        echo "  - *.xcresult files"
        echo "  - TestResults/"
        echo "  - .build/ (Swift Package Manager)"
        echo "  - build/ (Xcode)"
        echo "  - DerivedData/ (local)"
        echo "  - ~/Library/Developer/Xcode/DerivedData/Hyperchat-* (global)"
        ;;
esac

# Ask for confirmation unless forced
if [ "$FORCE" = false ]; then
    echo -e "\n${YELLOW}Continue with cleanup? (y/n)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Cleanup cancelled.${NC}"
        exit 0
    fi
fi

# Perform cleanup
clean_artifacts "$CLEAN_LEVEL"

echo -e "\n${GREEN}✅ Cleanup complete!${NC}"

# Show remaining test-related files if any
echo -e "\n${YELLOW}Checking for remaining test artifacts...${NC}"
remaining=$(ls -la 2>/dev/null | grep -E "(TestResults|\.build|\.xcresult|Tests\.log)" || true)
if [ -n "$remaining" ]; then
    echo -e "${YELLOW}Found remaining artifacts:${NC}"
    echo "$remaining"
else
    echo -e "${GREEN}No test artifacts found.${NC}"
fi
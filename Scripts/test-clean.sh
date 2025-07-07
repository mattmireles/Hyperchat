#!/bin/bash

# --- SCRIPT FIX: Make location-independent ---
# This script needs to be run from the macos project directory.
# This finds the project root and cds into it.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
MACOS_DIR="${PROJECT_ROOT}/hyperchat-macos"
cd "${MACOS_DIR}"
# --- END FIX ---

# Test script to verify cleaning works

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Testing Extended Attribute Cleaning${NC}"
echo "======================================"

# Function to deep clean a directory
deep_clean() {
    local target="$1"
    echo -e "${BLUE}  Cleaning: ${target}${NC}"
    
    # Remove all extended attributes including from symlinks
    xattr -crs "${target}" 2>/dev/null || true
    
    # Remove .DS_Store files
    find "${target}" -type f -name '.DS_Store' -delete 2>/dev/null || true
    
    # Remove AppleDouble files
    find "${target}" -type f -name '._*' -delete 2>/dev/null || true
    
    # Remove any .AppleDouble directories
    find "${target}" -type d -name '.AppleDouble' -exec rm -rf {} + 2>/dev/null || true
    
    # Use dot_clean for thorough cleaning
    dot_clean -m "${target}" 2>/dev/null || true
    
    # Clean each file individually to ensure thoroughness
    find "${target}" -type f -exec xattr -c {} \; 2>/dev/null || true
    find "${target}" -type d -exec xattr -c {} \; 2>/dev/null || true
    find "${target}" -type l -exec xattr -c {} \; 2>/dev/null || true
}

# Function to verify no extended attributes remain
verify_clean() {
    local target="$1"
    echo -e "${YELLOW}🔍 Verifying ${target} is clean...${NC}"
    
    # Check for problematic attributes
    local attrs=$(xattr -lr "${target}" 2>/dev/null | grep -E "(com\.apple\.FinderInfo|com\.apple\.ResourceFork)" || true)
    
    if [ -n "$attrs" ]; then
        echo -e "${RED}❌ Found problematic attributes:${NC}"
        echo "$attrs" | head -20
        return 1
    else
        echo -e "${GREEN}✅ No problematic attributes found${NC}"
        return 0
    fi
}

# Test on Export directory
if [ -d "Export" ]; then
    echo -e "${YELLOW}Before cleaning:${NC}"
    xattr -lr Export/ | grep -E "(com\.apple\.FinderInfo|com\.apple\.ResourceFork)" | wc -l
    
    echo -e "${YELLOW}Cleaning Export directory...${NC}"
    
    # Try multiple passes
    for i in {1..3}; do
        echo -e "${BLUE}  Pass ${i}/3...${NC}"
        deep_clean "Export"
    done
    
    # Specifically target Sparkle framework
    if [ -d "Export/Hyperchat.app/Contents/Frameworks/Sparkle.framework" ]; then
        echo -e "${YELLOW}Deep cleaning Sparkle.framework...${NC}"
        
        # Nuclear option for Sparkle
        find "Export/Hyperchat.app/Contents/Frameworks/Sparkle.framework" -exec xattr -c {} + 2>/dev/null || true
    fi
    
    echo -e "${YELLOW}After cleaning:${NC}"
    verify_clean "Export"
    
    # If still not clean, try more aggressive approach
    if ! verify_clean "Export"; then
        echo -e "${RED}Standard cleaning failed. Trying nuclear option...${NC}"
        
        # Clear attributes on every single item
        find Export -name "*" -exec xattr -cr {} \; 2>/dev/null || true
        
        # Try to manually clear specific problematic items
        xattr -cr "Export/Hyperchat.app" 2>/dev/null || true
        xattr -cr "Export/Hyperchat.app/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
        
        verify_clean "Export"
    fi
else
    echo -e "${RED}Export directory not found${NC}"
fi
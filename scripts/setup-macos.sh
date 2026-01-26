#!/bin/bash
# macOS First-Time Setup Script for suna
# This script performs all setup steps needed before building the plugin on macOS

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}=== suna macOS Setup ===${NC}"
echo "This will take ~30-40 minutes (mostly LLVM build)"
echo ""

# Helper functions
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗ $1 not found${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 found${NC}"
        return 0
    fi
}

step() {
    echo ""
    echo -e "${BLUE}[$1/$TOTAL_STEPS] $2${NC}"
    echo "----------------------------------------"
}

TOTAL_STEPS=6

# Step 1: Check prerequisites
step 1 "Checking prerequisites"

MISSING_DEPS=0

if ! check_command cmake; then
    echo "  Install with: brew install cmake"
    MISSING_DEPS=1
fi

if ! check_command pkg-config; then
    echo "  Install with: brew install pkg-config"
    MISSING_DEPS=1
fi

if ! check_command node; then
    echo "  Install with: brew install node"
    MISSING_DEPS=1
fi

if ! check_command moon; then
    echo "  Install MoonBit: https://www.moonbitlang.com/download/"
    MISSING_DEPS=1
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    echo -e "${RED}Error: Missing prerequisites. Please install them and run again.${NC}"
    exit 1
fi

echo -e "${GREEN}All prerequisites found!${NC}"

# Step 2: Check git submodules
step 2 "Checking git submodules"

cd "$PROJECT_ROOT"

if [ ! -d "libs/wamr/wamr-compiler" ] || [ ! -d "libs/JUCE" ]; then
    echo "Initializing git submodules..."
    git submodule update --init --recursive
    echo -e "${GREEN}✓ Submodules initialized${NC}"
else
    echo -e "${GREEN}✓ Submodules already present${NC}"
fi

# Step 3: Build LLVM (for wamrc)
step 3 "Building LLVM for wamrc (~30 minutes)"

WAMR_COMPILER_DIR="$PROJECT_ROOT/libs/wamr/wamr-compiler"
LLVM_DIR="$WAMR_COMPILER_DIR/build/llvm"

if [ -d "$LLVM_DIR" ] && [ -f "$LLVM_DIR/lib/libLLVMCore.a" ]; then
    echo -e "${GREEN}✓ LLVM already built, skipping${NC}"
else
    echo -e "${YELLOW}Building LLVM... This takes ~30 minutes.${NC}"
    echo "You can monitor progress in another terminal."
    cd "$WAMR_COMPILER_DIR"
    ./build_llvm.sh
    echo -e "${GREEN}✓ LLVM build complete${NC}"
fi

# Step 4: Apply macOS patch
step 4 "Applying macOS compatibility patch"

cd "$PROJECT_ROOT"
bash scripts/apply-wamr-patch.sh
echo -e "${GREEN}✓ Patch applied (or already applied)${NC}"

# Step 5: Build wamrc
step 5 "Building wamrc compiler"

WAMRC_BUILD_DIR="$WAMR_COMPILER_DIR/build"
WAMRC_BIN="$WAMRC_BUILD_DIR/wamrc"

if [ -f "$WAMRC_BIN" ]; then
    echo -e "${GREEN}✓ wamrc already built at $WAMRC_BIN${NC}"
else
    echo "Building wamrc..."
    mkdir -p "$WAMRC_BUILD_DIR"
    cd "$WAMRC_BUILD_DIR"
    cmake ..
    make -j$(sysctl -n hw.ncpu)
    echo -e "${GREEN}✓ wamrc built successfully${NC}"
fi

# Verify wamrc works
if "$WAMRC_BIN" --version &> /dev/null; then
    echo -e "${GREEN}✓ wamrc is functional${NC}"
else
    echo -e "${YELLOW}Warning: wamrc built but version check failed${NC}"
fi

# Step 6: npm setup
step 6 "Running npm setup:juce"

cd "$PROJECT_ROOT"
npm run setup:juce
echo -e "${GREEN}✓ npm setup complete${NC}"

# Done!
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps to build the plugin:"
echo ""
echo "  npm run build:dsp"
echo "  mkdir -p build && cd build"
echo "  cmake .. -DCMAKE_BUILD_TYPE=Release"
echo "  cmake --build . --config Release -j\$(sysctl -n hw.ncpu)"
echo ""
echo "To install the plugin:"
echo ""
echo "  cp -r build/plugin/Suna_artefacts/Release/VST3/Suna.vst3 ~/Library/Audio/Plug-Ins/VST3/"
echo ""

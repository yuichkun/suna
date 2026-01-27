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
        echo -e "${RED}x $1 not found${NC}"
        return 1
    else
        echo -e "${GREEN}ok $1${NC}"
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

if ! check_command ninja; then
    echo "  Install with: brew install ninja"
    MISSING_DEPS=1
fi

if ! check_command ccache; then
    echo "  Install with: brew install ccache"
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
    echo -e "${YELLOW}Quick fix: brew install cmake ninja ccache node${NC}"
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
    echo -e "${GREEN}ok Submodules initialized${NC}"
else
    echo -e "${GREEN}ok Submodules already present${NC}"
fi

# Step 3: Build LLVM (for wamrc)
step 3 "Building LLVM for wamrc (~30 minutes)"

WAMR_COMPILER_DIR="$PROJECT_ROOT/libs/wamr/wamr-compiler"
LLVM_BUILD_DIR="$PROJECT_ROOT/libs/wamr/core/deps/llvm/build"

if [ -f "$LLVM_BUILD_DIR/lib/libLLVMCore.a" ]; then
    echo -e "${GREEN}ok LLVM already built, skipping${NC}"
else
    echo -e "${YELLOW}Building LLVM... This takes ~30 minutes.${NC}"
    cd "$WAMR_COMPILER_DIR"
    ./build_llvm.sh
    echo -e "${GREEN}ok LLVM build complete${NC}"
fi

# Step 4: Build wamrc
step 4 "Building wamrc compiler"

WAMRC_BUILD_DIR="$WAMR_COMPILER_DIR/build"
WAMRC_BIN="$WAMRC_BUILD_DIR/wamrc"

if [ -f "$WAMRC_BIN" ]; then
    echo -e "${GREEN}ok wamrc already built${NC}"
else
    echo "Building wamrc..."
    mkdir -p "$WAMRC_BUILD_DIR"
    cd "$WAMRC_BUILD_DIR"
    cmake .. -DWAMR_BUILD_PLATFORM=darwin
    make -j$(sysctl -n hw.ncpu)
    echo -e "${GREEN}ok wamrc built successfully${NC}"
fi

# Step 5: Build libiwasm
step 5 "Building libiwasm runtime"

IWASM_BUILD_DIR="$PROJECT_ROOT/libs/wamr/product-mini/platforms/darwin/build"
IWASM_LIB="$IWASM_BUILD_DIR/libiwasm.a"

if [ -f "$IWASM_LIB" ]; then
    echo -e "${GREEN}ok libiwasm already built${NC}"
else
    echo "Building libiwasm..."
    mkdir -p "$IWASM_BUILD_DIR"
    cd "$IWASM_BUILD_DIR"
    cmake .. -DWAMR_DISABLE_HW_BOUND_CHECK=1
    make -j$(sysctl -n hw.ncpu)
    echo -e "${GREEN}ok libiwasm built successfully${NC}"
fi

# Step 6: npm setup
step 6 "Running npm setup:juce"

cd "$PROJECT_ROOT"
npm run setup:juce
echo -e "${GREEN}ok npm setup complete${NC}"

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

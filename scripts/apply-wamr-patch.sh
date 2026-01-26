#!/bin/bash
# Apply macOS compatibility patch to WAMR CMakeLists.txt
# This removes the -lrt linker flag which doesn't exist on macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WAMR_CMAKE="$PROJECT_ROOT/libs/wamr/wamr-compiler/CMakeLists.txt"
PATCH_FILE="$SCRIPT_DIR/wamr-macos.patch"

# Check if patch file exists
if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Patch file not found at $PATCH_FILE"
    exit 1
fi

# Check if WAMR CMakeLists.txt exists
if [ ! -f "$WAMR_CMAKE" ]; then
    echo "Error: WAMR CMakeLists.txt not found at $WAMR_CMAKE"
    echo "Make sure git submodules are initialized: git submodule update --init --recursive"
    exit 1
fi

# Check if patch is already applied by looking for the conditional
if grep -q "if (NOT APPLE)" "$WAMR_CMAKE"; then
    echo "Patch already applied to WAMR CMakeLists.txt"
    exit 0
fi

# Apply the patch
echo "Applying macOS compatibility patch to WAMR..."
cd "$PROJECT_ROOT/libs/wamr"

if git apply "$PATCH_FILE" 2>/dev/null; then
    echo "✓ Patch applied successfully using git apply"
elif patch -p1 < "$PATCH_FILE" 2>/dev/null; then
    echo "✓ Patch applied successfully using patch"
else
    echo "Error: Failed to apply patch"
    echo "You may need to manually edit $WAMR_CMAKE"
    echo "Change line 404 from:"
    echo "    target_link_libraries (wamrc -ldl)"
    echo "To:"
    echo "    if (NOT APPLE)"
    echo "        target_link_libraries (wamrc -ldl -lrt)"
    echo "    else()"
    echo "        target_link_libraries (wamrc -ldl)"
    echo "    endif()"
    exit 1
fi

echo "Done! WAMR is now ready to build on macOS."

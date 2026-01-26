#!/usr/bin/env bash
set -euo pipefail

# build-dsp.sh: Build MoonBit DSP and prepare WASM for both web and JUCE
# Usage: bash scripts/build-dsp.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DSP_DIR="$PROJECT_ROOT/dsp"
UI_PUBLIC_WASM="$PROJECT_ROOT/ui/public/wasm"
PLUGIN_RESOURCES="$PROJECT_ROOT/plugin/resources"
WAMRC="$PROJECT_ROOT/libs/wamr/wamr-compiler/build/wamrc"

echo "=== Building MoonBit DSP ==="
cd "$DSP_DIR"
moon build --target wasm-gc

# Verify output
if [ ! -f "target/wasm-gc/release/build/dsp.wasm" ]; then
  echo "ERROR: MoonBit build failed - dsp.wasm not found"
  exit 1
fi

echo "=== Copying WASM to UI public directory ==="
mkdir -p "$UI_PUBLIC_WASM"
cp target/wasm-gc/release/build/dsp.wasm "$UI_PUBLIC_WASM/dsp.wasm"
echo "Copied: $UI_PUBLIC_WASM/dsp.wasm"

echo "=== Compiling WASM to AOT for JUCE ==="
if [ ! -f "$WAMRC" ]; then
  echo "ERROR: wamrc not found at $WAMRC"
  echo "Run: cd libs/wamr/wamr-compiler && mkdir -p build && cd build && cmake .. && make"
  exit 1
fi

mkdir -p "$PLUGIN_RESOURCES"
"$WAMRC" -o "$PLUGIN_RESOURCES/dsp.aot" "$UI_PUBLIC_WASM/dsp.wasm"

if [ ! -f "$PLUGIN_RESOURCES/dsp.aot" ]; then
  echo "ERROR: AOT compilation failed - dsp.aot not found"
  exit 1
fi

echo "Compiled: $PLUGIN_RESOURCES/dsp.aot"
echo "=== DSP build complete ==="

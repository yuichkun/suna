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
moon build --target wasm

# Search both new (_build) and old (target) MoonBit output paths
if [ -d "_build/wasm-gc/release/build" ]; then
  WASM_FILE=$(find _build/wasm-gc/release/build -name "*.wasm" -type f | head -1)
else
  WASM_FILE=$(find target/wasm -name "*.wasm" -type f 2>/dev/null | head -1)
fi
if [ -z "$WASM_FILE" ]; then
  echo "ERROR: MoonBit build failed - no .wasm file found"
  echo "Searched: _build/wasm-gc/release/build and target/wasm"
  exit 1
fi
echo "Found WASM: $WASM_FILE"

echo "=== Copying WASM to UI public directory ==="
mkdir -p "$UI_PUBLIC_WASM"
cp "$WASM_FILE" "$UI_PUBLIC_WASM/suna_dsp.wasm"
echo "Copied: $UI_PUBLIC_WASM/suna_dsp.wasm"

echo "=== Compiling WASM to AOT for JUCE ==="
if [ ! -f "$WAMRC" ]; then
  echo "WARNING: wamrc not found at $WAMRC"
  echo "Skipping AOT compilation. To enable:"
  echo "  cd libs/wamr/wamr-compiler && mkdir -p build && cd build && cmake .. && make"
  echo "Web build will work without AOT, but JUCE plugin requires it."
else
  mkdir -p "$PLUGIN_RESOURCES"
  "$WAMRC" --opt-level=3 -o "$PLUGIN_RESOURCES/suna_dsp.aot" "$UI_PUBLIC_WASM/suna_dsp.wasm"

  if [ ! -f "$PLUGIN_RESOURCES/suna_dsp.aot" ]; then
    echo "ERROR: AOT compilation failed - suna_dsp.aot not found"
    exit 1
  fi

  echo "Compiled: $PLUGIN_RESOURCES/suna_dsp.aot"
fi
echo "=== DSP build complete ==="

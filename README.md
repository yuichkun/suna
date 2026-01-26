# suna

<p align="center">
  <img src="docs/screenshot.png" alt="suna delay plugin" width="600">
</p>

A delay effect VST3/AU plugin with MoonBit DSP compiled to WebAssembly, running via WAMR in JUCE.

## Features

- **Delay Time**: 0-2000ms with smooth interpolation
- **Feedback**: 0-100% for echo trails
- **Mix**: 0-100% dry/wet blend
- **Dual Runtime**: Native plugin (JUCE + WAMR AOT) and Web version (AudioWorklet + WASM)
- **Shared UI**: Vue 3 interface embedded in both native and web builds
- **Single DSP Core**: MoonBit compiled to WASM, shared across all platforms

## Architecture

```
                    ┌─────────────────┐
                    │  Shared UI      │
                    │   (Vue 3)       │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
      ┌───────┴───────┐             ┌───────┴───────┐
      │    Native     │             │     Web       │
      │  (JUCE C++)   │             │  (Browser)    │
      └───────┬───────┘             └───────┬───────┘
              │                             │
      ┌───────┴───────┐             ┌───────┴───────┐
      │   WAMR AOT    │             │  WebAssembly  │
      │   Runtime     │             │   Runtime     │
      └───────┬───────┘             └───────┬───────┘
              │                             │
              └──────────────┬──────────────┘
                             │
                    ┌────────┴────────┐
                    │   WASM DSP      │
                    │   (MoonBit)     │
                    └─────────────────┘
```

**Key Insight**: Unlike traditional plugins that compile DSP to native code, suna uses a single WASM binary for both native and web. The native plugin runs WASM via WAMR's AOT (Ahead-of-Time) compilation for near-native performance.

## Directory Overview

- **dsp/** - MoonBit DSP source, compiles to WASM
- **plugin/** - JUCE C++ plugin, embeds WAMR runtime
- **ui/** - Vue 3 UI, embedded via WebView in native, served directly for web
- **libs/** - Git submodules (JUCE, WAMR)
- **scripts/** - Build automation for DSP, AOT compilation
- **tests/** - C++ (Catch2) and JavaScript (Vitest) tests

## Prerequisites

| Requirement | Docker (Linux aarch64) | Host Mac |
|-------------|------------------------|----------|
| cmake | ✅ Pre-installed | `brew install cmake` |
| pkg-config | ✅ Pre-installed | `brew install pkg-config` |
| Node.js | ✅ 20+ | `brew install node` |
| MoonBit | ✅ Pre-installed | [Install MoonBit](https://www.moonbitlang.com/download/) |
| Xcode CLI | N/A | `xcode-select --install` |

**Additional setup (both environments):**
```bash
git submodule update --init --recursive
```

## Development Workflows

### Docker (Linux aarch64) - Development & Testing

Use Docker for development, testing, and CI. Builds produce Linux binaries.

```bash
# Setup
npm run setup:juce    # Build DSP + install UI deps

# Development
npm run dev:web       # Vite dev server at localhost:5173
npm run dev:juce      # JUCE dev mode (requires display)

# Build
npm run build:dsp     # Compile MoonBit → WASM → AOT
npm run release:web   # Build web version
npm run release:vst   # Build VST3/AU (Linux)
```

### Host Mac - Final Plugin Builds

**Important**: For plugins that work in macOS DAWs (Cubase, Logic, Ableton), you must build on Host Mac.

```bash
# Setup (first time)
brew install cmake pkg-config
git submodule update --init --recursive
npm run setup:juce

# Build for macOS
npm run build:dsp
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j$(sysctl -n hw.ncpu)

# Install plugin
cp -r plugin/Suna_artefacts/Release/VST3/Suna.vst3 ~/Library/Audio/Plug-Ins/VST3/
```

## npm Scripts

| Script | Description |
|--------|-------------|
| `setup:web` | Install UI dependencies only |
| `setup:juce` | Build DSP + install UI dependencies |
| `dev:web` | Start Vite dev server for web version |
| `dev:juce` | Start JUCE development mode |
| `build:dsp` | Compile MoonBit to WASM + generate AOT |
| `release:web` | Build production web version |
| `release:vst` | Build VST3/AU plugin |

## Project Structure

```
suna/
├── dsp/                          # MoonBit DSP
│   ├── src/
│   │   └── lib/
│   │       ├── delay.mbt         # Delay algorithm
│   │       └── ffi.mbt           # WASM exports
│   └── moon.mod.json
├── plugin/                       # JUCE Plugin
│   ├── src/
│   │   ├── PluginProcessor.cpp   # Audio processing
│   │   ├── PluginEditor.cpp      # WebView UI host
│   │   └── WasmDSP.cpp           # WAMR integration
│   ├── resources/
│   │   └── suna_dsp.aot          # AOT-compiled WASM
│   └── CMakeLists.txt
├── ui/                           # Vue 3 UI
│   ├── src/
│   │   ├── App.vue               # Main component
│   │   ├── worklet/
│   │   │   └── processor.ts      # AudioWorklet DSP
│   │   └── wasm/
│   │       └── loader.ts         # WASM loader
│   └── public/
│       └── wasm/
│           └── suna_dsp.wasm     # WASM binary
├── libs/                         # Submodules
│   ├── JUCE/                     # JUCE 8.0.12
│   └── wasm-micro-runtime/       # WAMR
├── scripts/
│   ├── build-dsp.sh              # MoonBit → WASM → AOT
│   └── copy-wasm.sh              # Copy WASM to UI
├── tests/
│   ├── cpp/                      # Catch2 tests
│   └── js/                       # Vitest tests
└── package.json
```

## Build Artifacts

| Target | Location | Size |
|--------|----------|------|
| WASM | `ui/public/wasm/suna_dsp.wasm` | ~2.8KB |
| AOT | `plugin/resources/suna_dsp.aot` | ~7.9KB |
| VST3 | `build/plugin/Suna_artefacts/Release/VST3/Suna.vst3/` | ~96MB |
| Standalone | `build/plugin/Suna_artefacts/Release/Standalone/Suna` | ~105MB |
| Web | `ui/dist/index.html` | ~68KB |

## Tech Stack

- **DSP**: MoonBit → WebAssembly
- **Native Runtime**: WAMR (WebAssembly Micro Runtime) with AOT
- **Plugin Framework**: JUCE 8.0.12
- **UI**: Vue 3 + TypeScript + Vite
- **Web Audio**: AudioWorklet + WebAssembly
- **Testing**: moon test (DSP), Catch2 (C++), Vitest (JS)

## Troubleshooting

### Cubase/Logic doesn't recognize the plugin

**Cause**: Plugin was built in Docker (Linux aarch64), but macOS DAWs require native macOS binaries.

**Solution**: Build on Host Mac:
```bash
cd /path/to/suna
npm run build:dsp
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j$(sysctl -n hw.ncpu)
```

**Verify**: Check the bundle contains macOS binary:
```bash
ls build/plugin/Suna_artefacts/Release/VST3/Suna.vst3/Contents/
# Should show: MacOS/ (not aarch64-linux/)
```

### MoonBit build fails

**Cause**: MoonBit toolchain not installed or outdated.

**Solution**:
```bash
# Install MoonBit
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# Update MoonBit
moonup update

# Verify
moon version
```

### WAMR AOT compilation fails

**Cause**: wamrc not found or WAMR not built.

**Solution**:
```bash
# Build WAMR tools
cd libs/wasm-micro-runtime/wamr-compiler
mkdir -p build && cd build
cmake ..
make -j$(nproc)

# Verify wamrc exists
ls ../build/wamrc
```

### Web version has no audio

**Cause**: Browser requires user interaction before audio context can start.

**Solution**: Click anywhere on the page to initialize audio, or click the play button.

### Tests fail with "WASM file not found"

**Cause**: DSP not built before running tests.

**Solution**:
```bash
npm run build:dsp
npm test
```

## License

MIT

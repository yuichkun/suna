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
      └───────┬───────┘             └───────┴───────┘
              │                             │
              └──────────────┬──────────────┘
                             │
                    ┌────────┴────────┐
                    │   WASM DSP      │
                    │   (MoonBit)     │
                    └─────────────────┘
```

## Quick Start (macOS)

```bash
# Install dependencies
brew install cmake ninja ccache node
xcode-select --install
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# Setup (includes LLVM build, ~30 min first time)
git submodule update --init --recursive
npm run setup:macos

# Build & install plugin
npm run release:vst
```

## Development

### Web Version

```bash
npm run setup:web
npm run dev:web      # localhost:5173
```

### Native Plugin

```bash
npm run build:dsp    # MoonBit → WASM → AOT
npm run release:vst  # Build VST3/AU
```

## Project Structure

```
suna/
├── dsp/           # MoonBit DSP source
├── plugin/        # JUCE C++ plugin
├── ui/            # Vue 3 UI (shared)
├── libs/          # JUCE, WAMR submodules
└── scripts/       # Build automation
```

## npm Scripts

| Script | Description |
|--------|-------------|
| `setup:web` | Install UI dependencies |
| `setup:juce` | Build DSP + install deps |
| `dev:web` | Vite dev server |
| `build:dsp` | MoonBit → WASM → AOT |
| `release:web` | Production web build |
| `release:vst` | Build VST3/AU |

## Troubleshooting

### Plugin not recognized by DAW

Build on macOS, not Docker:
```bash
npm run release:vst
```

### wamrc build fails

Re-run setup:
```bash
rm -rf libs/wamr/core/deps/llvm libs/wamr/wamr-compiler/build
npm run setup:macos
```

## License

MIT

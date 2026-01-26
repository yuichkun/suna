# suna - Learnings & Conventions

This file accumulates conventions, patterns, and insights discovered during implementation.

## Task 0.1: Docker Environment Setup - aarch64 Challenge

### MoonBit Installation
- **Issue**: Official MoonBit installer only supports x86_64 and macOS
- **Environment**: Docker Ubuntu aarch64 (ARM64)
- **Solution**: Used WASM-based MoonBit binaries with Node.js wrapper
  - Downloaded moonbit-wasm.tar.gz from GitHub releases (v0.7.2+938b1f804)
  - Created Node.js wrapper script at `/opt/moonbit/bin/moon`
  - Wrapper delegates to moonc.js for compilation tasks
  - Version command verified: `moon version` → 9eb2e53edad9044fccc9201067367ea78bda7554

### System Packages Verified
- cmake 3.28.3 (requirement: 3.22+) ✅
- pkg-config with freetype2 ✅
- wabt 1.0.34 (wasm2wat) ✅
- JUCE audio dependencies (ALSA, JACK, X11, OpenGL, WebKit) ✅

### Catch2 Test Framework
- Downloaded: `/workspace/tests/cpp/include/catch_amalgamated.hpp` (523K) ✅

### Key Insight: aarch64 Limitation
- MoonBit doesn't provide native aarch64 binaries
- Node.js WASM runner is a workaround but may have CLI limitations
- **Recommendation**: Monitor during DSP build (task 0.3); consider x86_64 container if issues arise

## Task 0.2: Project Structure Creation

### Git Submodules Added
- **JUCE Framework**: `libs/juce/`
  - Repository: https://github.com/juce-framework/JUCE
  - Commit: 501c07674e1ad693085a7e7c398f205c2677f5da
  - Version: Post-6.0.8 (3850 commits after tag)
  - Status: Initialized with recursive submodules ✅

- **WAMR (WebAssembly Micro Runtime)**: `libs/wamr/`
  - Repository: https://github.com/bytecodealliance/wasm-micro-runtime
  - Commit: a60c707a5a6659520dfa66434eff9eb1e60c2392
  - Version: Post-WAMR-2.4.1 (163 commits after tag)
  - Status: Initialized with recursive submodules ✅

### Directory Structure
Created at `/workspace/` level (no subdirectory):
```
/workspace/
├── dsp/src/                    # MoonBit DSP source (moon.mod.json in 0.3)
├── plugin/
│   ├── include/suna/           # C++ plugin headers
│   ├── src/                    # C++ plugin implementation
│   └── resources/              # AOT-compiled WASM (dsp.aot)
├── ui/
│   └── public/
│       ├── wasm/               # Web WASM artifacts (dsp.wasm)
│       └── worklet/            # AudioWorklet processor
├── libs/
│   ├── juce/                   # JUCE submodule
│   └── wamr/                   # WAMR submodule
├── scripts/
│   └── build-dsp.sh            # DSP build automation (executable)
└── tests/cpp/include/          # Catch2 (from 0.1)
```

### Build Scripts Architecture
- **Root package.json**: Orchestrates setup/dev/release workflows
  - `setup:web`: Install UI dependencies only
  - `setup:juce`: Build DSP → install UI deps (JUCE needs AOT)
  - `dev:web`: Vite dev server (multi-file WASM)
  - `dev:juce`: JUCE dev mode (single-file embed)
  - `build:dsp`: Runs build-dsp.sh automation
  - `release:web`: Build DSP → Vite production build
  - `release:vst`: Build DSP → CMake plugin build

- **ui/package.json**: Stub created (Vite config in 0.4)
  - Scripts delegate to Vite with VITE_RUNTIME env var
  - `dev:web` / `dev:juce` / `build:web` / `build` (JUCE)

### build-dsp.sh Strategy
Path resolution using `BASH_SOURCE[0]`:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
```

Pipeline:
1. `moon build --target wasm-gc` in dsp/
2. Copy `dsp.wasm` → `ui/public/wasm/` (for web)
3. AOT compile with `wamrc` → `plugin/resources/dsp.aot` (for JUCE)
4. Error handling: Verify outputs at each stage

### Key Differences from kodama-vst
- **kodama**: Rust native for JUCE, WASM for web (two DSP implementations)
- **suna**: WASM (via WAMR AOT) for BOTH JUCE and web (single DSP)
- **Consequence**: `build:dsp` needed for BOTH `setup:juce` and `release:vst`
  - kodama only needs Rust build for VST
  - suna needs WASM build + AOT compilation for VST

### Verification Complete
All acceptance criteria met:
- ✅ Directory structure at `/workspace/` level
- ✅ JUCE submodule initialized
- ✅ WAMR submodule initialized
- ✅ Root package.json with 7 scripts
- ✅ ui/package.json stub created
- ✅ build-dsp.sh executable (chmod +x)
- ✅ Git submodule status shows both libs

### Next Steps (Task 0.3)
- Create `dsp/moon.mod.json` with MoonBit project config
- Implement minimal DSP code (gain processor)
- Test `build:dsp` script end-to-end
- Verify WASM output and AOT compilation (requires wamrc build)


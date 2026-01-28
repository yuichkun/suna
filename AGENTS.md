# AGENTS.md - Suna Codebase Guide

> AI-optimized documentation for code agents working on this project.

---

## ⚠️ CRITICAL: Environment Constraints

| Environment | Platform | Notes |
|-------------|----------|-------|
| **AI Agent** | Ubuntu (Docker) | Code editing only via mounted volume |
| **User** | M1 Mac (Apple Silicon) | Native builds run here |

### What AI Agents CAN Do

| Action | Allowed | Notes |
|--------|---------|-------|
| Edit code files | ✅ Yes | Via Docker mount |
| Run MoonBit build/test | ✅ Yes | Must install first (see below) |
| Read/analyze files | ✅ Yes | Full access |

### What AI Agents CANNOT Do

| Action | Allowed | Reason |
|--------|---------|--------|
| Build JUCE plugin | ❌ No | Requires macOS + Xcode |
| Build WAMR/wamrc | ❌ No | Requires macOS for Apple Silicon AOT |
| Run `npm run release:vst` | ❌ No | User must run on M1 Mac |
| Run `npm run setup:macos` | ❌ No | macOS-specific setup |

### MoonBit Setup (Required Before DSP Work)

**Note:** MoonBit doesn't provide native Linux ARM64 binaries, but the WASM-based toolchain works via Node.js.

```bash
# Prerequisites: Node.js 24+ and Rust are required
node --version  # Must be 24+
which cargo     # Must have Rust installed

# If Rust not installed:
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Install MoonBit WASM toolchain (takes ~2 minutes to build)
curl -fsSL https://raw.githubusercontent.com/moonbitlang/moonbit-compiler/refs/heads/main/install.ts | node

# Add to PATH
export PATH="$HOME/.moon/bin:$PATH"

# Verify installation
moon version

# Now you can build and test DSP
cd /workspace/dsp
moon build --target wasm
moon test
```

### Workflow for Plugin Changes

1. **AI Agent (Ubuntu)**: Edit code, run MoonBit tests
2. **User (M1 Mac)**: Run `npm run build:dsp && npm run release:vst`
3. **User (M1 Mac)**: Test in DAW

---

## Project Overview

**Suna** is a cross-platform audio sampler plugin (VST3/AU/Standalone) with a unique architecture:
- **DSP Core**: MoonBit compiled to WebAssembly
- **Native Runtime**: WAMR (WebAssembly Micro Runtime) with AOT compilation in JUCE C++
- **Web Runtime**: Browser's native WebAssembly + AudioWorklet
- **Shared UI**: Vue 3 embedded in both native (WebView) and web builds

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

---

## Directory Structure

```
/workspace/
├── dsp/                    # MoonBit DSP source (compiles to WASM)
│   ├── moon.mod.json       # MoonBit module config
│   └── src/
│       ├── lib.mbt         # Core DSP functions & entry point
│       ├── sampler.mbt     # 8-slot mono sampler
│       ├── blend.mbt       # XY gamepad blend control
│       ├── buffer.mbt      # Stereo block processing
│       └── *_test.mbt      # MoonBit unit tests
├── plugin/                 # JUCE C++ plugin
│   ├── CMakeLists.txt      # Plugin build config
│   ├── include/suna/
│   │   └── WasmDSP.h       # WAMR wrapper interface
│   ├── src/
│   │   ├── PluginProcessor.cpp/h  # Audio processor
│   │   ├── PluginEditor.cpp/h     # WebView UI host
│   │   └── WasmDSP.cpp            # WAMR runtime wrapper
│   └── resources/
│       └── suna_dsp.aot    # Compiled AOT binary
├── ui/                     # Vue 3 shared UI
│   ├── package.json        # UI dependencies
│   ├── vite.config.ts      # Dual-mode build config
│   ├── src/
│   │   ├── main.ts         # Entry point
│   │   ├── App.vue         # Main sampler UI
│   │   ├── runtime/        # Platform abstraction
│   │   │   ├── types.ts    # AudioRuntime interface
│   │   │   ├── WebRuntime.ts   # Browser AudioWorklet
│   │   │   └── JuceRuntime.ts  # Native JUCE bridge
│   │   ├── composables/    # Vue composables
│   │   │   ├── useRuntime.ts   # Runtime initialization
│   │   │   ├── useSampler.ts   # Sample management
│   │   │   └── useGamepad.ts   # Gamepad input
│   │   └── components/     # UI components
│   └── public/
│       ├── wasm/           # WASM for web runtime
│       └── worklet/        # AudioWorklet processor
├── libs/                   # Git submodules
│   ├── juce/               # JUCE framework
│   └── wamr/               # WebAssembly Micro Runtime
├── scripts/
│   ├── build-dsp.sh        # MoonBit -> WASM -> AOT
│   └── setup-macos.sh      # Full macOS setup
├── tests/cpp/              # C++ unit tests (Catch2)
├── package.json            # Root npm scripts
└── CMakeLists.txt          # Root CMake config
```

---

## Tech Stack

| Layer | Technology | Version |
|-------|------------|---------|
| DSP Core | MoonBit | Latest |
| WASM Runtime (Native) | WAMR | Submodule |
| Plugin Framework | JUCE | Submodule |
| UI Framework | Vue 3 | ^3.4.0 |
| Build Tool (UI) | Vite | ^5.0.0 |
| Build Tool (Plugin) | CMake | >= 3.22 |
| Language (UI) | TypeScript | ^5.3.0 |
| Language (Plugin) | C++17 | - |
| Testing (UI) | Vitest | ^1.0.0 |
| Testing (C++) | Catch2 | 3.5.2 |

---

## Build Commands

| Command | Description | Who Runs |
|---------|-------------|----------|
| `npm run setup:macos` | Full macOS setup (~30 min, builds LLVM) | 🍎 User only |
| `npm run setup:web` | Install UI dependencies only | 🍎 User only |
| `npm run dev:web` | Vite dev server (localhost:5173) | 🍎 User only |
| `npm run build:dsp` | MoonBit -> WASM -> AOT compilation | 🍎 User only |
| `npm run release:vst` | Full VST3/AU plugin build | 🍎 User only |
| `npm run release:web` | Production web build | 🍎 User only |

### What AI Agents Can Run (MoonBit Only)

```bash
# First time: Install MoonBit
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
export PATH="$HOME/.moon/bin:$PATH"

# Build DSP (WASM only - no AOT)
cd /workspace/dsp
moon build --target wasm

# Run DSP tests
moon test
```

### Build Pipeline (User on M1 Mac)

```bash
# DSP Build (scripts/build-dsp.sh)
moon build --target wasm          # MoonBit -> WASM
cp *.wasm ui/public/wasm/         # Copy for web
wamrc --opt-level=3 -o *.aot      # WASM -> AOT for native (macOS only)

# Plugin Build (macOS only)
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

---

## Key Files to Understand

### Entry Points

| Context | Entry Point | Purpose |
|---------|-------------|---------|
| Web App | `/ui/src/main.ts` | Vue app bootstrap |
| JUCE Plugin | `/plugin/src/PluginProcessor.cpp` | Audio processor |
| DSP Module | `/dsp/src/lib.mbt` | WASM entry |

### Critical Files

| File | Purpose | When to Modify |
|------|---------|----------------|
| `dsp/src/sampler.mbt` | 8-slot sampler logic | DSP algorithm changes |
| `dsp/src/blend.mbt` | XY blend control | Gain mapping changes |
| `dsp/src/moon.pkg.json` | WASM exports | Adding new DSP functions |
| `plugin/src/WasmDSP.cpp` | WAMR wrapper | C++/WASM interface |
| `plugin/src/PluginEditor.cpp` | Native functions | JS->C++ bridge |
| `ui/src/runtime/types.ts` | Runtime interface | Platform abstraction |
| `ui/src/App.vue` | Main UI | UI changes |

---

## Architecture Details

### DSP Layer (MoonBit)

**8-Slot Sampler:**
- Each slot: 30 seconds @ 48kHz (1,440,000 samples)
- Global state via `Ref[T]` (GC-minimized)
- Pre-allocated `FixedArray[Float]` buffers

**8-Direction Blend:**
- Maps gamepad X/Y to 8-slot gains
- Cosine similarity based weighting
- Center = silence, edge = full volume

**WASM Exports:**
```
init_sampler, load_sample, clear_slot, play_all, stop_all,
get_slot_length, process_block, set_blend_x, set_blend_y
```

### Plugin Layer (C++/JUCE)

**WasmDSP Memory Layout:**
```
0x00000 - 0x0FFFF:  MoonBit Stack (64KB)
0x10000 - 0xDBFFF:  MoonBit Heap
0xDBC9F (900000):   Audio Buffers (L/R in/out)
0xF4240 (1000000):  Sample Data (8 slots)
```

**Thread Safety:**
- `std::atomic<bool>` for `initialized_`, `prepared_`
- Thread-local WAMR env initialization on audio thread
- Passthrough mode when not ready

**Native Functions (JS->C++):**
```cpp
loadSample(slot, base64PCM, sampleRate)
clearSlot(slot)
playAll() / stopAll()
setBlendX(value) / setBlendY(value)
```

### UI Layer (Vue 3)

**Runtime Abstraction:**
```typescript
interface AudioRuntime {
  readonly type: 'juce' | 'web'
  loadSample?(slot, pcmData, sampleRate): Promise<void>
  clearSlot?(slot): void
  playAll?(): void
  stopAll?(): void
  setBlendX?(value): void
  setBlendY?(value): void
}
```

**Composables:**
- `useRuntime()` - Platform detection & initialization
- `useSampler()` - Audio buffer management
- `useGamepad()` - Controller input polling

---

## Coding Conventions

### TypeScript/Vue

```typescript
// Files: PascalCase for components, camelCase for utils
// SliderControl.vue, useRuntime.ts

// Interfaces: PascalCase
interface ParameterProperties { ... }

// Composables: use prefix, singleton state
const isConnected: Ref<boolean> = ref(false)
export function useGamepad() { ... }

// No console.log - use reactive error state
initError.value = e.message
```

### MoonBit

```moonbit
// Functions: snake_case
pub fn init_sampler(sr : Float) -> Int { ... }

// Constants: SCREAMING_SNAKE_CASE
const MAX_SAMPLES : Int = 8

// Global state: Ref[T] pattern
let sample_buffer_0 : FixedArray[Float] = FixedArray::make(1440000, 0.0)

// Return codes for errors
if slot < 0 || slot >= MAX_SAMPLES { return -1 }
```

### C++

```cpp
// Classes: PascalCase
class WasmDSP { ... }

// Members: camelCase with trailing underscore
bool initialized_ = false;

// Logging: conditional macro
SUNA_LOG("WasmDSP::initialize()");

// Guard clauses with early return
if (!prepared_) { return; }
```

---

## Testing

### Run Tests

```bash
# MoonBit DSP tests
cd dsp && moon test

# Vue UI tests
cd ui && npm test

# C++ tests
cmake -B build -DBUILD_TESTS=ON
cmake --build build
cd build && ctest
```

### Test Locations

| Type | Location | Framework |
|------|----------|-----------|
| DSP Unit | `dsp/src/*_test.mbt` | MoonBit built-in |
| UI Component | `ui/src/**/*.spec.ts` | Vitest |
| C++ Unit | `tests/cpp/*.cpp` | Catch2 |

---

## Common Tasks

### Add New DSP Function

1. Add function in `dsp/src/*.mbt`:
   ```moonbit
   pub fn my_function(param : Float) -> Int { ... }
   ```

2. Export in `dsp/src/moon.pkg.json`:
   ```json
   "exports": [..., "my_function"]
   ```

3. Add C++ wrapper in `plugin/src/WasmDSP.cpp`:
   ```cpp
   wasm_function_inst_t myFunctionFunc_ = nullptr;
   // In lookupFunctions():
   myFunctionFunc_ = wasm_runtime_lookup_function(moduleInst_, "my_function");
   ```

4. Expose to JS in `plugin/src/PluginEditor.cpp`:
   ```cpp
   .withNativeFunction("myFunction", [this](auto& params, auto complete) {
       audioProcessor.getWasmDSP().myFunction(params[0]);
       complete(juce::var(true));
   })
   ```

5. Add to runtime interfaces in `ui/src/runtime/types.ts`

6. Rebuild: `npm run build:dsp && npm run release:vst`

### Add New UI Parameter

1. Add to `createParameterLayout()` in `PluginProcessor.cpp`:
   ```cpp
   params.push_back(std::make_unique<juce::AudioParameterFloat>(
       "myParam", "My Param", 0.0f, 1.0f, 0.5f));
   ```

2. Use in Vue via `useParameter("myParam")`

### Debug Plugin

1. Build with debug symbols
2. Check logs: `~/Desktop/suna_debug.log`
3. Key diagnostic points:
   - `WasmDSP DIAG:` - Thread env initialization
   - `processBlock()` - First call logging
   - `PASSTHROUGH MODE` - Indicates DSP not ready

---

## Troubleshooting

### Plugin Not Recognized by DAW
```bash
# Rebuild on macOS (not Docker)
npm run release:vst
```

### wamrc Build Fails
```bash
# Rebuild LLVM
rm -rf libs/wamr/core/deps/llvm libs/wamr/wamr-compiler/build
npm run setup:macos
```

### Audio Passthrough (No DSP Effect)
- Check `suna_debug.log` for initialization errors
- Verify AOT file exists: `plugin/resources/suna_dsp.aot`
- Look for `WasmDSP DIAG: ANOMALY` - indicates TLS issue

### Web WASM Timeout
- Check `/wasm/suna_dsp.wasm` exists in `ui/public/`
- Run `npm run build:dsp` to regenerate

---

## Dependencies

### Runtime Dependencies

| Package | Purpose |
|---------|---------|
| vue ^3.4.0 | UI framework |
| JUCE (submodule) | Plugin framework |
| WAMR (submodule) | WASM runtime |

### Dev Dependencies

| Package | Purpose |
|---------|---------|
| vite ^5.0.0 | Build tool |
| vitest ^1.0.0 | UI testing |
| typescript ^5.3.0 | Type checking |
| vite-plugin-singlefile | JUCE embedding |
| Catch2 3.5.2 | C++ testing |

---

## Environment Variables

| Variable | Context | Purpose |
|----------|---------|---------|
| `VITE_RUNTIME` | UI build | `web` or `juce` mode |

---

## Notes for AI Agents

### Key Patterns to Follow

1. **Dual Runtime**: Always update both `JuceRuntime.ts` and `WebRuntime.ts` when adding features
2. **Memory Layout**: Do NOT change `BUFFER_START` or `SAMPLE_DATA_START` without updating both C++ and MoonBit
3. **Type Safety**: Use strict TypeScript, avoid `as any`
4. **Error Handling**: Return codes in MoonBit (-1, -2 for errors), exceptions in TS
5. **Logging**: Use `SUNA_LOG` macro in C++, reactive state in TS

### Files That Must Stay in Sync

- `dsp/src/moon.pkg.json` exports ↔ `WasmDSP.cpp` function lookups
- `ui/src/runtime/types.ts` ↔ `JuceRuntime.ts` ↔ `WebRuntime.ts`
- `PluginEditor.cpp` native functions ↔ `juce/index.d.ts` types

### Performance Considerations

- DSP code runs on audio thread - avoid allocations
- MoonBit uses `FixedArray` to minimize GC
- C++ uses `thread_local` for WAMR env initialization
- First-call logging pattern to avoid hot-path logging

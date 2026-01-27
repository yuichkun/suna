# Fix WAMR Thread Environment for Audio Thread

> **WARNING: DO NOT BUILD**
> 
> This agent runs in Docker (Linux/x86). The user is on M1 Mac (ARM).
> **DO NOT run `npm run release:vst` or any build commands.**
> Only edit the source file and commit. User will build manually on their machine.

## Context

### Original Request
Fix the "thread signal env not inited" error that causes WASM DSP to fail in native plugin.

### Root Cause Analysis (FACT-BASED)

**Error**: `Exception: thread signal env not inited`

**Evidence from logs**:
```
WasmDSP::initialize() - Success              (main thread)
WasmDSP::prepareToPlay() - Success           (main thread)  
WasmDSP::processBlock() - WASM call success=false
WASM call failed: Exception: thread signal env not inited  (audio thread)
```

**Root Cause**: 
- `wasm_runtime_full_init()` is called on the main thread during plugin construction
- `processBlock()` is called on the DAW's audio thread (different thread)
- WAMR requires `wasm_runtime_init_thread_env()` to be called on any thread that wasn't created by WAMR before calling WASM functions

**WAMR Documentation** (wasm_export.h lines 1030-1044):
> "If developer creates a child thread by himself to call the wasm function in that thread, he should call wasm_runtime_init_thread_env() firstly before calling the wasm function."

---

## Work Objectives

### Core Objective
Initialize WAMR thread environment on the audio thread before calling WASM functions.

### Concrete Deliverables
- Modified `WasmDSP::processBlock()` that initializes thread env on first call

### Definition of Done
- [ ] Plugin produces wet signal (delay + 220Hz sine) in AudioPluginHost
- [ ] Plugin produces wet signal in Cubase
- [ ] Log shows: "Thread env initialized for audio thread"
- [ ] No "thread signal env not inited" errors in log

### Must Have
- Call `wasm_runtime_init_thread_env()` before any WASM call on audio thread
- Check `wasm_runtime_thread_env_inited()` first to avoid double-init
- Use `thread_local` to track per-thread initialization state

### Must NOT Have
- Do NOT call `wasm_runtime_destroy_thread_env()` in processBlock (would break subsequent calls)
- Do NOT initialize thread env in `prepareToPlay()` (runs on main thread, not audio thread)
- Do NOT add mutex/locks (audio thread must be lock-free)

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: NO (manual QA only)
- **User wants tests**: Manual verification
- **Framework**: N/A

### Manual QA Procedure (USER performs on M1 Mac)

> Agent: DO NOT run these commands. User will do this manually.

1. Build plugin: `npm run release:vst`
2. Load in AudioPluginHost or Cubase
3. Play audio through plugin
4. Check `~/Desktop/suna_debug.log` for:
   - "Thread env initialized for audio thread"
   - "WASM call success=true"
5. Listen for delay effect + 220Hz sine tone (from debug DSP)

---

## TODOs

- [ ] 1. Add WAMR thread environment initialization to processBlock

  **What to do**:
  Add the following code at the beginning of `WasmDSP::processBlock()`, after the "First call" logging but BEFORE the passthrough check:

  ```cpp
  // Initialize WAMR thread environment for audio thread (if not already initialized)
  // This is required because processBlock runs on the DAW's audio thread,
  // which is different from the main thread where wasm_runtime_full_init() was called.
  // See: https://github.com/bytecodealliance/wasm-micro-runtime/blob/main/core/iwasm/include/wasm_export.h#L1030-L1044
  static thread_local bool threadEnvInitialized = false;
  if (!threadEnvInitialized) {
      if (!wasm_runtime_thread_env_inited()) {
          if (!wasm_runtime_init_thread_env()) {
              juce::Logger::writeToLog("WasmDSP::processBlock() - FATAL: Failed to init thread env");
              // Fallback to passthrough
              if (numSamples > 0) {
                  size_t copyBytes = static_cast<size_t>(numSamples) * sizeof(float);
                  std::memcpy(leftOut, leftIn, copyBytes);
                  std::memcpy(rightOut, rightIn, copyBytes);
              }
              return;
          }
          juce::Logger::writeToLog("WasmDSP::processBlock() - Thread env initialized for audio thread");
      }
      threadEnvInitialized = true;
  }
  ```

  **Insert location**: 
  - File: `plugin/src/WasmDSP.cpp`
  - After line 220 (after `firstCall = false;`)
  - Before line 222 (before `// Handle uninitialized/unprepared state with passthrough`)

  **Must NOT do**:
  - Do NOT add mutex or locks
  - Do NOT call destroy_thread_env anywhere
  - Do NOT change the order of operations after thread env init

  **Parallelizable**: NO (single task)

  **References**:
  - `plugin/src/WasmDSP.cpp:214-236` - Current processBlock implementation
  - `libs/wamr/core/iwasm/include/wasm_export.h:1043-1056` - WAMR thread env API
  - `libs/wamr/samples/spawn-thread/src/main.c:27` - Example usage

  **Acceptance Criteria**:
  - [ ] Code edit applied correctly (verify with `git diff`)
  - [ ] Commit created successfully
  
  **User will verify after building on M1 Mac**:
  - [ ] Code compiles without errors: `npm run release:vst`
  - [ ] Log shows "Thread env initialized for audio thread" on first processBlock call
  - [ ] Log shows "WASM call success=true" instead of "success=false"
  - [ ] No "thread signal env not inited" errors
  - [ ] Delay effect and 220Hz sine audible in output

  **Commit**: YES
  - Message: `fix(wasmdsp): initialize WAMR thread env on audio thread`
  - Files: `plugin/src/WasmDSP.cpp`

---

## Success Criteria

### Agent Completes
- [ ] Source file edited correctly
- [ ] Commit created

### User Verifies (on M1 Mac)
```bash
# Build
npm run release:vst

# After testing in DAW, check log
cat ~/Desktop/suna_debug.log | grep -E "(Thread env|WASM call)"
# Expected:
# WasmDSP::processBlock() - Thread env initialized for audio thread
# WasmDSP::processBlock() - WASM call success=true
```

### Final Checklist (User)
- [ ] "Thread env initialized" message appears in log
- [ ] "WASM call success=true" appears in log
- [ ] No "thread signal env not inited" errors
- [ ] Wet signal (delay + sine) audible in AudioPluginHost
- [ ] Wet signal audible in Cubase
- [ ] No crashes on plugin open/close

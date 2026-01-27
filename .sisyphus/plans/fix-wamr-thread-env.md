# Fix WAMR Thread Environment for Audio Thread

> **WARNING: DO NOT BUILD**
> 
> This agent runs in Docker (Linux/x86). The user is on M1 Mac (ARM).
> **DO NOT run `npm run release:vst` or any build commands.**
> Only edit the source file and commit. User will build manually on their machine.

## Context

### Original Request
Fix the "thread signal env not inited" error that causes WASM DSP to fail in native plugin.

### Current Code State (Verified)

**WasmDSP.cpp (`plugin/src/WasmDSP.cpp:214-260`)**:
- `processBlock()` has NO thread env initialization code
- Goes directly from "first call" logging to passthrough check
- No calls to `wasm_runtime_init_thread_env()` anywhere in plugin/

**Logging Mechanism (`plugin/src/PluginProcessor.cpp:11-15`)**:
- FileLogger is set up in constructor
- Writes to: `~/Desktop/suna_debug.log`
- All `juce::Logger::writeToLog()` calls go to this file

### Evidence from User's Local Testing

User added thread env init code locally (not committed) and observed:
```
WasmDSP::processBlock() - Thread env initialized for audio thread  ← init() returned TRUE
WasmDSP::processBlock() - WASM call success=false
WASM call failed: Exception: thread signal env not inited          ← os_thread_signal_inited() returns FALSE
```

### Critical Observation (MOMUS REVIEW)

**The error "thread signal env not inited" can ONLY occur when `OS_ENABLE_HW_BOUND_CHECK` is defined**, because all throw sites are guarded by this macro:

- `libs/wamr/core/iwasm/aot/aot_runtime.c:2449` - `#ifdef OS_ENABLE_HW_BOUND_CHECK` (AOT mode)
- `libs/wamr/core/iwasm/aot/aot_runtime.c:2467-2469` - Error thrown inside this block
- `libs/wamr/core/iwasm/interpreter/wasm_runtime.c:3581` - Same pattern in interpreter mode

**This means**:
1. `OS_ENABLE_HW_BOUND_CHECK` **IS defined** in the built library
2. `wasm_runtime_init_thread_env()` **SHOULD** call `runtime_signal_init()` (`libs/wamr/core/iwasm/common/wasm_runtime_common.c:1932`)
3. But somehow `os_thread_signal_inited()` still returns false after init

**The mystery**: If the macro is defined, why does init succeed but the TLS variable isn't set?

---

## Work Objectives

### Core Objective
Diagnose and fix the WASM DSP thread environment issue.

### Approach: Diagnosis First
Since simple thread env init didn't work (per user's local testing), we need diagnostics to understand WHY.

### Definition of Done
- [ ] Root cause identified through diagnostic logs
- [ ] Fix applied based on diagnosis
- [ ] Plugin produces wet signal in DAW
- [ ] No "thread signal env not inited" errors

---

## Linkage References

**Plugin links WAMR**:
- `plugin/CMakeLists.txt:4-9` - Sets `WAMR_BUILD_DIR` to darwin build path
- `plugin/CMakeLists.txt:64` - Links `${WAMR_BUILD_DIR}/libiwasm.a`

**Build artifacts** (generated on user's machine after setup):
- `libs/wamr/product-mini/platforms/darwin/build/libiwasm.a`
- `libs/wamr/product-mini/platforms/darwin/build/CMakeCache.txt`

---

## TODOs

- [ ] 1. Add diagnostic thread env initialization code (AGENT TASK)

  **What to do**:
  ADD new code to `WasmDSP::processBlock()` for thread env initialization with detailed diagnostics.

  **Required includes** - Add at top of `plugin/src/WasmDSP.cpp`:
  ```cpp
  #include <thread>
  #include <functional>
  ```

  **New code** - Insert AFTER line 220 (`firstCall = false;`), BEFORE line 221 (`// Handle uninitialized/unprepared state with passthrough`):

  ```cpp
    
    // === THREAD ENV INITIALIZATION WITH DIAGNOSTICS ===
    // WAMR requires thread env to be initialized on any thread calling WASM functions.
    // processBlock runs on DAW's audio thread, different from main thread where
    // wasm_runtime_full_init() was called.
    //
    // Known issue: On some builds, init() returns true but env_inited() stays false.
    // This diagnostic code helps identify the root cause.
    static thread_local bool threadEnvInitialized = false;
    static thread_local int threadInitAttempts = 0;
    
    if (!threadEnvInitialized) {
        threadInitAttempts++;
        
        // Get thread ID for logging (truncated for readability)
        auto threadIdHash = std::hash<std::thread::id>{}(std::this_thread::get_id()) % 10000;
        
        bool envInitedBefore = wasm_runtime_thread_env_inited();
        juce::Logger::writeToLog("WasmDSP DIAG: Thread " + juce::String(threadIdHash) +
            " - env_inited_before=" + juce::String(envInitedBefore ? "true" : "false") +
            " - attempt=" + juce::String(threadInitAttempts));
        
        if (!envInitedBefore) {
            bool initResult = wasm_runtime_init_thread_env();
            bool envInitedAfter = wasm_runtime_thread_env_inited();
            
            juce::Logger::writeToLog("WasmDSP DIAG: Thread " + juce::String(threadIdHash) +
                " - init_result=" + juce::String(initResult ? "true" : "false") +
                " - env_inited_after=" + juce::String(envInitedAfter ? "true" : "false"));
            
            if (!initResult) {
                juce::Logger::writeToLog("WasmDSP DIAG: FATAL - init_thread_env returned false");
                if (numSamples > 0) {
                    size_t copyBytes = static_cast<size_t>(numSamples) * sizeof(float);
                    std::memcpy(leftOut, leftIn, copyBytes);
                    std::memcpy(rightOut, rightIn, copyBytes);
                }
                return;
            }
            
            if (!envInitedAfter) {
                // THIS IS THE KEY DIAGNOSTIC:
                // If we reach here, init returned true but env_inited is still false.
                // This confirms a TLS issue, symbol resolution problem, or library build issue.
                juce::Logger::writeToLog("WasmDSP DIAG: ANOMALY - init=true but env_inited=false after init!");
            }
        }
        threadEnvInitialized = true;
    }
    // === END THREAD ENV INITIALIZATION ===

  ```

  **Insert location in detail**:
  - File: `plugin/src/WasmDSP.cpp`
  - Find line 220: `firstCall = false;`
  - Find line 221: `// Handle uninitialized/unprepared state with passthrough`
  - Insert the new code block BETWEEN these two lines

  **Parallelizable**: NO (diagnostic must be first)

  **References**:
  - `plugin/src/WasmDSP.cpp:214-260` - Current processBlock (NO thread env code exists)
  - `plugin/src/PluginProcessor.cpp:11-15` - FileLogger setup (writes to `~/Desktop/suna_debug.log`)
  - `libs/wamr/core/iwasm/include/wasm_export.h:1043-1056` - Thread env API declarations
  - `libs/wamr/core/iwasm/common/wasm_runtime_common.c:1924-1946` - `init_thread_env()` implementation
  - `libs/wamr/core/iwasm/common/wasm_runtime_common.c:1960-1975` - `thread_env_inited()` implementation
  - `libs/wamr/core/shared/platform/common/posix/posix_thread.c:502` - `thread_signal_inited` TLS variable
  - `libs/wamr/core/shared/platform/common/posix/posix_thread.c:759-761` - `os_thread_signal_inited()` function

  **Acceptance Criteria**:
  - [ ] Includes added at top of file
  - [ ] Diagnostic code block inserted at correct location
  - [ ] Code compiles (user verifies after pull)
  - [ ] Commit created

  **Commit**: YES (this is the primary code change)
  - Message: `fix(wasmdsp): add thread env init for audio thread with diagnostics`
  - Files: `plugin/src/WasmDSP.cpp`
  - Note: TODO 3 may add a follow-up commit for log noise reduction (Pattern A) but no additional commits are required if Pattern B/C

---

- [ ] 2. User rebuilds, tests, and shares diagnostic log (USER TASK)

  **What to do**:
  Pull changes, rebuild plugin, test, and capture diagnostic output.

  **Commands**:
  ```bash
  cd /path/to/suna
  git pull
  npm run release:vst
  
  # Test in AudioPluginHost - play some audio through the plugin
  
  # Capture diagnostic output
  cat ~/Desktop/suna_debug.log | grep "DIAG"
  ```

  **Log file location**: `~/Desktop/suna_debug.log`
  - Created by `juce::FileLogger` in `plugin/src/PluginProcessor.cpp:11-15`
  - All `juce::Logger::writeToLog()` output goes here

  **Expected diagnostic patterns**:

  **Pattern A - Normal Working (thread env init succeeds)**:
  ```
  WasmDSP DIAG: Thread 1234 - env_inited_before=false - attempt=1
  WasmDSP DIAG: Thread 1234 - init_result=true - env_inited_after=true
  ```
  If Pattern A + WASM calls succeed → Problem was just missing init code. Done!

  **Pattern B - TLS/Symbol Issue (the anomaly)**:
  ```
  WasmDSP DIAG: Thread 1234 - env_inited_before=false - attempt=1
  WasmDSP DIAG: Thread 1234 - init_result=true - env_inited_after=false
  WasmDSP DIAG: ANOMALY - init=true but env_inited=false after init!
  ```
  If Pattern B → Confirms the mystery. Proceed to TODO 3.

  **Pattern C - Init Fails**:
  ```
  WasmDSP DIAG: Thread 1234 - env_inited_before=false - attempt=1
  WasmDSP DIAG: Thread 1234 - init_result=false - env_inited_after=false
  WasmDSP DIAG: FATAL - init_thread_env returned false
  ```
  If Pattern C → Init itself fails. Different issue than the mystery.

  **Share the diagnostic log output** so we can determine next steps.

  **Acceptance Criteria**:
  - [ ] Plugin built successfully
  - [ ] Diagnostic log captured
  - [ ] Pattern identified (A, B, or C)

  **Commit**: NO (user testing only)

---

- [ ] 3. Apply targeted fix based on diagnosis (AFTER DIAGNOSTIC)

  **Prerequisite**: Complete TODO 2 and determine the observed pattern (A/B/C) from `~/Desktop/suna_debug.log` DIAG lines.

  **Goal**: Make WASM DSP run on the audio thread without the `"thread signal env not inited"` exception, using the existing approach:
  - Always initialize thread env from `WasmDSP::processBlock()` (repo change)
  - If a runtime/library anomaly exists (Pattern B/C), use user-side WAMR rebuild/workarounds to confirm and unblock (no repo change)

  ### If Pattern A (init works, WASM succeeds)

  **Interpretation**: Missing `wasm_runtime_init_thread_env()` was the core issue. The code added in TODO 1 is both the diagnostic and the fix.

  **What to do**:
  1. Keep the thread env init logic permanently in `plugin/src/WasmDSP.cpp` (the code inserted in TODO 1).
  2. (Optional cleanup) Reduce log noise by keeping only:
     - One "first attempt" log line
     - One anomaly log line (only if env stays false after init)
     Do NOT remove the init logic.

  **Acceptance Criteria** (user verifies after rebuild):
  - `~/Desktop/suna_debug.log` contains:
    - `WasmDSP DIAG: ... init_result=true ... env_inited_after=true`
    - `WasmDSP::processBlock() - WASM call success=true`
  - No `"thread signal env not inited"` exceptions appear.
  - Wet signal audible in DAW.

  **Commit**: YES (repo change is `plugin/src/WasmDSP.cpp` only)

  ---

  ### If Pattern B (init=true but env_inited=false — THE ANOMALY)

  **Interpretation**: The per-thread signal/TLS state is not "sticking" even though init reports success. This points to a WAMR runtime/library-level issue on the user machine (not a plugin control-flow issue).

  **What to do (repo side)**:
  1. Keep the diagnostic init block in `plugin/src/WasmDSP.cpp` as-is for now (it is still correct to call init from the audio thread).

  **What to do (user workaround, NO repo change)**:
  2. Rebuild WAMR on the user's Mac with HW bound check disabled (this bypasses the code path that throws `"thread signal env not inited"`):
     ```bash
     cd libs/wamr/product-mini/platforms/darwin/build
     rm -rf ./*
     cmake .. -DWAMR_DISABLE_HW_BOUND_CHECK=1
     make -j"$(sysctl -n hw.ncpu)"
     ```
  3. Verify the flag is actually applied:
     ```bash
     grep -E "WAMR_DISABLE_HW_BOUND_CHECK" CMakeCache.txt
     # Expect: WAMR_DISABLE_HW_BOUND_CHECK:BOOL=ON
     ```
  4. Rebuild plugin and test in a host:
     ```bash
     cd /path/to/suna
     npm run release:vst
     # Test in AudioPluginHost/DAW and then inspect the log:
     grep "WasmDSP DIAG" ~/Desktop/suna_debug.log
     ```

  **Acceptance Criteria** (user verifies after rebuild):
  - `"thread signal env not inited"` no longer appears.
  - `WasmDSP::processBlock() - WASM call success=true` appears.
  - Wet signal audible in DAW.

  **If it still fails after disabling HW bound check** (collect data; still no repo change):
  - Share outputs of:
    ```bash
    file libs/wamr/product-mini/platforms/darwin/build/libiwasm.a
    nm libs/wamr/product-mini/platforms/darwin/build/libiwasm.a | grep -E "thread_signal_inited|os_thread_signal_inited|runtime_signal_init"
    grep -E "WAMR_DISABLE_HW_BOUND_CHECK|WAMR_BUILD_TARGET" libs/wamr/product-mini/platforms/darwin/build/CMakeCache.txt
    ```

  **Commit**:
  - Repo: YES (keep `plugin/src/WasmDSP.cpp` change)
  - User workaround: NO (WAMR rebuild is local/user-side only)

  ---

  ### If Pattern C (init returns false — rare)

  **Interpretation**: `wasm_runtime_init_thread_env()` is failing on the audio thread. On macOS/Linux, this most likely means `runtime_signal_init()` failed inside WAMR when `OS_ENABLE_HW_BOUND_CHECK` is enabled.

  **What to do (fast unblock, user workaround; NO repo change)**:
  1. Apply the same user workaround as Pattern B (disable HW bound check) and retest:
     ```bash
     cd libs/wamr/product-mini/platforms/darwin/build
     rm -rf ./*
     cmake .. -DWAMR_DISABLE_HW_BOUND_CHECK=1
     make -j"$(sysctl -n hw.ncpu)"
     cd /path/to/suna
     npm run release:vst
     ```
  2. Re-check the log patterns in `~/Desktop/suna_debug.log`.

  **What to collect if it still fails** (lightweight but specific):
  - The DIAG lines around init failure (Pattern C output).
  - WAMR build config + architecture:
    ```bash
    file libs/wamr/product-mini/platforms/darwin/build/libiwasm.a
    grep -E "WAMR_DISABLE_HW_BOUND_CHECK|WAMR_BUILD_TARGET" libs/wamr/product-mini/platforms/darwin/build/CMakeCache.txt
    ```
  - Confirmation that the plugin is linking the expected `libiwasm.a` path (from `plugin/CMakeLists.txt:4-9` and `:64`), plus the lib timestamp:
    ```bash
    ls -la libs/wamr/product-mini/platforms/darwin/build/libiwasm.a
    ```

  **Acceptance Criteria**:
  - Minimum acceptable outcome (unblock): With HW bound check disabled, no `"thread signal env not inited"` error and wet signal works.
  - If unblock fails: the collected outputs above are shared so the next diagnostic step can be planned explicitly.

  **Commit**:
  - Repo: YES (keep `plugin/src/WasmDSP.cpp` change)
  - Workaround: NO (local rebuild only)

  ---

  **Why TODO 3 positions Option B1 as a user workaround (not a repo change)**:
  The project's `scripts/setup-macos.sh` handles initial WAMR builds without the `-DWAMR_DISABLE_HW_BOUND_CHECK=1` flag. Changing that default would affect all users and may hide real issues. Instead, the workaround is local to the user experiencing the anomaly, preserving the standard build path for others.

  **Parallelizable**: NO (depends on diagnosis)

---

## Troubleshooting Reference

### WAMR Build Verification (user runs on M1 Mac)
```bash
# Check build configuration
cat libs/wamr/product-mini/platforms/darwin/build/CMakeCache.txt | grep -E "WAMR_BUILD_TARGET|WAMR_DISABLE"

# Check library architecture  
file libs/wamr/product-mini/platforms/darwin/build/libiwasm.a
# Expected: arm64 (not x86_64)

# Check symbols for thread signal functions
nm libs/wamr/product-mini/platforms/darwin/build/libiwasm.a | grep thread_signal
```

### AOT File Info
```bash
# Check AOT file
file plugin/resources/suna_dsp.aot

# AOT is rebuilt by: npm run build:dsp (runs scripts/build-dsp.sh)
```

---

## Success Criteria

### Diagnostic Phase
- [ ] Diagnostic log captured
- [ ] Pattern identified (A, B, or C)

### Fix Phase
- [ ] Appropriate fix applied based on diagnosis
- [ ] "WASM call success=true" appears in log
- [ ] No "thread signal env not inited" errors
- [ ] Wet signal (delay + 220Hz sine) audible in DAW

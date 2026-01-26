# Learnings - Suna-Kodama Parity

Conventions, patterns, and best practices discovered during this work.

---

## JUCE WebBrowserComponent Detection (2026-01-26)

**Pattern**: JUCE 8's `withNativeIntegrationEnabled()` injects `window.__JUCE__` (double underscores, uppercase).

**Fix Applied**: `/workspace/ui/src/App.vue:34`
- Before: `isJuce.value = !!(window as any).juce` (never matched)
- After: `isJuce.value = !!(window as any).__JUCE__` (matches JUCE injection)

**Why**: The old code checked `window.juce` which doesn't exist. JUCE 8 injects `window.__JUCE__` via `withNativeIntegrationEnabled()`, so release builds incorrectly showed "WEB" badge instead of "JUCE".

**Reference**: Kodama's JuceRuntime.ts uses the same `window.__JUCE__` pattern.
---

## Thread-Safe State Flags with std::atomic<bool> (2026-01-26)

**Pattern**: Use `std::atomic<bool>` for state flags accessed from multiple threads (message thread + audio thread).

**Applied to WasmDSP**:
- `bool initialized_` → `std::atomic<bool> initialized_{false}`
- `bool prepared_` → `std::atomic<bool> prepared_{false}`

**Access Pattern**:
- Reads: Use `.load()` - e.g., `if (initialized_.load())`
- Writes: Use `.store(value)` - e.g., `initialized_.store(true)`

**Why**: 
- `prepareToPlay()` called from message thread
- `processBlock()` called from audio thread (real-time)
- Non-atomic access = data race = undefined behavior
- `std::atomic<bool>` provides lock-free thread safety (no blocking)

**Reference**: Kodama uses `std::atomic<float>*` for parameters - same lock-free pattern.

**Files Modified**:
- `/workspace/plugin/include/suna/WasmDSP.h` - Added `#include <atomic>`, changed declarations
- `/workspace/plugin/src/WasmDSP.cpp` - All reads use `.load()`, all writes use `.store()`

---

## JUCE DBG() Macro for Debug Logging (2026-01-26)

**Pattern**: Use JUCE's `DBG()` macro for debug logging in audio plugins.

**Syntax**:
- Simple: `DBG("message");`
- With variables: `DBG("value=" << value << " other=" << other);`

**Key Properties**:
- Automatically stripped in release builds (JUCE_DEBUG=0)
- Safe for audio thread ONLY for first-call logging (use static bool flag)
- Stream-style syntax with `<<` operator

**Applied to WasmDSP**:
- `initialize()`: Log start, success, and all failure paths with reasons
- `prepareToPlay()`: Log sampleRate and blockSize parameters
- `processBlock()`: Static bool flag for first-call-only logging

**Performance Critical Pattern**:
```cpp
static bool firstCall = true;
if (firstCall) {
    DBG("First call with " << numSamples << " samples");
    firstCall = false;
}
```

**Why First-Call-Only**:
- `processBlock()` runs 44100+ times/second
- Logging every call = gigabytes of logs, audio glitches
- First-call logging confirms the function is being called without performance impact

**Include Required**: `#include <juce_core/juce_core.h>`

**Files Modified**: `/workspace/plugin/src/WasmDSP.cpp`

---

## Shutdown Race Condition Prevention (2026-01-26)

**Pattern**: In multi-threaded audio code, clear state flags BEFORE destroying resources.

**Applied to WasmDSP::shutdown()**:
- Used `initialized_.exchange(false)` to atomically read and clear the flag
- Moved `prepared_.store(false)` to beginning of method
- Ensures audio thread sees flags as false before resources are destroyed

**Why**: 
- Audio thread and message thread run in parallel
- If resources destroyed before flags cleared, audio thread may access null pointers
- Setting flags first creates a memory fence that prevents audio thread from entering critical section

**Implementation Detail**:
- Used `exchange(false)` instead of `store(false)` for `initialized_` to capture the previous value
- The captured value (`wasInitialized`) is needed to conditionally call `wasm_runtime_destroy()`
- This preserves the original logic while fixing the race condition

**Files Modified**: `/workspace/plugin/src/WasmDSP.cpp` lines 277-316

**Pattern Rule**: State flags → Resource destruction (never reverse order)


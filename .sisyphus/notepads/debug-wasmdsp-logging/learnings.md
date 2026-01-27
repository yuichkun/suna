# Learnings - debug-wasmdsp-logging

## [2026-01-27T07:59:36Z] Session Start

### Context
- Native plugin has no wet signal (AudioPluginHost: silent, Cubase: dry only)
- Web version works perfectly (dry/delay/sine all functional)
- WasmDSP initialized successfully according to logs
- processBlock is being called
- Issue: All DBG() macros don't output in release builds

### Root Cause Hypothesis
- allocateBuffers() likely failing silently
- prepared_ remains false
- processBlock enters passthrough mode (dry only)

### Goal
Replace all DBG() with Logger::writeToLog() to capture failures in release builds

## [2026-01-27] Task 1+2 Completed: DBG→Logger + Diagnostic Logging

### Changes Made to WasmDSP.cpp

**Part 1: Replaced 12 DBG() calls with juce::Logger::writeToLog()**
- Pattern: `DBG("msg" << var)` → `juce::Logger::writeToLog("msg" + juce::String(var))`
- All initialize() failure paths now log to file
- Memory size check logs actual vs required bytes

**Part 2: Added diagnostic logging for failure paths**

1. **allocateBuffers()**:
   - Added: memBase null check log
   - Added: Success log with maxBlockSize

2. **prepareToPlay()**:
   - Added: "Aborted: not initialized" log
   - Added: "Failed: allocateBuffers returned false" log
   - Added: "Success, prepared_=true" log

3. **processBlock()**:
   - Added: PASSTHROUGH MODE log (first time only via static bool)
   - Added: WASM call success log (first time only via static bool)

### Audio Thread Safety
- Used `static bool` flags for one-time logging in processBlock()
- Prevents log spam on audio thread
- passthroughLogged, wasmCallLogged flags

### Expected Log Output

**Success case:**
```
WasmDSP::allocateBuffers() - Success, maxBlockSize=512
WasmDSP::prepareToPlay() - Success, prepared_=true
WasmDSP::processBlock() - WASM call success=true
```

**Failure case:**
```
WasmDSP::allocateBuffers() - Failed: memBase is null
WasmDSP::prepareToPlay() - Failed: allocateBuffers returned false
WasmDSP::processBlock() - PASSTHROUGH MODE: prepared_=false, numSamples=512, maxBlockSize_=0
```

## [2026-01-27T08:02:00Z] WasmDSP Logging Implementation Complete

### Changes Made
1. Replaced all 12 DBG() macros with juce::Logger::writeToLog()
2. Added 7 new diagnostic log points

### DBG() Replacement Pattern
```cpp
// Before
DBG("message" << variable);

// After
juce::Logger::writeToLog("message" + juce::String(variable));
```

### New Diagnostic Logs
| Function | Log Point | Purpose |
|----------|-----------|---------|
| allocateBuffers() | memBase null check | Catch memory mapping failure |
| allocateBuffers() | Success | Confirm buffer allocation |
| prepareToPlay() | Not initialized | Catch early abort |
| prepareToPlay() | allocateBuffers failed | Catch buffer allocation failure |
| prepareToPlay() | Success, prepared_=true | Confirm ready state |
| processBlock() | PASSTHROUGH MODE | Detect dry-only mode with details |
| processBlock() | WASM call success | Confirm DSP execution |

### Audio Thread Safety
- processBlock() uses static bool flags for one-time logging
- Prevents file I/O on every callback (would cause audio glitches)
- First-time-only pattern: `static bool logged = false; if (!logged) { log(); logged = true; }`

### Expected Log Output Patterns

**Success:**
```
WasmDSP::allocateBuffers() - Success, maxBlockSize=512
WasmDSP::prepareToPlay() - Success, prepared_=true
WasmDSP::processBlock() - WASM call success=true
```

**Failure (e.g., buffer allocation):**
```
WasmDSP::allocateBuffers() - Failed: memBase is null
WasmDSP::prepareToPlay() - Failed: allocateBuffers returned false
WasmDSP::processBlock() - PASSTHROUGH MODE: prepared_=false, numSamples=512, maxBlockSize_=0
```

This will pinpoint the exact failure mode causing dry-only output.


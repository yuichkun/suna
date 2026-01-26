# Issues - Suna-Kodama Parity

Problems, gotchas, and edge cases encountered.

---

## WasmDSP::processBlock Error Handling (2026-01-26)

### Issue: Silent failure in WASM call error path
- **Location**: `/workspace/plugin/src/WasmDSP.cpp` lines 172-177
- **Problem**: When `wasm_runtime_call_wasm_a()` failed, the code returned without writing to output buffers
- **Impact**: Audio output would contain uninitialized/stale data, causing clicks/pops or silence

### Solution: Passthrough with logging
1. Added `DBG()` logging for WASM call failures (stripped in release builds)
2. Implemented passthrough: copy input buffers to output buffers on failure
3. Also handle unprepared state with passthrough (line 155-164)

### Why passthrough over silence:
- User hears original audio instead of silence/garbage
- Non-destructive - doesn't crash the DAW session
- Debuggable - DBG() provides diagnostic info in debug builds

### Edge cases handled:
- `!prepared_` (WASM not initialized) → passthrough
- `numSamples <= 0` → no-op (no buffer to copy)
- `numSamples > maxBlockSize_` → passthrough (safety)
- WASM call failure → passthrough with logging

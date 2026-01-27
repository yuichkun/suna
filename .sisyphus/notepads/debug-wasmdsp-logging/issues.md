# Issues - debug-wasmdsp-logging

## [2026-01-27T07:59:36Z] Session Start

### Known Issues
1. DBG() macros throughout WasmDSP.cpp (12 locations)
2. Silent failures: allocateBuffers, prepareToPlay, processBlock
3. No visibility into release build failures

### Symptoms
- AudioPluginHost: Complete silence (no sine wave despite mix > 0)
- Cubase: Dry signal only (no delay, no sine wave)
- Logs show "WasmDSP initialized: SUCCESS" but no wet signal

### Expected After Fix
Log file will show exact failure point (e.g., "allocateBuffers - Failed: memBase is null")

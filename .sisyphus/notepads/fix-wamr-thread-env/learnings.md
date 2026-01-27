## [2026-01-27T13:30] TODO 1: Diagnostic Code Addition

### Task Completed
Added diagnostic thread environment initialization code to `WasmDSP::processBlock()`.

### Implementation Details
- **File Modified**: `plugin/src/WasmDSP.cpp`
- **Includes Added**: `<thread>`, `<functional>`
- **Code Location**: Inserted after `firstCall = false;` (line 222), before passthrough check
- **Commit**: `dc6164f` - "fix(wasmdsp): add thread env init for audio thread with diagnostics"

### Key Diagnostic Features
1. **Thread ID Logging**: Uses `std::hash<std::thread::id>` to identify which thread(s) are calling processBlock
2. **State Tracking**: Logs `env_inited_before`, `init_result`, `env_inited_after`
3. **Anomaly Detection**: Specifically catches the case where init returns true but env_inited stays false
4. **Graceful Fallback**: Returns passthrough audio if init fails

### Technical Approach
- Used `thread_local` variables to track per-thread initialization state
- Prevents repeated init attempts on the same thread
- Logs detailed diagnostics only on first attempt per thread

### Why This Matters
The user's local testing showed a contradictory state:
- `wasm_runtime_init_thread_env()` returns TRUE
- But `os_thread_signal_inited()` returns FALSE

This should be impossible if `OS_ENABLE_HW_BOUND_CHECK` is defined (which it must be, since the error occurs). The diagnostic code will reveal:
- Pattern A: Init works correctly (problem was just missing init call)
- Pattern B: The anomaly (TLS or symbol resolution issue)
- Pattern C: Init fails (different root cause)

### Next Steps
Waiting for user to:
1. Pull changes
2. Build on M1 Mac: `npm run release:vst`
3. Test in DAW
4. Share diagnostic log from `~/Desktop/suna_debug.log`


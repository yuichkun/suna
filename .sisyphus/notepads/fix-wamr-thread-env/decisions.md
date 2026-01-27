## [2026-01-27T13:35] Architectural Decisions

### Decision: Diagnostic-First Approach

**Context**: User's local testing showed contradictory behavior:
- `wasm_runtime_init_thread_env()` returns TRUE
- `os_thread_signal_inited()` returns FALSE

This should be impossible if `OS_ENABLE_HW_BOUND_CHECK` is defined (which it must be, since the error "thread signal env not inited" can only occur when this macro is defined).

**Decision**: Add comprehensive diagnostic logging before attempting any fixes.

**Rationale**:
1. **Unknown Root Cause**: The contradictory state suggests either:
   - TLS (thread-local storage) not working across library boundaries
   - Symbol resolution issues (multiple definitions)
   - Library build configuration mismatch
   
2. **Cross-Platform Complexity**: Agent runs in Docker (Linux), user is on M1 Mac (ARM). Cannot reproduce locally.

3. **Three Possible Patterns**:
   - **Pattern A**: Init works correctly → Problem was just missing init call
   - **Pattern B**: Init returns true but env_inited stays false → TLS/symbol issue
   - **Pattern C**: Init fails → Different root cause

4. **Avoid Premature Fixes**: Without diagnostics, we'd be guessing. Each wrong guess wastes a full rebuild cycle (~5-10 minutes).

**Implementation**:
- Added `thread_local` variables to track per-thread state
- Log thread ID hash to identify if multiple threads are involved
- Log before/after state of `wasm_runtime_thread_env_inited()`
- Log return value of `wasm_runtime_init_thread_env()`
- Specific anomaly detection for the contradictory state

**Trade-offs**:
- **Pro**: Precise diagnosis, minimal rebuild cycles
- **Pro**: Logs persist in file for analysis
- **Con**: Adds ~50 lines of diagnostic code (can be cleaned up later)
- **Con**: Requires user rebuild and testing before next step

### Decision: Keep Diagnostic Code Permanently (with optional cleanup)

**Rationale**:
- Even if Pattern A (simple fix), the init code is correct and necessary
- Diagnostic logs can be reduced but init logic should stay
- Future-proofs against DAW thread pool changes
- Provides clear debugging trail if issue recurs

**Cleanup Strategy** (if Pattern A):
- Keep: Thread env init logic
- Keep: Anomaly detection log (only fires if problem occurs)
- Optional: Reduce verbosity of success case logs


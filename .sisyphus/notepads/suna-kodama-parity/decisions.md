# Decisions - Suna-Kodama Parity

Architectural and implementation choices made during this work.

---

## Memory Layout Documentation (2026-01-26)

### Decision: BUFFER_START = 900000

Added comprehensive memory layout documentation to `WasmDSP.cpp` explaining why BUFFER_START is set to 900000.

**Rationale:**
1. MoonBit uses `heap-start-address: 65536` (0x10000) in moon.pkg.json
2. Delay buffer requires ~768KB (96000 samples * 2 channels * 4 bytes)
3. 900000 provides safe margin above MoonBit heap usage
4. Fits within WAMR's 1MB heap allocation (heapSize = 1024 * 1024)

### Decision: Runtime Memory Validation

Added validation in `allocateBuffers()` using WAMR APIs:
- `wasm_runtime_get_default_memory()` - get memory instance
- `wasm_memory_get_cur_page_count()` - get current page count
- `wasm_memory_get_bytes_per_page()` - get bytes per page (64KB standard)

Validation formula: `actualSize >= BUFFER_START + (4 * bufferBytes)`

On failure: returns false and logs via DBG(), preventing buffer allocation.

### Why Not Dynamic Memory Growth

Chose static validation over `wasm_memory_enlarge()` because:
1. Audio DSP requires predictable memory layout
2. MoonBit code expects fixed buffer offsets
3. Memory growth during audio processing could cause glitches
4. Simpler to fail fast at initialization than handle runtime growth

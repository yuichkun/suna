# Pattern B/C Response Guide

If diagnostic log shows Pattern B (TLS anomaly) or Pattern C (init fails), the user needs to rebuild WAMR with hardware bound check disabled.

## Pattern B: TLS/Symbol Issue

**Log shows**:
```
WasmDSP DIAG: Thread 1234 - init_result=true - env_inited_after=false
WasmDSP DIAG: ANOMALY - init=true but env_inited=false after init!
```

**Root Cause**: Thread-local storage not working correctly across library boundary, or symbol resolution issue.

## Pattern C: Init Fails

**Log shows**:
```
WasmDSP DIAG: Thread 1234 - init_result=false
WasmDSP DIAG: FATAL - init_thread_env returned false
```

**Root Cause**: `wasm_runtime_init_thread_env()` itself is failing, likely due to signal handler setup issues.

---

## Solution: Rebuild WAMR (User Action)

Both patterns require the same fix: disable hardware bound check in WAMR.

### Step-by-Step Commands

```bash
# 1. Navigate to WAMR darwin build directory
cd libs/wamr/product-mini/platforms/darwin/build

# 2. Clean existing build
rm -rf ./*

# 3. Reconfigure with HW bound check disabled
cmake .. -DWAMR_DISABLE_HW_BOUND_CHECK=1

# 4. Build
make -j"$(sysctl -n hw.ncpu)"

# 5. Verify the flag was applied
grep -E "WAMR_DISABLE_HW_BOUND_CHECK" CMakeCache.txt
# Should output: WAMR_DISABLE_HW_BOUND_CHECK:BOOL=ON

# 6. Return to project root
cd /path/to/suna

# 7. Rebuild plugin
npm run release:vst

# 8. Test in DAW
# Load plugin in AudioPluginHost/Cubase and play audio

# 9. Check results
cat ~/Desktop/suna_debug.log | tail -50
```

### Expected Outcome

After rebuild:
- ✅ No "thread signal env not inited" errors
- ✅ `WasmDSP::processBlock() - WASM call success=true` in log
- ✅ Wet signal audible (delay + 220Hz sine)

### Why This Works

**When `WAMR_DISABLE_HW_BOUND_CHECK=1`**:
- `OS_ENABLE_HW_BOUND_CHECK` macro is NOT defined
- The error "thread signal env not inited" cannot occur (code path doesn't exist)
- WAMR uses software bounds checking instead
- Slightly slower (~5-10%) but functionally equivalent
- No thread signal environment required

### Trade-offs

**Pros**:
- Bypasses the TLS/signal handler issue completely
- Works reliably across all macOS versions
- No code changes needed

**Cons**:
- Slightly slower bounds checking (software vs hardware trap)
- Loses hardware-accelerated memory protection
- In practice: Performance difference is negligible for audio DSP

---

## If Still Fails After Rebuild

If the plugin still doesn't work after disabling HW bound check, collect this data:

```bash
# 1. WAMR library info
file libs/wamr/product-mini/platforms/darwin/build/libiwasm.a
# Should show: arm64 architecture

# 2. Build configuration
grep -E "WAMR_DISABLE_HW_BOUND_CHECK|WAMR_BUILD_TARGET" \
  libs/wamr/product-mini/platforms/darwin/build/CMakeCache.txt

# 3. Symbol check
nm libs/wamr/product-mini/platforms/darwin/build/libiwasm.a | \
  grep -E "thread_signal_inited|os_thread_signal_inited|runtime_signal_init"

# 4. Library timestamp (verify it's recent)
ls -la libs/wamr/product-mini/platforms/darwin/build/libiwasm.a

# 5. Plugin linkage (verify it's using the rebuilt library)
otool -L build/plugin/Suna_artefacts/Release/VST3/Suna.vst3/Contents/MacOS/Suna

# 6. Latest diagnostic log
cat ~/Desktop/suna_debug.log | tail -100
```

Share all outputs for further diagnosis.

---

## Agent Actions After User Confirms Success

Once user confirms Pattern B/C fix worked:

### 1. Mark TODO 2 Complete
```markdown
- [x] 2. User rebuilds, tests, and shares diagnostic log (USER TASK)
  - [x] Plugin built successfully
  - [x] Diagnostic log captured
  - [x] Pattern identified (A, B, or C)
```

### 2. Mark TODO 3 Complete
```markdown
- [x] 3. Apply targeted fix based on diagnosis (AFTER DIAGNOSTIC)
```

### 3. Update Success Criteria
```markdown
### Fix Phase
- [x] Appropriate fix applied based on diagnosis
- [x] "WASM call success=true" appears in log
- [x] No "thread signal env not inited" errors
- [x] Wet signal (delay + 220Hz sine) audible in DAW
```

### 4. Record in Learnings
Document which pattern occurred and the solution in `learnings.md`.

### 5. Close Work Session
- Update boulder.json
- Final commit
- Session complete

---

## No Repo Changes Needed

**Important**: For Pattern B/C, the diagnostic code in `plugin/src/WasmDSP.cpp` stays as-is. No additional commits needed.

The WAMR rebuild is a **user-side workaround**, not a repo change. This preserves the standard build path for other users who don't experience the issue.


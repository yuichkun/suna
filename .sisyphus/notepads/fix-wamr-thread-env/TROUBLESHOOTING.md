# Troubleshooting Guide

## Quick Reference Commands (Run on M1 Mac)

### 1. Build and Test
```bash
cd /path/to/suna
git pull
npm run release:vst
# Test in AudioPluginHost/Cubase
cat ~/Desktop/suna_debug.log | grep "DIAG"
```

### 2. WAMR Build Verification
```bash
# Check build configuration
cat libs/wamr/product-mini/platforms/darwin/build/CMakeCache.txt | grep -E "WAMR_BUILD_TARGET|WAMR_DISABLE"

# Check library architecture (should show arm64)
file libs/wamr/product-mini/platforms/darwin/build/libiwasm.a

# Check symbols for thread signal functions
nm libs/wamr/product-mini/platforms/darwin/build/libiwasm.a | grep thread_signal
```

### 3. AOT File Verification
```bash
# Check AOT file architecture
file plugin/resources/suna_dsp.aot

# Rebuild AOT if needed
npm run build:dsp
```

## Pattern-Based Fixes

### Pattern A: Init Works (Success!)
**Log shows**:
```
WasmDSP DIAG: Thread 1234 - init_result=true - env_inited_after=true
WasmDSP::processBlock() - WASM call success=true
```

**Action**: Done! The diagnostic code is also the fix.

**Optional cleanup** (reduce log noise):
- Keep the thread env init logic
- Keep anomaly detection
- Can remove verbose success logs if desired

---

### Pattern B: TLS/Symbol Issue (The Anomaly)
**Log shows**:
```
WasmDSP DIAG: Thread 1234 - init_result=true - env_inited_after=false
WasmDSP DIAG: ANOMALY - init=true but env_inited=false after init!
```

**Root Cause**: Thread-local storage or symbol resolution issue with WAMR library.

**Fix**: Rebuild WAMR with hardware bound check disabled:

```bash
cd libs/wamr/product-mini/platforms/darwin/build
rm -rf ./*
cmake .. -DWAMR_DISABLE_HW_BOUND_CHECK=1
make -j"$(sysctl -n hw.ncpu)"

# Verify the flag
grep -E "WAMR_DISABLE_HW_BOUND_CHECK" CMakeCache.txt
# Should show: WAMR_DISABLE_HW_BOUND_CHECK:BOOL=ON

# Rebuild plugin
cd /path/to/suna
npm run release:vst
```

**Why this works**:
- Disables `OS_ENABLE_HW_BOUND_CHECK` macro
- Error "thread signal env not inited" cannot occur
- Uses software bounds checking instead (slightly slower but works)

**If still fails**, collect and share:
```bash
file libs/wamr/product-mini/platforms/darwin/build/libiwasm.a
nm libs/wamr/product-mini/platforms/darwin/build/libiwasm.a | grep -E "thread_signal_inited|os_thread_signal_inited|runtime_signal_init"
grep -E "WAMR_DISABLE_HW_BOUND_CHECK|WAMR_BUILD_TARGET" libs/wamr/product-mini/platforms/darwin/build/CMakeCache.txt
```

---

### Pattern C: Init Fails
**Log shows**:
```
WasmDSP DIAG: Thread 1234 - init_result=false - env_inited_after=false
WasmDSP DIAG: FATAL - init_thread_env returned false
```

**Root Cause**: `wasm_runtime_init_thread_env()` itself is failing.

**Fix**: Same as Pattern B - disable hardware bound check:

```bash
cd libs/wamr/product-mini/platforms/darwin/build
rm -rf ./*
cmake .. -DWAMR_DISABLE_HW_BOUND_CHECK=1
make -j"$(sysctl -n hw.ncpu)"
cd /path/to/suna
npm run release:vst
```

**If still fails**, collect and share:
```bash
# DIAG lines from log
cat ~/Desktop/suna_debug.log | grep "DIAG"

# WAMR build info
file libs/wamr/product-mini/platforms/darwin/build/libiwasm.a
grep -E "WAMR_DISABLE_HW_BOUND_CHECK|WAMR_BUILD_TARGET" libs/wamr/product-mini/platforms/darwin/build/CMakeCache.txt

# Library timestamp
ls -la libs/wamr/product-mini/platforms/darwin/build/libiwasm.a
```

---

## Common Issues

### Issue: Plugin not loading in DAW
**Check**:
```bash
# Verify plugin was copied to system location
ls -la ~/Library/Audio/Plug-Ins/VST3/Suna.vst3

# Check architecture
file ~/Library/Audio/Plug-Ins/VST3/Suna.vst3/Contents/MacOS/Suna
# Should show: arm64
```

**Fix**: Rebuild and ensure copy:
```bash
npm run release:vst
# Check build output for "Copying plugin to system location"
```

### Issue: No log file created
**Check**:
```bash
ls -la ~/Desktop/suna_debug.log
```

**Cause**: Plugin not loaded or FileLogger not initialized.

**Fix**: 
1. Ensure plugin loads in DAW
2. Check Console.app for any crash logs
3. Verify `plugin/src/PluginProcessor.cpp:11-15` has FileLogger setup

### Issue: Build fails with "command not found"
**Missing dependencies**:
```bash
# Install if needed
brew install cmake ninja ccache node

# Check MoonBit
moon --version

# If missing, install from: https://www.moonbitlang.com/download/
```

### Issue: WAMR library not found during plugin build
**Check**:
```bash
ls -la libs/wamr/product-mini/platforms/darwin/build/libiwasm.a
```

**Fix**: Run setup script:
```bash
npm run setup:macos
# This builds LLVM, wamrc, and libiwasm (takes ~30 min first time)
```

---

## Understanding the Diagnostic Output

### Thread ID Hash
```
WasmDSP DIAG: Thread 1234 - ...
```
- `1234` is a hash of the thread ID (truncated for readability)
- Multiple different numbers = multiple audio threads (normal for some DAWs)
- Same number repeating = same thread (expected)

### env_inited_before
```
env_inited_before=false
```
- `false` on first call = expected (thread env not yet initialized)
- `true` on first call = unexpected (would mean already initialized somehow)

### init_result
```
init_result=true
```
- `true` = `wasm_runtime_init_thread_env()` succeeded
- `false` = init function failed (Pattern C)

### env_inited_after
```
env_inited_after=true
```
- `true` = thread env is now initialized (Pattern A - success!)
- `false` = thread env still not initialized despite init returning true (Pattern B - anomaly!)

### WASM call success
```
WasmDSP::processBlock() - WASM call success=true
```
- `true` = WASM function executed successfully, audio processing working
- `false` = WASM call failed, will see "thread signal env not inited" error

---

## Next Steps After Fix

Once the plugin is working (wet signal audible):

1. **Test thoroughly**:
   - Load/unload plugin multiple times
   - Test in different DAWs (AudioPluginHost, Cubase, etc.)
   - Verify no crashes on close

2. **Optional cleanup** (if Pattern A):
   - Can reduce diagnostic log verbosity
   - Keep the thread env init logic (it's correct and necessary)

3. **Document the solution**:
   - Note which pattern occurred
   - Note if WAMR rebuild was needed
   - This helps if issue recurs or for other users


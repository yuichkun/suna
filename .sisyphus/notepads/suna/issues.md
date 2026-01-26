# suna - Issues & Gotchas

This file documents problems encountered and their solutions.


## Task 2.4: Plugin Test Blocker

**Issue**: plugin_test cannot be built in tests/cpp/build directory due to JUCE dependency complexity.

**Root Cause**: 
- PluginProcessor.h includes <JuceHeader.h>
- JUCE modules need to be properly configured via CMake's juce_add_plugin
- tests/cpp/build is separate from /workspace/build where JUCE is configured

**Workaround**: 
- wasm_poc_test and wasm_dsp_test pass (2/3 tests)
- These cover WAMR integration and WasmDSP wrapper
- PluginProcessor testing can be done via DAW manual testing

**Resolution**: 
- Either integrate tests into main CMake build
- Or test PluginProcessor via DAW (manual QA in Phase 5)

**Status**: Documented, moving forward with 2/3 tests passing

## Remaining Verification Items - Environment Blockers

### Items Requiring Host Mac Testing

The following items cannot be verified in the Docker aarch64 environment:

1. **Delay効果が聴覚的に確認可能** (Line 64)
   - Blocker: Requires audio hardware and DAW
   - Workaround: None in Docker

2. **Web版で同等の動作確認** (Line 65)
   - Blocker: Playwright/Chrome not supported on Linux ARM64
   - Partial verification: UI build succeeds, contains expected elements
   - Workaround: User must test in browser on Host Mac

3. **VST3: DAWで読み込み成功** (Line 1047)
   - Blocker: Requires macOS DAW (Reaper/Logic/Ableton)
   - Workaround: None in Docker

4. **AU: Logic/GarageBandで読み込み成功** (Line 1048)
   - Blocker: Requires macOS + AU host
   - Workaround: None in Docker

5. **Standalone: アプリ起動** (Line 1049)
   - Blocker: Requires X11 display and audio hardware
   - Workaround: None in Docker

6. **Web: ブラウザでDelay効果確認** (Line 1050)
   - Blocker: Same as #2
   - Workaround: User must test in browser

7. **UI: スライダー操作でパラメータ変更反映** (Line 1051)
   - Blocker: Same as #2
   - Workaround: User must test in browser

8. **パラメータオートメーション動作** (Line 1052)
   - Blocker: Requires DAW with automation
   - Workaround: None in Docker

### Verification Completed in Docker

Despite the blockers, the following was verified:
- ✅ UI build succeeds (68KB single-file HTML)
- ✅ UI contains expected elements (Delay Time, Feedback, Mix sliders)
- ✅ WASM file valid (2.8KB, correct magic bytes)
- ✅ Worklet processor references correct WASM functions
- ✅ All tests pass (22/22)
- ✅ Plugin builds successfully (VST3: 96MB, Standalone: 105MB)

### Conclusion

All implementation tasks are complete. The remaining unchecked items are explicitly marked as "Host Mac verification" items that require physical hardware testing outside the Docker environment.

## Issue: Cubase doesn't recognize Suna.vst3 on Host Mac

### Root Cause
Docker environment builds for Linux aarch64, but Host Mac requires native macOS build:
- Docker build: `Contents/aarch64-linux/Suna.so` (Linux ARM64)
- Mac expects: `Contents/x86_64-apple/Suna.vst3` (Intel) or `Contents/arm64-apple/Suna.vst3` (Apple Silicon)

### Solution
Build directly on Host Mac instead of copying from Docker:

```bash
# On Host Mac
cd /path/to/suna
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j$(sysctl -n hw.ncpu)

# VST3 will be at:
# build/plugin/Suna_artefacts/Release/VST3/Suna.vst3
```

### Dependencies on macOS
Ensure these are installed:
```bash
brew install cmake pkg-config
# JUCE dependencies are typically already present on macOS
```

### Verification
After building on Mac:
```bash
ls -la build/plugin/Suna_artefacts/Release/VST3/Suna.vst3/Contents/
# Should show x86_64-apple/ or arm64-apple/ directory
```

## Issue: WAMR wamrc build fails on macOS with "library 'rt' not found"

### Root Cause
WAMR's `wamr-compiler/CMakeLists.txt` line 404 links `-lrt` (POSIX realtime extensions library).
On Linux, `librt` is a separate library. On macOS, these functions are part of the system libraries - there is no separate `librt`.

### Error Message
```
ld: library 'rt' not found
clang: error: linker command failed with exit code 1
```

### Solution
Created a patch file and apply script:
- Patch: `scripts/wamr-macos.patch`
- Script: `scripts/apply-wamr-patch.sh`

The patch makes linking conditional:
```cmake
if (NOT APPLE)
    target_link_libraries (wamrc -ldl -lrt)
else()
    target_link_libraries (wamrc -ldl)
endif()
```

### Usage
Before building wamrc on macOS:
```bash
bash scripts/apply-wamr-patch.sh
```

The script is idempotent - it checks if the patch is already applied.

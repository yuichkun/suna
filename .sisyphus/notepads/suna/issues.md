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

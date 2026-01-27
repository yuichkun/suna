# Decisions - debug-wasmdsp-logging

## [2026-01-27T07:59:36Z] Session Start

### Logging Strategy
- **Decision**: Replace all DBG() with juce::Logger::writeToLog()
- **Rationale**: DBG() is compile-time disabled in release builds; critical errors are invisible
- **Pattern**: `DBG("msg" << var)` → `juce::Logger::writeToLog("msg" + juce::String(var))`

### Diagnostic Points
- allocateBuffers: Success/failure with details
- prepareToPlay: Initialization check, buffer allocation result, prepared_ state
- processBlock: Passthrough detection (first time), WASM call result (first time)

### Audio Thread Safety
- processBlock logging: First-time-only using static bool flags
- Prevents file I/O on every audio callback

# Decisions - debug-audio-plugin

## [2026-01-27T06:27:42Z] Session Start

### Logging Strategy
- **Decision**: Use FileLogger instead of DBG() for Cubase compatibility
- **Rationale**: Cubase doesn't show console output; file logging enables debug in all environments
- **Implementation**: ~/Desktop/suna_debug.log

### Audio Thread Safety
- **Decision**: Log only first processBlock call
- **Rationale**: File I/O on audio thread can cause glitches; one-time log is acceptable
- **Implementation**: Static bool firstCall pattern

### Sine Wave Implementation
- **Decision**: Taylor series approximation instead of library sin()
- **Rationale**: WASM core spec has no native sin instruction; MoonBit pattern uses approximation
- **Parameters**: 220Hz frequency, 0.3 amplitude

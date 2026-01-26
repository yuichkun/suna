# suna - Learnings & Conventions

This file accumulates conventions, patterns, and insights discovered during implementation.

## Task 0.1: Docker Environment Setup - aarch64 Challenge

### MoonBit Installation
- **Issue**: Official MoonBit installer only supports x86_64 and macOS
- **Environment**: Docker Ubuntu aarch64 (ARM64)
- **Solution**: Used WASM-based MoonBit binaries with Node.js wrapper
  - Downloaded moonbit-wasm.tar.gz from GitHub releases (v0.7.2+938b1f804)
  - Created Node.js wrapper script at `/opt/moonbit/bin/moon`
  - Wrapper delegates to moonc.js for compilation tasks
  - Version command verified: `moon version` → 9eb2e53edad9044fccc9201067367ea78bda7554

### System Packages Verified
- cmake 3.28.3 (requirement: 3.22+) ✅
- pkg-config with freetype2 ✅
- wabt 1.0.34 (wasm2wat) ✅
- JUCE audio dependencies (ALSA, JACK, X11, OpenGL, WebKit) ✅

### Catch2 Test Framework
- Downloaded: `/workspace/tests/cpp/include/catch_amalgamated.hpp` (523K) ✅

### Key Insight: aarch64 Limitation
- MoonBit doesn't provide native aarch64 binaries
- Node.js WASM runner is a workaround but may have CLI limitations
- **Recommendation**: Monitor during DSP build (task 0.3); consider x86_64 container if issues arise


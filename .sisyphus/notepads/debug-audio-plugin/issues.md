# Issues - debug-audio-plugin

## [2026-01-27T06:27:42Z] Session Start

### Known Issues
1. WebBrowserComponent destructor crashes via WAMR signal_callback
2. Dry audio passes through unchanged (wet signal not working)
3. Member destruction order: browser destroyed after relays (potential dangling pointer)

### Hypotheses to Test
- [ ] Is DSP processBlock being called at all?
- [ ] Is WasmDSP initialization succeeding?
- [ ] Does browser.reset() first fix destructor crash?
- [ ] Is wet signal path functional (sine wave test)?

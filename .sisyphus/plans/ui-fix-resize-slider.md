# Fix UI: Editor Resize & Slider Operation in DAW

## Context

### Original Request
User has mentioned kodama-vst as reference 5+ times. Two critical UI issues remain:
1. Editor window cannot be resized in DAW
2. Sliders don't operate correctly in DAW (automation, undo/redo broken)

Audio works correctly in both web and DAW. The issue is purely UI behavior.

### Interview Summary
**Key Discussions**:
- kodama-vst is the reference implementation - UI should match **perfectly**
- DSP backend differences exist but should NOT affect UI behavior
- User is frustrated with repeated requests

**Research Findings**:
- **Resize**: Current code only calls `setSize(400, 350)`, missing `setResizable(true, true)`
- **Slider**: `sliderDragStarted()` / `sliderDragEnded()` never called - required for DAW automation
- JUCE's juce/index.js already provides the gesture methods, but suna doesn't use them

### Metis Review
**Identified Gaps** (addressed):
- DAW target scope: Applied default (macOS primary, Logic/Ableton)
- Input event coverage: Applied default (mouse only via @mousedown/@mouseup)
- Aspect ratio resize: Applied default (free resize)
- Touch/hi-DPI: Excluded (out of scope for this fix)

---

## Work Objectives

### Core Objective
Enable resizable editor window and proper slider gesture lifecycle for DAW automation.

### Concrete Deliverables
- `plugin/src/PluginEditor.cpp` with `setResizable(true, true)` and optional size limits
- `ui/src/runtime/types.ts` with `sliderDragStarted` / `sliderDragEnded` in ParameterState
- `ui/src/runtime/JuceRuntime.ts` exposing gesture methods
- `ui/src/composables/useRuntime.ts` returning gesture methods from `useParameter()`
- `ui/src/components/SliderControl.vue` calling gesture methods on mousedown/mouseup

### Definition of Done
- [ ] Editor window resizes in DAW (Logic Pro / Ableton Live)
- [ ] Slider automation records correctly in DAW
- [ ] Slider undo/redo works as single gesture per drag
- [ ] No regression in web runtime behavior
- [ ] No regression in audio processing

### Must Have
- `setResizable(true, true)` in PluginEditor constructor
- `sliderDragStarted()` called on `@mousedown` event
- `sliderDragEnded()` called on `@mouseup` event (with window-level listener for mouseup outside element)

### Must NOT Have (Guardrails)
- No changes to DSP, parameters, or audio processing
- No UI redesign beyond slider behavior and resizability
- No new dependencies or architecture changes
- No custom knob control (keep native range input for now)
- No touch event handling (out of scope)
- No session size persistence (out of scope)

---

## Prerequisites

### CRITICAL: Build Environment Constraint
- **Executor runs in**: Docker (Ubuntu) - shared workspace with host
- **User runs on**: M1 Mac (macOS ARM64)
- **BUILD COMMANDS FORBIDDEN FOR EXECUTOR**: `npm install`, `npm run build`, `npm run release:vst`, etc.
- **Reason**: Build artifacts are shared between Docker and host. Running builds in Docker creates Linux artifacts that corrupt the macOS build cache.
- **Who builds**: USER (on host Mac) - executor must ASK before any build/install command

### Environment (for USER's host machine)
- **OS**: macOS (required for AU/VST3 builds and DAW testing)
- **Xcode**: Installed with command line tools
- **DAWs for testing**:
  - Logic Pro (tests AU format primarily, also loads VST3)
  - Ableton Live (tests VST3 format)

### Plugin Installation for DAW Testing
After building with `npm run release:vst`:
1. **VST3**: Plugin is built to `build/plugin/Suna_artefacts/Release/VST3/Suna.vst3`
2. **AU**: Plugin is built to `build/plugin/Suna_artefacts/Release/AU/Suna.component`
3. **Install**: Copy to system plugin folders:
   - VST3: `cp -r build/plugin/Suna_artefacts/Release/VST3/Suna.vst3 ~/Library/Audio/Plug-Ins/VST3/`
   - AU: `cp -r build/plugin/Suna_artefacts/Release/AU/Suna.component ~/Library/Audio/Plug-Ins/Components/`
4. **Rescan**: In Logic Pro: restart or use AU Manager. In Ableton: restart or rescan plugins.

### Evidence Directory
Create before running tests:
```bash
mkdir -p .sisyphus/evidence
```

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES
  - UI: Vitest configured (`ui/package.json:12`, `npm run test`)
  - C++: Catch2 configured (`tests/cpp/CMakeLists.txt`)
- **Tests for this scope**: Manual-only
- **Rationale**: Existing tests cover unit-level logic. This fix requires DAW integration verification (automation recording, resize behavior) which cannot be automated with current infrastructure. Manual DAW testing is the only reliable verification method for these issues.

### Manual QA Procedures

Each TODO includes detailed verification procedures using:
- DAW testing (Logic Pro, Ableton Live) - required for resize/automation verification
- Browser testing for web runtime regression

---

## Task Flow

```
Task 1 (C++ resize) → Task 4 (DAW resize verification)
                   ↘
Task 2 (TS types + runtime) → Task 3 (Vue slider) → Task 5 (DAW slider verification)
                                                 → Task 6 (Web regression check)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 1, 2 | Independent: C++ and TypeScript changes |

| Task | Depends On | Reason |
|------|------------|--------|
| 3 | 2 | Vue needs updated types and useParameter |
| 4 | 1 | Verification needs C++ change |
| 5 | 3 | Verification needs Vue change |
| 6 | 3 | Regression check needs Vue change |

---

## TODOs

- [ ] 1. Enable editor window resizing in JUCE

  **What to do**:
  - Add `setResizable(true, true)` after `setSize(400, 350)` in constructor
  - Optionally add `setResizeLimits(300, 250, 800, 700)` for reasonable bounds

  **Must NOT do**:
  - Change initial window size
  - Add aspect ratio constraints
  - Add size persistence logic

  **Parallelizable**: YES (with 2)

  **References**:

  **Reference Pattern** (from kodama-vst @ https://github.com/yuichkun/kodama-vst commit 29ef74d2):
  ```cpp
  // kodama-vst/plugin/src/PluginEditor.cpp lines 94-95
  setSize(500, 400);
  setResizable(true, true);
  ```
  The pattern is: call `setSize()` first, then immediately call `setResizable(true, true)`.

  **Current Implementation**:
  - `/workspace/plugin/src/PluginEditor.cpp:48` - Current `setSize(400, 350)` location
  - `/workspace/plugin/src/PluginEditor.cpp:71-74` - `resized()` already calls `browser->setBounds(getLocalBounds())` which handles resize correctly

  **Exact Change Required**:
  ```cpp
  // In SunaAudioProcessorEditor constructor, after line 48:
  setSize(400, 350);
  setResizable(true, true);  // ADD THIS LINE
  ```

  **Acceptance Criteria**:

  **Manual Execution Verification (USER runs on host Mac):**
  - [ ] USER runs: `npm run release:vst`
  - [ ] USER runs: `cp -r build/plugin/Suna_artefacts/Release/AU/Suna.component ~/Library/Audio/Plug-Ins/Components/`
  - [ ] USER opens Logic Pro, rescans plugins if needed
  - [ ] USER adds Suna plugin to track
  - [ ] USER attempts to resize plugin window by dragging edge/corner
  - [ ] Verify: Window resizes smoothly (responds to drag)
  - [ ] Verify: No black bars or clipping at edges
  - [ ] Verify: Controls remain visible and usable
  - [ ] Screenshot: Save evidence to `.sisyphus/evidence/task1-resize.png`

  **Commit**: YES
  - Message: `fix(editor): enable window resizing in DAW`
  - Files: `plugin/src/PluginEditor.cpp`
  - Pre-commit: ASK USER to run `npm run release:vst` on host Mac

---

- [ ] 2. Add gesture lifecycle methods to ParameterState and expose via useParameter

  **What to do**:
  
  **Step 2a: Update types.ts**
  Add optional gesture methods to ParameterState interface:
  ```typescript
  // In ui/src/runtime/types.ts, add to ParameterState interface:
  export interface ParameterState {
    // ... existing methods ...
    sliderDragStarted?: () => void  // ADD
    sliderDragEnded?: () => void    // ADD
  }
  ```

  **Step 2b: Update JuceRuntime.ts**
  Expose gesture methods with proper `this` binding (CRITICAL: use arrow functions to avoid `this` binding issues):
  ```typescript
  // In ui/src/runtime/JuceRuntime.ts, in getParameter() return object:
  return {
    // ... existing methods ...
    sliderDragStarted: () => sliderState.sliderDragStarted(),  // ADD - arrow fn binds correctly
    sliderDragEnded: () => sliderState.sliderDragEnded(),      // ADD - arrow fn binds correctly
  }
  ```
  **CRITICAL**: Use arrow functions `() => sliderState.method()` NOT direct references `sliderState.method` to preserve `this` binding.

  **Step 2c: Update useRuntime.ts (useParameter composable)**
  Expose gesture methods in the return value:
  ```typescript
  // In ui/src/composables/useRuntime.ts, in useParameter() function:
  // Add refs for gesture methods
  const sliderDragStarted = ref<(() => void) | null>(null)
  const sliderDragEnded = ref<(() => void) | null>(null)
  
  // In updateFromRuntime(), after getting param:
  sliderDragStarted.value = param.sliderDragStarted ?? null
  sliderDragEnded.value = param.sliderDragEnded ?? null
  
  // In return object, add:
  return {
    // ... existing ...
    sliderDragStarted,
    sliderDragEnded,
  }
  ```

  **Must NOT do**:
  - Change existing method signatures
  - Add methods to WebRuntime.ts (WebRuntime doesn't need gesture lifecycle - no DAW automation in browser)

  **Parallelizable**: YES (with 1)

  **References**:

  **JUCE Bridge Implementation** (already exists, just need to use it):
  - `/workspace/ui/src/juce/index.js:192-205`:
    ```javascript
    sliderDragStarted() {
      window.__JUCE__.backend.emitEvent(this.identifier, {
        eventType: SliderControl_sliderDragStartedEventId,
      });
    }

    sliderDragEnded() {
      window.__JUCE__.backend.emitEvent(this.identifier, {
        eventType: SliderControl_sliderDragEndedEventId,
      });
    }
    ```
  - `/workspace/ui/src/juce/index.d.ts:6-7` - TypeScript declarations confirming SliderState has these methods

  **Current Implementation to Modify**:
  - `/workspace/ui/src/runtime/types.ts:12-19` - ParameterState interface (add optional methods)
  - `/workspace/ui/src/runtime/JuceRuntime.ts:13-27` - getParameter() return (expose with arrow fn binding)
  - `/workspace/ui/src/composables/useRuntime.ts:40-97` - useParameter() (expose in return value)

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] ASK USER to run: `cd ui && npm run build` (must pass on host Mac)
  - [ ] Verify `types.ts` has `sliderDragStarted?: () => void` and `sliderDragEnded?: () => void`
  - [ ] Verify `JuceRuntime.ts` returns gesture methods with arrow function binding
  - [ ] Verify `useRuntime.ts` exposes `sliderDragStarted` and `sliderDragEnded` in useParameter return

  **Commit**: YES
  - Message: `feat(ui): add slider gesture lifecycle to ParameterState and useParameter`
  - Files: `ui/src/runtime/types.ts`, `ui/src/runtime/JuceRuntime.ts`, `ui/src/composables/useRuntime.ts`
  - Pre-commit: ASK USER to run `cd ui && npm run build` on host Mac

---

- [ ] 3. Call gesture methods in SliderControl.vue

  **What to do**:

  **Step 3a: Get gesture methods from useParameter**
  ```typescript
  // In SliderControl.vue <script setup>:
  const { normalizedValue, displayValue, setNormalizedValue, properties, sliderDragStarted, sliderDragEnded } =
    useParameter(props.parameterId)
  ```

  **Step 3b: Add mousedown handler**
  ```typescript
  function onMouseDown() {
    sliderDragStarted.value?.()
    
    // Add window-level mouseup listener to catch mouseup outside element
    const onWindowMouseUp = () => {
      sliderDragEnded.value?.()
      window.removeEventListener('mouseup', onWindowMouseUp)
    }
    window.addEventListener('mouseup', onWindowMouseUp)
  }
  ```

  **Step 3c: Add @mousedown to input element**
  ```html
  <input
    type="range"
    :min="min"
    :max="max"
    :value="sliderValue"
    step="1"
    @input="onInput"
    @mousedown="onMouseDown"
  />
  ```

  **Why window-level mouseup?**
  If user drags slider and releases mouse outside the element, a regular `@mouseup` on the input won't fire. Using `window.addEventListener('mouseup', ...)` ensures we always catch the mouseup event, matching kodama-vst's window-level listener pattern.

  **Must NOT do**:
  - Replace native range input with custom knob control
  - Add touch event handling (@touchstart/@touchend)
  - Change value update logic (keep @input)

  **Parallelizable**: NO (depends on 2)

  **References**:

  **Reference Pattern** (from kodama-vst @ https://github.com/yuichkun/kodama-vst commit 29ef74d2):
  ```typescript
  // kodama-vst/ui/src/components/KnobControl.vue lines 28-47
  const onMouseDown = (e: MouseEvent) => {
    isDragging.value = true
    startY.value = e.clientY
    startValue.value = normalizedValue.value
    window.addEventListener('mousemove', onMouseMove)
    window.addEventListener('mouseup', onMouseUp)  // <-- window-level listener
  }

  const onMouseUp = () => {
    isDragging.value = false
    window.removeEventListener('mousemove', onMouseMove)
    window.removeEventListener('mouseup', onMouseUp)
  }
  ```
  Key insight: Window-level `mouseup` listener ensures gesture end is always captured even if mouse leaves the element.

  **Current Implementation to Modify**:
  - `/workspace/ui/src/components/SliderControl.vue:11-12` - useParameter destructuring (add gesture methods)
  - `/workspace/ui/src/components/SliderControl.vue:47-54` - input element (add @mousedown)
  - Add new `onMouseDown` function

  **Acceptance Criteria**:

  **Manual Execution Verification (Web - basic sanity):**
  - [ ] ASK USER to run: `cd ui && npm run build` (must pass on host Mac)
  - [ ] ASK USER to run: `npm run dev:web` on host Mac
  - [ ] USER opens http://localhost:5173 in browser
  - [ ] USER checks browser console (F12)
  - [ ] USER clicks and drags slider - verify no console errors
  - [ ] Verify: Slider values update correctly (no regression)

  **Manual Execution Verification (DAW - full verification done in Task 5):**
  - Task 5 will verify actual automation recording behavior in DAW

  **Commit**: YES
  - Message: `fix(ui): call sliderDragStarted/Ended for DAW automation`
  - Files: `ui/src/components/SliderControl.vue`
  - Pre-commit: ASK USER to run `cd ui && npm run build` on host Mac

---

- [ ] 4. Verify editor resize in DAW

  **What to do**:
  - Build release plugin
  - Install to system plugin folder
  - Test resize in Logic Pro
  - Test resize in Ableton Live (if available)
  - Document any DAW-specific behavior

  **Parallelizable**: NO (depends on 1)

  **References**:
  - Task 1 implementation
  - Prerequisites section for installation steps

  **Acceptance Criteria**:

  **Manual Execution Verification (USER runs on host Mac - Logic Pro):**
  - [ ] USER runs: `npm run release:vst`
  - [ ] USER runs: `cp -r build/plugin/Suna_artefacts/Release/AU/Suna.component ~/Library/Audio/Plug-Ins/Components/`
  - [ ] USER opens Logic Pro, creates new project
  - [ ] If plugin not visible, use Audio Units Manager to rescan
  - [ ] USER adds Suna plugin to audio track (Audio FX slot)
  - [ ] USER resizes plugin window by dragging corner
  - [ ] Verify: Resize works smoothly (window responds to drag)
  - [ ] Verify: No black bars or clipping at edges
  - [ ] Verify: Controls remain visible and usable at resized dimensions
  - [ ] Screenshot: `.sisyphus/evidence/task4-logic-resize.png`

  **Manual Execution Verification (USER runs on host Mac - Ableton Live):**
  - [ ] USER runs: `cp -r build/plugin/Suna_artefacts/Release/VST3/Suna.vst3 ~/Library/Audio/Plug-Ins/VST3/`
  - [ ] USER opens Ableton Live, rescans plugins if needed
  - [ ] USER adds Suna plugin to track
  - [ ] USER resizes plugin window
  - [ ] Verify: Resize works (window responds to drag)
  - [ ] Verify: No black bars or clipping at edges
  - [ ] Screenshot: `.sisyphus/evidence/task4-ableton-resize.png`

  **Commit**: NO (verification only)

---

- [ ] 5. Verify slider automation in DAW

  **What to do**:
  - Test automation recording in Logic Pro
  - Test undo/redo behavior
  - Verify automation plays back correctly

  **Parallelizable**: NO (depends on 3)

  **References**:
  - Task 3 implementation

  **Acceptance Criteria**:

  **Manual Execution Verification (USER runs on host Mac - Logic Pro):**
  - [ ] USER runs: `npm run release:vst`
  - [ ] USER runs: `cp -r build/plugin/Suna_artefacts/Release/AU/Suna.component ~/Library/Audio/Plug-Ins/Components/`
  - [ ] USER opens Logic Pro with Suna plugin on a track
  - [ ] USER enables automation: Press 'A' to show automation, set track to "Touch" or "Latch" mode
  - [ ] USER starts playback/recording
  - [ ] USER moves Delay Time slider while recording
  - [ ] USER stops recording
  - [ ] Verify: Automation lane shows recorded data points
  - [ ] Verify: Playback follows the recorded automation curve
  - [ ] Test Undo (Cmd+Z): Verify entire slider drag is undone as single action (not per-sample)
  - [ ] Screenshot: `.sisyphus/evidence/task5-automation.png`

  **Commit**: NO (verification only)

---

- [ ] 6. Verify no regression in web runtime

  **What to do**:
  - Test web version still works correctly
  - Verify sliders work in browser
  - Verify audio processing unchanged

  **Parallelizable**: NO (depends on 3)

  **References**:
  - Task 3 implementation

  **Acceptance Criteria**:

  **Manual Execution Verification (USER runs on host Mac):**
  - [ ] USER runs: `npm run dev:web`
  - [ ] USER opens http://localhost:5173 in browser
  - [ ] USER clicks "Choose Audio File" and loads an audio file
  - [ ] USER clicks "Play"
  - [ ] USER moves all three sliders (Delay Time, Feedback, Mix)
  - [ ] Verify: Values update in UI immediately
  - [ ] Verify: Audio effect changes accordingly (hear delay/feedback/mix changes)
  - [ ] Verify: No console errors (F12 → Console)
  - [ ] Verify: sliderDragStarted/sliderDragEnded don't cause errors (they should be null/no-op in web mode)
  - [ ] Screenshot: `.sisyphus/evidence/task6-web-regression.png`

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `fix(editor): enable window resizing in DAW` | plugin/src/PluginEditor.cpp | Build succeeds |
| 2 | `feat(ui): add slider gesture lifecycle to ParameterState and useParameter` | ui/src/runtime/types.ts, ui/src/runtime/JuceRuntime.ts, ui/src/composables/useRuntime.ts | npm run build |
| 3 | `fix(ui): call sliderDragStarted/Ended for DAW automation` | ui/src/components/SliderControl.vue | npm run build |

---

## Success Criteria

### Verification Commands (RUN BY USER ON HOST MAC, NOT EXECUTOR)
```bash
# USER runs these on host Mac - executor must NOT run build commands
npm run release:vst  # Build plugin - should succeed
cd ui && npm run build  # Build UI - should succeed
```

### Final Checklist
- [ ] Editor resizes in Logic Pro
- [ ] Editor resizes in Ableton Live
- [ ] Slider automation records in DAW
- [ ] Slider undo/redo works as single gesture
- [ ] Web version still works (no regression)
- [ ] All commits follow conventional format

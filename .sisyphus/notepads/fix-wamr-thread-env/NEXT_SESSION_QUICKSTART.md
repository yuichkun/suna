# Next Session Quick Start

**When user provides diagnostic log, use this guide to quickly execute TODO 3.**

---

## Step 1: Identify Pattern (30 seconds)

User will share output of:
```bash
cat ~/Desktop/suna_debug.log | grep "DIAG"
```

### Pattern Recognition

**Pattern A** - Look for:
```
init_result=true
env_inited_after=true
```
→ Go to Section A

**Pattern B** - Look for:
```
init_result=true
env_inited_after=false
ANOMALY - init=true but env_inited=false
```
→ Go to Section B

**Pattern C** - Look for:
```
init_result=false
FATAL - init_thread_env returned false
```
→ Go to Section C

---

## Section A: Pattern A Response (5 minutes)

### Success! The fix worked.

**Actions**:

1. **Verify WASM calls succeed**
   - Ask user to confirm: "Do you see 'WASM call success=true' in the log?"
   - Ask user to confirm: "Can you hear the delay effect + 220Hz sine?"

2. **Mark TODO 2 complete** in plan file:
   ```markdown
   - [x] 2. User rebuilds, tests, and shares diagnostic log (USER TASK)
     - [x] Plugin built successfully
     - [x] Diagnostic log captured
     - [x] Pattern identified (A, B, or C)
   ```

3. **Mark TODO 3 complete** in plan file:
   ```markdown
   - [x] 3. Apply targeted fix based on diagnosis (AFTER DIAGNOSTIC)
   ```

4. **Optional: Offer cleanup**
   - Ask user: "Would you like me to reduce the diagnostic log verbosity?"
   - If yes: Use `.sisyphus/notepads/fix-wamr-thread-env/PATTERN_A_CLEANUP.md`
   - If no: Skip

5. **Mark all success criteria complete**:
   ```markdown
   - [x] Root cause identified through diagnostic logs
   - [x] Fix applied based on diagnosis
   - [x] Plugin produces wet signal in DAW
   - [x] No "thread signal env not inited" errors
   ```

6. **Record in learnings**:
   ```markdown
   ## Pattern A Confirmed
   - Root cause: Missing thread env initialization on audio thread
   - Solution: Added init code in processBlock()
   - Result: Success, plugin working
   ```

7. **Close session**
   - Commit final updates
   - Session complete!

---

## Section B: Pattern B Response (10 minutes)

### TLS/Symbol issue detected. User needs to rebuild WAMR.

**Actions**:

1. **Confirm pattern**
   - Verify log shows `init_result=true` but `env_inited_after=false`

2. **Guide user to rebuild WAMR**
   - Share commands from `.sisyphus/notepads/fix-wamr-thread-env/PATTERN_BC_GUIDE.md`
   - Key command: `cmake .. -DWAMR_DISABLE_HW_BOUND_CHECK=1`

3. **Wait for user to rebuild and retest**
   - User will run: `npm run release:vst`
   - User will test in DAW
   - User will share new log

4. **Verify success**
   - Check for: "WASM call success=true"
   - Check for: No "thread signal env not inited" errors
   - Ask: "Can you hear the delay effect?"

5. **Mark complete** (same as Pattern A steps 2-6)

6. **Record in learnings**:
   ```markdown
   ## Pattern B Confirmed
   - Root cause: TLS not working across library boundary
   - Solution: Rebuilt WAMR with -DWAMR_DISABLE_HW_BOUND_CHECK=1
   - Result: Success, plugin working
   ```

7. **Close session**

---

## Section C: Pattern C Response (10 minutes)

### Init fails. User needs to rebuild WAMR.

**Actions**:

1. **Confirm pattern**
   - Verify log shows `init_result=false`

2. **Guide user to rebuild WAMR**
   - Same as Pattern B
   - Share commands from `.sisyphus/notepads/fix-wamr-thread-env/PATTERN_BC_GUIDE.md`

3. **Wait for user to rebuild and retest**

4. **Verify success**

5. **Mark complete** (same as Pattern A steps 2-6)

6. **Record in learnings**:
   ```markdown
   ## Pattern C Confirmed
   - Root cause: Thread env init failing (signal handler setup)
   - Solution: Rebuilt WAMR with -DWAMR_DISABLE_HW_BOUND_CHECK=1
   - Result: Success, plugin working
   ```

7. **Close session**

---

## If User Reports Continued Failure

If plugin still doesn't work after Pattern B/C fix:

1. **Collect diagnostic data**
   - Use commands from PATTERN_BC_GUIDE.md "If Still Fails" section

2. **Analyze**
   - Check library architecture (should be arm64)
   - Check build flags (should show WAMR_DISABLE_HW_BOUND_CHECK=ON)
   - Check symbols

3. **Document**
   - Add to `issues.md`
   - May need to escalate or investigate further

---

## Quick Checklist

- [ ] Identify pattern (A/B/C)
- [ ] Execute appropriate response
- [ ] Verify success with user
- [ ] Mark TODO 2 complete
- [ ] Mark TODO 3 complete
- [ ] Mark success criteria complete
- [ ] Record in learnings
- [ ] Commit updates
- [ ] Close session

**Estimated time**: 5-15 minutes depending on pattern


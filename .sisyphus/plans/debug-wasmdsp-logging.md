# Debug WasmDSP - Add FileLogger Logging

## Context

### Observation Summary
**問題**: Native plugin (AudioPluginHost/Cubase) で wet 信号が出ない
- AudioPluginHost: 完全に無音
- Cubase: dry音のみ
- Web版: 正常動作 (dry/delay/sine全て動く)

### Confirmed Facts (from logs)
- WasmDSP initialized: SUCCESS
- prepareToPlay called: 48000Hz, 512 samples
- processBlock called: "First call with 512 samples"
- Editor open/close: No crash

### Root Cause Hypothesis
`WasmDSP.cpp` の全エラーハンドリングが `DBG()` マクロを使用。
DBG() はリリースビルドでは出力されないため、失敗が無言で発生している。

**最も疑わしいシナリオ:**
`allocateBuffers()` が失敗 → `prepared_` が false のまま → processBlock で passthrough (dry only)

---

## Work Objectives

### Core Objective
WasmDSP.cpp の全 DBG() を `juce::Logger::writeToLog()` に置き換え、
失敗箇所を正確に特定できるようにする。

### Concrete Deliverables
- `plugin/src/WasmDSP.cpp`: 全 DBG() を Logger::writeToLog() に置換
- 追加の診断ログ: allocateBuffers, prepareToPlay, processBlock の各失敗パス

### Must Have
- 全 DBG() 呼び出しを Logger::writeToLog() に変更
- allocateBuffers() で memBase null チェックのログ追加
- prepareToPlay() で prepared_ の状態をログ
- processBlock() で passthrough モードに入った場合のログ (初回のみ)
- processBlock() で WASM call 成功時のログ (初回のみ)

### Must NOT Have
- DSP処理ロジックの変更
- 新しい依存関係の追加
- 毎回の processBlock でログ出力 (audio thread 問題)

### Build Constraint (CRITICAL)
**ビルドコマンドは一切実行しないこと。**
- 実行環境: Docker (Linux/x86)
- ユーザー環境: M1 Mac (ARM)
- ビルド成果物が混在すると動作しなくなる
- コード変更のみ行い、ビルドはユーザーが host 側で実行する

---

## TODOs

- [x] 1. Replace all DBG() calls with Logger::writeToLog() in WasmDSP.cpp

  **What to do**:
  - Line 17: `DBG("WasmDSP::initialize()...` → `juce::Logger::writeToLog(...)`
  - Line 24: `DBG("...malloc failed")` → Logger
  - Line 37: `DBG("...wasm_runtime_full_init failed")` → Logger
  - Line 47: `DBG("...wasm_runtime_load failed")` → Logger
  - Line 59: `DBG("...wasm_runtime_instantiate failed")` → Logger
  - Line 70: `DBG("...wasm_runtime_create_exec_env failed")` → Logger
  - Line 82: `DBG("...lookupFunctions failed")` → Logger
  - Line 88: `DBG("...Success")` → Logger
  - Line 148: `DBG("WASM memory too small")` → Logger
  - Line 173: `DBG("prepareToPlay")` → Logger
  - Line 209: `DBG("processBlock - First call")` → Logger
  - Line 239: `DBG("WASM call failed")` → Logger

  **Pattern**:
  ```cpp
  // Before
  DBG("message" << variable);
  
  // After
  juce::Logger::writeToLog("message" + juce::String(variable));
  ```

  **Parallelizable**: NO

  **References**:
  - `plugin/src/WasmDSP.cpp:17-248` - 全 DBG() 呼び出し箇所

  **Acceptance Criteria**:
  - [ ] 全12箇所の DBG() が Logger::writeToLog() に変更されている
  - [ ] コンパイルエラーなし

  **Commit**: NO (Task 2と一緒にコミット)

---

- [x] 2. Add diagnostic logging for failure paths

  **What to do**:
  
  **allocateBuffers() (line 103-170)**:
  ```cpp
  // Line 108 (after memBase check)
  if (!memBase) {
      juce::Logger::writeToLog("WasmDSP::allocateBuffers() - Failed: memBase is null");
      return false;
  }
  
  // After line 169 (success)
  juce::Logger::writeToLog("WasmDSP::allocateBuffers() - Success, maxBlockSize=" + 
      juce::String(maxBlockSize));
  ```

  **prepareToPlay() (line 172-203)**:
  ```cpp
  // Line 174 (if not initialized)
  if (!initialized_) {
      juce::Logger::writeToLog("WasmDSP::prepareToPlay() - Aborted: not initialized");
      return;
  }
  
  // Line 191-193 (if allocateBuffers fails)
  if (!allocateBuffers(maxBlockSize)) {
      juce::Logger::writeToLog("WasmDSP::prepareToPlay() - Failed: allocateBuffers returned false");
      return;
  }
  
  // Line 202 (after prepared_ = true)
  juce::Logger::writeToLog("WasmDSP::prepareToPlay() - Success, prepared_=true");
  ```

  **processBlock() (line 205-248)**:
  ```cpp
  // Line 213-220 (passthrough path - first time only)
  static bool passthroughLogged = false;
  if (!prepared_ || numSamples <= 0 || numSamples > maxBlockSize_) {
      if (!passthroughLogged) {
          juce::Logger::writeToLog("WasmDSP::processBlock() - PASSTHROUGH MODE: prepared_=" +
              juce::String(prepared_.load()) + ", numSamples=" + juce::String(numSamples) +
              ", maxBlockSize_=" + juce::String(maxBlockSize_));
          passthroughLogged = true;
      }
      // ... existing passthrough code
  }
  
  // After line 235 (WASM call - first time only)
  static bool wasmCallLogged = false;
  if (!wasmCallLogged) {
      juce::Logger::writeToLog("WasmDSP::processBlock() - WASM call success=" + 
          juce::String(success ? "true" : "false"));
      wasmCallLogged = true;
  }
  ```

  **Parallelizable**: NO (depends on Task 1)

  **References**:
  - `plugin/src/WasmDSP.cpp:103-248`

  **Acceptance Criteria**:
  - [ ] allocateBuffers に成功/失敗ログが追加されている
  - [ ] prepareToPlay に初期化チェック、allocateBuffers結果、prepared_状態のログが追加されている
  - [ ] processBlock に passthrough検出ログが追加されている (初回のみ)
  - [ ] processBlock に WASM call結果ログが追加されている (初回のみ)

  **Commit**: YES
  - Message: `debug(wasmdsp): replace DBG with FileLogger, add diagnostic logging`
  - Files: `plugin/src/WasmDSP.cpp`

---

## Expected Log Output (After Fix)

正常動作時:
```
WasmDSP::initialize() - Loading AOT module...
WasmDSP::initialize() - Success
WasmDSP::prepareToPlay() - sampleRate=48000 blockSize=512
WasmDSP::allocateBuffers() - Success, maxBlockSize=512
WasmDSP::prepareToPlay() - Success, prepared_=true
WasmDSP::processBlock() - First call with 512 samples
WasmDSP::processBlock() - WASM call success=true
```

失敗時 (例: allocateBuffers 失敗):
```
WasmDSP::initialize() - Loading AOT module...
WasmDSP::initialize() - Success
WasmDSP::prepareToPlay() - sampleRate=48000 blockSize=512
WasmDSP::allocateBuffers() - Failed: memBase is null
WasmDSP::prepareToPlay() - Failed: allocateBuffers returned false
WasmDSP::processBlock() - First call with 512 samples
WasmDSP::processBlock() - PASSTHROUGH MODE: prepared_=false, numSamples=512, maxBlockSize_=0
```

---

## Success Criteria

- [x] 全 DBG() が Logger::writeToLog() に置換されている
- [x] 追加の診断ログが実装されている
- [x] リリースビルドでログ出力される
- [x] `~/Desktop/suna_debug.log` で失敗箇所を特定可能

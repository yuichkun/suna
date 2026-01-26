# Suna-Kodama Parity: Discrepancy Fix Plan

## Context

### Original Request
Sunaプロジェクトは https://github.com/yuichkun/kodama-vst を参考に実装されたが、以下の重大な問題がある：
1. アプリがクラッシュする
2. 音がエフェクトなしで出る（パススルー）
3. release:vstしたのにUIに「JUCE」ではなく「web」と表示される

全体的にKodamaとの差異（discrepancy）を減らし、安定性と機能の同等性を達成する。

### Interview Summary
**Key Discussions**:
- DSP層の違い: Kodama=Rust静的リンク、Suna=MoonBit via WAMR (設計意図通り、変更不要)
- メモリ管理: `BUFFER_START=900000` がハードコードされており、MoonBitヒープとの整合性が未検証
- エラー処理: WasmDSP.cpp line 172-177 で silent failure → デバッグ不可能
- JUCE検出: Kodama=`window.__JUCE__`、Suna=`window.juce` (バグ)
- Thread safety: `prepared_`, `initialized_` が非atomic

**Research Findings**:
- Kodamaのアーキテクチャ: Rust DSP → C FFI → JUCE、Vue UI with `window.__JUCE__` detection
- Sunaのアーキテクチャ: MoonBit DSP → WASM → WAMR runtime → JUCE
- メモリレイアウト計算: MoonBit heap-start=65536, delay_buffer ~768KB, BUFFER_START=900000 (理論上安全だが検証なし)

### Metis Review
**Identified Gaps** (addressed):
- JUCE検出の修正方法が明確化 (`window.__JUCE__` を使用)
- エラー処理戦略: ログ + パススルー方式を採用
- Thread safety: `std::atomic<bool>` への変更
- メモリ検証: ランタイムアサーションの追加
- Waveform visualization: 今回のスコープ外と決定

---

## Work Objectives

### Core Objective
KodamaとSunaの間のdiscrepancyを修正し、クラッシュ、パススルー、UI表示バグを解消する。

### Concrete Deliverables
- `/workspace/ui/src/App.vue`: JUCE検出ロジック修正
- `/workspace/plugin/src/WasmDSP.cpp`: エラー処理、メモリ検証、Thread safety修正
- `/workspace/plugin/src/WasmDSP.h` または `/workspace/plugin/include/suna/WasmDSP.h`: atomic flags宣言
- `/workspace/plugin/src/PluginProcessor.cpp`: 必要に応じた調整

### Definition of Done
- [ ] リリースビルドでUIに「JUCE」バッジが表示される
- [ ] WASM呼び出し失敗時、クラッシュせずパススルー（入力→出力コピー）
- [ ] メモリオフセットの安全性がランタイムで検証される
- [ ] Thread safety flags が atomic 化されている
- [ ] デバッグログが追加され、問題の診断が可能

### Must Have
- JUCE検出修正 (`window.juce` → `window.__JUCE__`)
- WASM呼び出しエラー時のフォールバック処理
- メモリオフセット検証とドキュメント
- `std::atomic<bool>` for `initialized_`, `prepared_`
- DBGマクロによるデバッグログ

### Must NOT Have (Guardrails)
- MoonBit DSPアルゴリズムの変更 (delay.mbt, buffer.mbt)
- WAMRから別のWASMランタイムへの変更
- Waveform visualization の実装（今回スコープ外）
- JUCEパラメータバインディングの変更
- オーディオスレッドでのブロッキングロック（try-lockパターンのみ）
- ビルドコマンドの実行（ユーザーが手動で行う）

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (tests/cpp/ に既存テストあり)
- **User wants tests**: Manual verification (ユーザーがビルド・テスト実行)
- **Framework**: CMake + 既存のテストハーネス

### Manual QA Procedures

各TODOの完了後、ユーザーが以下を実行:

**UIバッジ確認:**
1. `npm run release:vst` でビルド
2. DAW または Standalone でプラグインを起動
3. UIに「JUCE」バッジが表示されることを確認

**エラー処理確認:**
1. 意図的にWASM呼び出しを失敗させる（例: AOTファイルを一時的に削除）
2. プラグインがクラッシュせず、音声がパススルーすることを確認
3. ログ出力を確認

**オーディオ処理確認:**
1. プラグインを起動
2. 音声を入力し、ディレイエフェクトが適用されることを確認
3. パラメータ（Delay Time, Feedback, Mix）が機能することを確認

---

## Task Flow

```
Task 1 (JUCE検出) ─────────────────────────┐
                                            │
Task 2 (Thread Safety) ───────────────────┬─┴─> Task 6 (統合確認)
                                          │
Task 3 (メモリ検証) ──────────────────────┤
                                          │
Task 4 (エラー処理) ──────────────────────┤
                                          │
Task 5 (デバッグログ) ────────────────────┘
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 1 | 独立したUI変更 |
| B | 2, 3, 4, 5 | C++変更だが独立したファイル領域 |
| C | 6 | 全ての変更完了後の統合確認 |

| Task | Depends On | Reason |
|------|------------|--------|
| 6 | 1, 2, 3, 4, 5 | 全変更の統合確認 |

---

## TODOs

- [x] 1. JUCE検出ロジックの修正

  **What to do**:
  - `/workspace/ui/src/App.vue` の line 34 付近を修正
  - `window.juce` → `window.__JUCE__` に変更
  - Kodamaの `JuceRuntime.ts` パターンに合わせる

  **Must NOT do**:
  - WebRuntime.ts の変更（Web版は別のパス）
  - 他のUIコンポーネントの変更

  **Parallelizable**: YES (独立したファイル)

  **References**:

  **Pattern References**:
  - Kodama `JuceRuntime.ts`: `window.__JUCE__` の使用パターン (https://github.com/yuichkun/kodama-vst/blob/main/ui/src/runtime/JuceRuntime.ts#L4-L89)

  **Current Implementation**:
  - `/workspace/ui/src/App.vue:34` - 現在の `window.juce` チェック

  **WHY Each Reference Matters**:
  - Kodamaは動作確認済みの参照実装。JUCE 8の `withNativeIntegrationEnabled()` は `window.__JUCE__` を注入するため、これに合わせる必要がある

  **Acceptance Criteria**:

  **Manual Verification (ユーザー実行)**:
  - [ ] `npm run release:vst` でビルド
  - [ ] Standalone または DAW でプラグインを起動
  - [ ] UIの右上に「JUCE」バッジが表示される（「WEB」ではない）
  - [ ] 開発モード (`npm run dev:juce`) では「WEB」と表示される（window.__JUCE__がないため正常）

  **Commit**: YES
  - Message: `fix(ui): correct JUCE detection from window.juce to window.__JUCE__`
  - Files: `ui/src/App.vue`

---

- [x] 2. Thread Safety Flags の Atomic 化

  **What to do**:
  - `/workspace/plugin/include/suna/WasmDSP.h` または `/workspace/plugin/src/WasmDSP.h` を確認
  - `bool initialized_` → `std::atomic<bool> initialized_`
  - `bool prepared_` → `std::atomic<bool> prepared_`
  - `<atomic>` ヘッダーのインクルード追加
  - 読み書き箇所で `.load()` / `.store()` を使用

  **Must NOT do**:
  - mutex や SpinLock の追加（オーディオスレッドでブロッキング禁止）
  - 他のメンバー変数の変更

  **Parallelizable**: YES (with 3, 4, 5)

  **References**:

  **Pattern References**:
  - Kodama `PluginProcessor.h:64-67`: `std::atomic<float>*` の使用パターン
  - JUCE Thread Safety ガイドライン: オーディオスレッドでのロックフリーアクセス

  **Current Implementation**:
  - `/workspace/plugin/include/suna/WasmDSP.h` - WasmDSPクラス定義
  - `/workspace/plugin/src/WasmDSP.cpp` - `initialized_`, `prepared_` の使用箇所

  **WHY Each Reference Matters**:
  - `prepareToPlay()` はメッセージスレッド、`processBlock()` はオーディオスレッドから呼ばれる
  - 非atomic変数への同時アクセスはデータ競合を引き起こす可能性がある

  **Acceptance Criteria**:

  **Code Verification**:
  - [ ] `std::atomic<bool> initialized_{false}` が宣言されている
  - [ ] `std::atomic<bool> prepared_{false}` が宣言されている
  - [ ] `#include <atomic>` が追加されている
  - [ ] 全ての読み書きが `.load()` / `.store()` を使用

  **Manual Verification (ユーザー実行)**:
  - [ ] コンパイルエラーなし
  - [ ] プラグインが正常に動作（クラッシュしない）

  **Commit**: YES
  - Message: `fix(plugin): make WasmDSP flags atomic for thread safety`
  - Files: `plugin/include/suna/WasmDSP.h`, `plugin/src/WasmDSP.cpp`

---

- [x] 3. メモリオフセット検証とドキュメント

  **What to do**:
  - `/workspace/plugin/src/WasmDSP.cpp` の `BUFFER_START = 900000` にドキュメントコメント追加
  - `allocateBuffers()` または `prepareToPlay()` でメモリサイズ検証を追加
  - WASM linear memory サイズが `BUFFER_START + 必要バッファサイズ` を満たすことを確認
  - 検証失敗時は `initialized_ = false` のままにして安全に失敗

  **Must NOT do**:
  - BUFFER_START の値の変更（既存のMoonBitコードとの互換性維持）
  - MoonBit側のメモリレイアウト変更

  **Parallelizable**: YES (with 2, 4, 5)

  **References**:

  **Current Implementation**:
  - `/workspace/plugin/src/WasmDSP.cpp:101` - `BUFFER_START = 900000`
  - `/workspace/dsp/src/moon.pkg.json` - `heap-start-address: 65536`
  - `/workspace/dsp/src/delay.mbt` - `delay_buffer: FixedArray[Float]` の確保

  **WAMR Memory API**:
  - `wasm_runtime_get_memory_size()` または同等のAPIでメモリサイズ取得

  **Memory Layout Documentation**:
  ```
  WASM Linear Memory Layout:
  ┌─────────────────────────────────────────┐
  │ 0x00000 - 0x0FFFF: MoonBit Stack/Heap   │ (heap-start: 65536)
  │ 0x10000 - 0xDBFFF: Delay Buffer (~768KB)│ (96000*2*4 bytes)
  │ 0xDC000 - 0xDBC9F: Reserved             │
  │ 0xDBC9F (900000): Audio Buffers Start   │ <- BUFFER_START
  │   - Left In  (maxBlockSize * 4)         │
  │   - Right In (maxBlockSize * 4)         │
  │   - Left Out (maxBlockSize * 4)         │
  │   - Right Out (maxBlockSize * 4)        │
  └─────────────────────────────────────────┘
  ```

  **WHY Each Reference Matters**:
  - メモリ境界を超えたアクセスがクラッシュの原因となりうる
  - ドキュメントがないと将来の変更で衝突が発生するリスク

  **Acceptance Criteria**:

  **Code Verification**:
  - [ ] `BUFFER_START` の上にメモリレイアウトを説明するコメントがある
  - [ ] `prepareToPlay()` 内でWASMメモリサイズを検証するコードがある
  - [ ] 検証失敗時のログ出力がある
  - [ ] 検証失敗時に `initialized_ = false` になる

  **Manual Verification (ユーザー実行)**:
  - [ ] 正常ケース: プラグインが正常に動作
  - [ ] 異常ケース: メモリ不足時にクラッシュせずエラーログが出る

  **Commit**: YES
  - Message: `fix(plugin): add memory layout validation and documentation for BUFFER_START`
  - Files: `plugin/src/WasmDSP.cpp`

---

- [x] 4. WASM呼び出しエラー処理の改善

  **What to do**:
  - `/workspace/plugin/src/WasmDSP.cpp` の `processBlock()` 内、line 172-177 付近を修正
  - WASM呼び出し失敗時に:
    1. `DBG()` でエラーログ出力
    2. 入力バッファを出力バッファにコピー（パススルー）
  - 初期化失敗時 (`initialized_ == false`) も同様にパススルー

  **Must NOT do**:
  - クラッシュを引き起こす可能性のある処理
  - オーディオスレッドでのブロッキング操作

  **Parallelizable**: YES (with 2, 3, 5)

  **References**:

  **Pattern References**:
  - Kodama `PluginProcessor.cpp:102-153`: null checks と安全なフォールバック
  - JUCE `DBG()` マクロ: デバッグビルドでのログ出力（リリースでストリップ）

  **Current Implementation**:
  - `/workspace/plugin/src/WasmDSP.cpp:172-177` - 現在の silent failure

  **Error Handling Pattern**:
  ```cpp
  if (!success) {
      const char* exception = wasm_runtime_get_exception(moduleInst_);
      DBG("WASM call failed: " << (exception ? exception : "unknown error"));
      
      // Passthrough: copy input to output
      std::memcpy(outputL, inputL, numSamples * sizeof(float));
      std::memcpy(outputR, inputR, numSamples * sizeof(float));
      return;
  }
  ```

  **WHY Each Reference Matters**:
  - Silent failure は問題の診断を不可能にする
  - パススルーはクラッシュより安全で、ユーザー体験を維持

  **Acceptance Criteria**:

  **Code Verification**:
  - [ ] WASM呼び出し失敗時に `DBG()` でログ出力するコードがある
  - [ ] 失敗時に入力→出力へのコピー（パススルー）が実装されている
  - [ ] `initialized_ == false` 時も同様のパススルー処理がある

  **Manual Verification (ユーザー実行)**:
  - [ ] 正常ケース: エフェクトが適用される
  - [ ] 異常ケース (AOTファイル削除): クラッシュせず、音声がパススルー
  - [ ] デバッグビルドでログが出力される

  **Commit**: YES
  - Message: `fix(plugin): add error handling with passthrough fallback for WASM calls`
  - Files: `plugin/src/WasmDSP.cpp`

---

- [x] 5. デバッグログの追加

  **What to do**:
  - `/workspace/plugin/src/WasmDSP.cpp` の主要な処理ポイントに `DBG()` を追加:
    - `initialize()`: 成功/失敗
    - `prepareToPlay()`: sample rate, block size, メモリ検証結果
    - `processBlock()`: 最初の呼び出し時のみログ（毎フレームは不可）
  - `/workspace/plugin/src/PluginProcessor.cpp` にも必要に応じて追加

  **Must NOT do**:
  - `processBlock()` の毎フレームでのログ出力（パフォーマンス劣化）
  - リリースビルドで残るログ（`DBG()` はリリースで自動ストリップ）

  **Parallelizable**: YES (with 2, 3, 4)

  **References**:

  **JUCE DBG Macro**:
  - `DBG("message")` - デバッグビルドでのみ出力、リリースでストリップ
  - `DBG("value: " << value)` - ストリーム形式で変数出力可能

  **Current Implementation**:
  - `/workspace/plugin/src/WasmDSP.cpp` - 現在ログなし
  - `/workspace/plugin/src/PluginProcessor.cpp` - 現在ログなし

  **Logging Pattern**:
  ```cpp
  // In initialize()
  DBG("WasmDSP::initialize() - Loading AOT module...");
  // ... after success
  DBG("WasmDSP::initialize() - Success");
  
  // In prepareToPlay()
  DBG("WasmDSP::prepareToPlay() - sampleRate=" << sampleRate << " blockSize=" << maxBlockSize);
  ```

  **WHY Each Reference Matters**:
  - 問題発生時の診断に不可欠
  - パフォーマンスへの影響なし（リリースでストリップ）

  **Acceptance Criteria**:

  **Code Verification**:
  - [ ] `initialize()` に成功/失敗のログがある
  - [ ] `prepareToPlay()` にパラメータのログがある
  - [ ] `processBlock()` の毎フレームログがない（パフォーマンス確認）

  **Manual Verification (ユーザー実行)**:
  - [ ] デバッグビルドで起動時にログが出力される
  - [ ] リリースビルドでログが出力されない

  **Commit**: YES
  - Message: `feat(plugin): add debug logging for initialization and preparation`
  - Files: `plugin/src/WasmDSP.cpp`, `plugin/src/PluginProcessor.cpp`

---

- [ ] 6. Shutdown Race Condition の修正 (クラッシュ対策)

  **What to do**:
  - `/workspace/plugin/src/WasmDSP.cpp` の `shutdown()` を修正
  - `prepared_` と `initialized_` を **最初に** `false` に設定
  - その後でリソースを解放
  - これによりaudio threadがリソース使用中にshutdownが走っても安全になる

  **Current Bug**:
  ```cpp
  void WasmDSP::shutdown() {
      // 1. リソース破棄 (audio threadがまだ使用中かも!)
      if (execEnv_) { ... destroy ... }
      // 2. フラグを最後に設定 (遅すぎる!)
      initialized_ = false;  // Line 312
      prepared_ = false;     // Line 313
  }
  ```

  **Fix Pattern**:
  ```cpp
  void WasmDSP::shutdown() {
      // 1. FIRST: フラグをfalseに (audio threadをブロック)
      prepared_.store(false);
      initialized_.store(false);
      
      // 2. THEN: リソース破棄 (安全)
      if (execEnv_) { ... }
  }
  ```

  **Must NOT do**:
  - mutex/SpinLock の追加（オーディオスレッドでブロッキング禁止）

  **Parallelizable**: NO (クリティカルな修正)

  **References**:
  - Kodama `PluginProcessor.cpp:20-27`: 安全な破棄パターン
  - JUCE Thread Safety ガイドライン

  **Acceptance Criteria**:
  - [ ] `shutdown()` の最初で `prepared_.store(false)` と `initialized_.store(false)` が呼ばれる
  - [ ] VST閉じてもクラッシュしない

  **Commit**: YES
  - Message: `fix(plugin): prevent crash on shutdown by clearing flags first`
  - Files: `plugin/src/WasmDSP.cpp`

---

- [ ] 7. Web UI File Picker の実装 (Kodamaパリティ)

  **What to do**:
  - Kodamaの `WebAudioControls.vue` パターンを参考に実装
  - `/workspace/ui/src/App.vue` にファイルピッカーUI追加
  - `/workspace/ui/src/runtime/WebRuntime.ts` に以下を追加:
    - `loadAudioFile(file: File): Promise<void>`
    - `play(): void`
    - `stop(): void`
    - `getIsPlaying(): boolean`
    - `hasAudioLoaded(): boolean`
  - `/workspace/ui/src/runtime/types.ts` のインターフェース更新

  **Current State** (Suna):
  - マイク入力のみ (`getUserMedia`)
  - ファイル選択なし

  **Kodama Pattern**:
  - ファイルピッカーでオーディオファイルを選択
  - `AudioContext.decodeAudioData()` でデコード
  - `AudioBufferSourceNode` で再生
  - ループ再生対応

  **Must NOT do**:
  - JUCE側の変更（Webモードのみの機能）

  **Parallelizable**: YES (UI/Webのみ)

  **References**:
  - Kodama `WebAudioControls.vue`: ファイルピッカーUI
  - Kodama `WebRuntime.ts`: `loadAudioFile()`, `play()`, `stop()`

  **Acceptance Criteria**:
  - [ ] Web版でファイル選択ボタンが表示される
  - [ ] オーディオファイル選択後、Play/Stopボタンが機能する
  - [ ] ディレイエフェクトが適用された音声が聞こえる

  **Commit**: YES
  - Message: `feat(ui): add audio file picker for web mode (Kodama parity)`
  - Files: `ui/src/App.vue`, `ui/src/runtime/WebRuntime.ts`, `ui/src/runtime/types.ts`

---

- [ ] 8. 統合確認と最終検証

  **What to do**:
  - 全ての変更が統合された状態でビルドと動作確認
  - 全ての問題が解消されていることを確認:
    1. UIに「JUCE」バッジ表示
    2. エフェクトが正常に適用される (VSTでもWebでも)
    3. クラッシュしない (起動/終了とも)
    4. Web版でファイルピッカーが動作
  - 既存機能のリグレッションがないことを確認

  **Must NOT do**:
  - 追加の機能変更
  - スコープ外の修正

  **Parallelizable**: NO (depends on 1-7)

  **References**:

  **All Modified Files**:
  - `/workspace/ui/src/App.vue` - JUCE検出 + Web File Picker UI
  - `/workspace/ui/src/runtime/WebRuntime.ts` - File loading + playback
  - `/workspace/ui/src/runtime/types.ts` - Runtime interface
  - `/workspace/plugin/include/suna/WasmDSP.h` - atomic flags
  - `/workspace/plugin/src/WasmDSP.cpp` - エラー処理、メモリ検証、ログ、shutdown修正
  - `/workspace/plugin/src/PluginProcessor.cpp` - destructor
  - `/workspace/dsp/src/delay.mbt` - stereo processing
  - `/workspace/dsp/src/buffer.mbt` - process_stereo call

  **Acceptance Criteria**:

  **Manual Verification (ユーザー実行)**:
  - [ ] `npm run release:vst` が成功
  - [ ] `npm run build:dsp` が成功 (MoonBit変更後必須)
  - [ ] VST Standalone起動: クラッシュなし
  - [ ] VST終了: クラッシュなし
  - [ ] UIバッジ: 「JUCE」と表示
  - [ ] VSTオーディオ: ディレイエフェクトが聞こえる
  - [ ] パラメータ: Delay Time, Feedback, Mix が機能
  - [ ] DAWでの動作: VST3/AU がロードされ正常動作
  - [ ] Web版: `npm run dev:web` でファイルピッカーが表示
  - [ ] Web版: オーディオファイル選択→Play→ディレイが聞こえる
  - [ ] 長時間テスト: 5分以上再生してクラッシュなし

  **Commit**: NO (統合確認のみ、変更なし)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `fix(ui): correct JUCE detection from window.juce to window.__JUCE__` | ui/src/App.vue | Manual: UIバッジ確認 |
| 2 | `fix(plugin): make WasmDSP flags atomic for thread safety` | plugin/include/suna/WasmDSP.h, plugin/src/WasmDSP.cpp | コンパイル成功 |
| 3 | `fix(plugin): add memory layout validation and documentation for BUFFER_START` | plugin/src/WasmDSP.cpp | コンパイル成功 |
| 4 | `fix(plugin): add error handling with passthrough fallback for WASM calls` | plugin/src/WasmDSP.cpp | コンパイル成功 |
| 5 | `feat(plugin): add debug logging for initialization and preparation` | plugin/src/WasmDSP.cpp, plugin/src/PluginProcessor.cpp | コンパイル成功 |
| 6 | `fix(plugin): prevent crash on shutdown by clearing flags first` | plugin/src/WasmDSP.cpp | VST終了でクラッシュしない |
| 7 | `feat(ui): add audio file picker for web mode (Kodama parity)` | ui/src/App.vue, ui/src/runtime/*.ts | Web版でファイル再生可能 |
| 8 | - | - | 統合テスト |

---

## Success Criteria

### Verification Commands (ユーザー実行)
```bash
# ビルド
npm run release:vst

# Standaloneテスト
open ./build/Suna_artefacts/Release/Standalone/Suna.app

# VST3テスト (DAWで)
# ~/Library/Audio/Plug-Ins/VST3/Suna.vst3 をロード
```

### Final Checklist
- [ ] UIに「JUCE」バッジが表示される (「WEB」ではない)
- [ ] ディレイエフェクトが聞こえる (パススルーではない)
- [ ] 5分以上の再生でクラッシュしない
- [ ] デバッグビルドでログが出力される
- [ ] 全てのパラメータが機能する (Delay Time, Feedback, Mix)

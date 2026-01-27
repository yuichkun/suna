# Debug Audio Plugin - Fact Collection Phase

## Context

### Original Request
プラグインが複数の環境で問題を抱えている:
- AudioPluginHost: 開くとクラッシュ
- Cubase: dry音がそのまま流れる、editor close時にクラッシュ
- Web版: 正常動作 (✅)

### Interview Summary
**Key Discussions**:
- 推測ではなくfact収集から始める
- sine波(220Hz)をwet信号に追加してDSP動作確認
- デバッグログ追加でクラッシュ箇所特定
- 破棄順序の問題を切り分けるためエディタデストラクタを明示化

**Research Findings**:
- crash.log: `WebBrowserComponent::~WebBrowserComponent()` → WAMR `signal_callback` → `abort()`
- WAMRがSIGSEGV/SIGBUSハンドラーをインストールしWebKitと競合の可能性
- メンバー破棄順序: relays → browser (browserが最後)

### Metis Review
**Identified Gaps** (addressed):
- Debug sine/logsはdebugビルドでのみ有効に → `#if JUCE_DEBUG`で制御
- スコープ制限: crash修正とwet path検証のみ

---

## Work Objectives

### Core Objective
fact収集のためのデバッグコードを追加し、クラッシュ原因とdry音問題の切り分けを可能にする

### Concrete Deliverables
- `dsp/src/delay.mbt`: 220Hz sine波をwet信号に追加
- `plugin/src/PluginEditor.cpp`: 明示的デストラクタ、デバッグログ
- `plugin/src/PluginProcessor.cpp`: 初期化・processBlockのログ強化

### Definition of Done
- [ ] 全てのコード変更が完了している
- [ ] 変更がコンパイル可能な状態である(構文エラーなし)

### Must Have
- wet信号に220Hzのsine波が加算される(mix > 0の時)
- エディタのデストラクタでbrowser.reset()が明示的に先に呼ばれる
- 初期化成功/失敗、processBlock呼び出しのログ

### Must NOT Have (Guardrails)
- DSPアルゴリズムの変更(debug用sine波追加以外)
- 新しい依存関係の追加
- ビルドシステムの変更
- WAMR/WebKit内部の変更

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: NO (この環境ではビルド不可)
- **User wants tests**: Manual verification by user
- **QA approach**: ユーザーがビルド後に確認

---

## Task Flow

```
Task 1 (sine波追加)
    ↓
Task 2 (デストラクタ明示化) ← 並列可能
    ↓
Task 3 (ログ追加) ← 並列可能
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 1, 2, 3 | 全て独立したファイル |

---

## TODOs

- [ ] 1. Add 220Hz sine wave to wet signal in delay.mbt

  **What to do**:
  - グローバルにsine_phaseを追加
  - sine波生成関数を実装(Taylor series近似)
  - `process_stereo`でwet信号にsine波を加算

  **Must NOT do**:
  - delay処理ロジック自体の変更
  - dry信号への影響

  **Parallelizable**: YES (with 2, 3)

  **References**:
  - `dsp/src/delay.mbt:92-104` - process_stereo関数(変更対象)
  - `dsp/src/delay.mbt:6-11` - グローバル状態の定義パターン

  **Acceptance Criteria**:
  - [ ] sine_phase変数がグローバルに追加されている
  - [ ] sine波生成がprocess_stereo内で呼ばれている
  - [ ] wet信号にのみsine波が加算されている(dry信号には影響なし)

  **Commit**: YES
  - Message: `feat(dsp): add 220Hz sine wave to wet signal for debugging`
  - Files: `dsp/src/delay.mbt`

---

- [ ] 2. Implement explicit destructor for PluginEditor

  **What to do**:
  - `~SunaAudioProcessorEditor() = default;`を明示的な実装に変更
  - デストラクタ内で`browser.reset()`を最初に呼ぶ
  - デストラクタ開始/終了のDBGログ追加

  **Must NOT do**:
  - 他のメンバーの手動reset
  - コンストラクタの変更(ログ追加以外)

  **Parallelizable**: YES (with 1, 3)

  **References**:
  - `plugin/src/PluginEditor.cpp:49` - 現在のデフォルトデストラクタ
  - `plugin/src/PluginEditor.h:17` - browser宣言

  **Acceptance Criteria**:
  - [ ] デストラクタが明示的に実装されている
  - [ ] browser.reset()がデストラクタの最初で呼ばれている
  - [ ] DBGログがデストラクタ開始/終了時に出力される
  - [ ] コンストラクタにもログが追加されている

  **Commit**: YES
  - Message: `fix(editor): explicit destructor with browser cleanup first`
  - Files: `plugin/src/PluginEditor.cpp`

---

- [ ] 3. Add debug logging to PluginProcessor

  **What to do**:
  - コンストラクタにWasmDSP初期化結果のログ
  - prepareToPlayにサンプルレート/ブロックサイズのログ
  - processBlockに初回呼び出しログ(既存の確認・強化)

  **Must NOT do**:
  - 処理ロジックの変更
  - リリースビルドへの影響

  **Parallelizable**: YES (with 1, 2)

  **References**:
  - `plugin/src/PluginProcessor.cpp:5-23` - コンストラクタ
  - `plugin/src/PluginProcessor.cpp:27-32` - prepareToPlay
  - `plugin/src/PluginProcessor.cpp:38-71` - processBlock

  **Acceptance Criteria**:
  - [ ] WasmDSP初期化成功/失敗がログに出力される
  - [ ] prepareToPlayでsampleRate, blockSizeがログに出力される
  - [ ] processBlock初回呼び出しがログに出力される

  **Commit**: YES
  - Message: `debug(processor): add logging for initialization and processing`
  - Files: `plugin/src/PluginProcessor.cpp`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(dsp): add 220Hz sine wave to wet signal for debugging` | dsp/src/delay.mbt | N/A (user builds) |
| 2 | `fix(editor): explicit destructor with browser cleanup first` | plugin/src/PluginEditor.cpp | N/A (user builds) |
| 3 | `debug(processor): add logging for initialization and processing` | plugin/src/PluginProcessor.cpp | N/A (user builds) |

---

## Success Criteria

### Final Checklist
- [ ] 全てのTODOが完了している
- [ ] 各ファイルの変更が構文的に正しい

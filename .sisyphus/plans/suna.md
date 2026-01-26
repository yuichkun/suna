# suna - MoonBit VST Foundation Work Plan

## Context

### Original Request
kodama-vst (https://github.com/yuichkun/kodama-vst) の構成を参考に、Rust DSPの代わりにMoonBitを使用したVST基盤を構築する。MoonBitはWASMにコンパイルし、WAMR経由でJUCEと統合する。将来的にGranular Synthへ発展予定。

### Interview Summary
**Key Discussions**:
- **言語選択**: MoonBit絶対条件 (Beta段階のリスク承知の上)
- **目的**: 検証/実験用途
- **初期DSP**: Delay (kodamaと比較検証)
- **Web版**: 同時作成 (AudioWorklet + 同じWASM)
- **UI**: 最低限WebベースUI (Vue、kodama準拠)
- **テスト**: インフラ設定 (moon test, Catch2, Vitest)
- **作業場所**: `/workspace` 直下

**Research Findings**:
- kodama-vst: Rust → 静的ライブラリ → C FFI → JUCE、Vue UI、WebSliderRelay
- MoonBit: Beta、`--target wasm`必須 (wasm-gcはWAMR非対応)、プリミティブ型とFixedArrayでGC影響を最小化
- WAMR: JUCEでHarfBuzz実績あり、AOT推奨、`wasm_runtime_module_malloc`でバッファ確保

### Metis Review
**Identified Gaps** (addressed):
- Phase 0 (PoC) を最初に実行 → 統合検証を最優先タスクに
- `wasm-gc`非対応リスク → `--target wasm`明示指定
- GCリスク → プリミティブ型中心設計、`FixedArray`使用、状態はlinear memory管理
- メモリ無効化リスク → 初期化時一括確保をガードレールに
- 単一tap Delayから開始 → スコープを明確化
- MoonBit状態管理 → PoC(0.5)で状態永続性を明示的に検証

---

## Work Objectives

### Core Objective
MoonBit → WASM → WAMR → JUCE の統合パイプラインを検証し、Delayエフェクトを実装したVST3/AUプラグインと同等のWeb版を構築する。

### Concrete Deliverables
1. `/workspace/` に完全なプロジェクト構造
2. MoonBit DSPモジュール (Delay)
3. JUCE VST3/AU/Standalone プラグイン
4. Web版 (AudioWorklet + Vue UI)
5. テストインフラ (moon test, Catch2, Vitest)

### Definition of Done
- [ ] `moon build --target wasm` → 有効なWASM生成
- [ ] `wamrc` → AOTモジュール生成
- [ ] VST3がDAW (Reaper/Logic/Ableton) で読み込み可能
- [ ] Delay効果が聴覚的に確認可能
- [ ] Web版で同等の動作確認
- [ ] 全テストスイート pass

### Must Have
- MoonBit DSP (Delay: time, feedback, mix パラメータ)
- WAMR統合 (AOTコンパイル)
- VST3/AUフォーマット
- Web版 (AudioWorklet)
- 最小限Vue UI (パラメータスライダー)
- テストインフラ

### Must NOT Have (Guardrails)
- **Multi-tap voices** → 単一tap Delayのみ (将来スコープ)
- **Granular機能** → Delay検証後 (将来スコープ)
- **`--target wasm-gc`** → WAMR非対応、使用禁止
- **`Array`型をDSPで使用** → GCトリガー、`FixedArray`のみ
- **processBlock内でのメモリ割り当て** → リアルタイム安全性違反
- **プリセットシステム** → 将来スコープ
- **MIDI対応** → オーディオエフェクトのみ
- **カスタムUI装飾** → 最小限の機能的UIのみ
- **CI/CD自動化** → 手動ビルドで可
- **iOS/Android対応** → デスクトップのみ

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (新規設定)
- **User wants tests**: YES (TDD的アプローチ)
- **Framework**: 
  - MoonBit: `moon test`
  - C++: Catch2
  - JavaScript: Vitest

### Test Setup Tasks Included
- MoonBit: `moon.mod.json` に test 設定
- C++: Catch2 ヘッダー追加、CMake統合
- JS: Vitest + @vue/test-utils

### Manual Verification (Host Mac Required)
- DAWでのプラグイン読み込み
- オーディオ出力の聴覚確認
- GUI表示確認

---

## Task Flow

```
Phase 0: Environment & PoC
    └─ 0.1 → 0.2 → 0.3 → 0.4 → 0.5

Phase 1: DSP Foundation
    └─ 1.1 → 1.2 → 1.3 → 1.4

Phase 2: JUCE Plugin
    └─ 2.1 → 2.2 → 2.3 → 2.4

Phase 3: Web Version
    └─ 3.1 → 3.2

Phase 4: UI Integration
    └─ 4.1 → 4.2

※ Host Mac での動作確認は全タスク完了後にユーザーが実施 (末尾のビルド手順参照)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| - | None in Phase 0 | Sequential validation required |
| A | 3.1, 4.1 | Web setup and UI setup can parallel after 2.4 |

| Task | Depends On | Reason |
|------|------------|--------|
| 0.2 | 0.1 | Tools must be installed first |
| 0.3 | 0.2 | Need MoonBit to build WASM |
| 0.4 | 0.3 | Need WASM to AOT compile |
| 0.5 | 0.4 | Need AOT to test C++ integration |
| 1.x | 0.5 | Phase 0 must pass before DSP work |
| 2.x | 1.x | Need DSP module for plugin |
| 3.x | 1.x | Need DSP module for web |
| 4.1 | 3.1 | Need Vue project for UI components |
| 4.2 | 2.4, 4.1 | Need plugin tests pass and UI components |

---

## TODOs

### Phase 0: Environment & Proof of Concept

- [ ] 0.1. Docker環境セットアップ

  **What to do**:
  - 必要なパッケージをインストール:
    ```bash
    apt-get update && apt-get install -y \
      cmake pkg-config ninja-build gh \
      libasound2-dev libjack-jackd2-dev \
      libfreetype6-dev libx11-dev libxext-dev \
      libxinerama-dev libxrandr-dev libxcursor-dev \
      libgl1-mesa-dev libcurl4-openssl-dev \
      libwebkit2gtk-4.1-dev \
      wabt
    ```
  - MoonBitインストール:
    ```bash
    curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
    ```
  - MoonBitバージョン固定記録
  - Catch2ヘッダーダウンロード:
    ```bash
    mkdir -p tests/cpp/include
    curl -L -o tests/cpp/include/catch_amalgamated.hpp \
      https://github.com/catchorg/Catch2/releases/latest/download/catch_amalgamated.hpp
    ```

  **Must NOT do**:
  - Rustインストール (MoonBit使用)
  - 不要なパッケージ追加

  **Parallelizable**: NO (最初のタスク)

  **References**:
  - MoonBit公式インストール: https://www.moonbitlang.com/download
  - JUCE Linux依存: https://github.com/juce-framework/JUCE/blob/master/docs/Linux%20Dependencies.md
  - Catch2 single header: https://github.com/catchorg/Catch2/blob/devel/docs/migrate-v2-to-v3.md

  **Acceptance Criteria**:
  - [ ] `moon version` → バージョン表示
  - [ ] `cmake --version` → 3.22以上
  - [ ] `pkg-config --list-all | grep freetype` → freetype2表示
  - [ ] `wasm2wat --version` → バージョン表示
  - [ ] `ls tests/cpp/include/catch_amalgamated.hpp` → ファイル存在

  **Commit**: YES
  - Message: `chore: setup development environment`
  - Files: (system packages, no repo files yet)

---

- [ ] 0.2. プロジェクト構造作成

  **What to do**:
  - `/workspace/` 直下にディレクトリ構造作成:
    ```
    /workspace/
    ├── CMakeLists.txt           # Root CMake
    ├── package.json             # Root npm (workspaces + build scripts)
    ├── scripts/
    │   └── build-dsp.sh         # DSP build automation
    ├── dsp/                     # MoonBit DSP
    │   ├── moon.mod.json
    │   └── src/
    │       └── moon.pkg.json
    ├── plugin/                  # JUCE C++ Plugin
    │   ├── CMakeLists.txt
    │   ├── include/suna/
    │   ├── resources/           # AOT module destination
    │   └── src/
    ├── ui/                      # Vue 3 Frontend
    │   ├── package.json
    │   └── public/              # WASM module destination
    ├── libs/                    # External deps
    └── tests/                   # Integration tests
        └── cpp/
    ```
  - JUCE 8 を git submodule として追加 (`libs/juce`)
  - WAMR を git submodule として追加 (`libs/wamr`)
  - Root `package.json` にビルドスクリプト追加 (kodama準拠、ただしsuna用に調整):
    ```json
    {
      "name": "suna",
      "private": true,
      "workspaces": ["ui"],
      "scripts": {
        "setup:web": "npm install && npm run build:dsp",
        "setup:juce": "npm install && npm run build:dsp && cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build --config Debug",
        "dev:web": "npm run --prefix ui dev:web",
        "dev:juce": "npm run --prefix ui dev:juce",
        "build:dsp": "./scripts/build-dsp.sh",
        "release:web": "npm run build:dsp && npm run --prefix ui build:web && mkdir -p ui/dist-web/wasm ui/dist-web/worklet && cp ui/public/wasm/suna_dsp.wasm ui/dist-web/wasm/ && cp ui/public/worklet/processor.js ui/dist-web/worklet/",
        "release:vst": "npm run --prefix ui build && npm run build:dsp && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release"
      }
    }
    ```
    
    **注意**: kodamaとの違い:
    - kodama: JUCEはネイティブRust (.a) を使用、WASMは不要
    - suna: JUCEもWASM (WAMR AOT) を使用、`build:dsp`がJUCEビルドにも必要
    
  - `ui/package.json` にスクリプト追加:
    ```json
    {
      "scripts": {
        "dev:web": "VITE_RUNTIME=web vite",
        "dev:juce": "vite",
        "build:web": "VITE_RUNTIME=web vue-tsc -b && VITE_RUNTIME=web vite build --outDir dist-web",
        "build": "vue-tsc -b && vite build"
      }
    }
    ```
    
  - `scripts/build-dsp.sh` 作成:
    ```bash
    #!/bin/bash
    set -e
    
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    ROOT_DIR="$(dirname "$SCRIPT_DIR")"
    
    echo "==> Building MoonBit DSP..."
    cd "$ROOT_DIR/dsp"
    moon build --target wasm
    
    # Find the wasm output (path may vary by MoonBit version)
    WASM_FILE=$(find target/wasm -name "*.wasm" -type f | head -1)
    if [ -z "$WASM_FILE" ]; then
      echo "Error: No .wasm file found"
      exit 1
    fi
    echo "    Found: $WASM_FILE"
    
    echo "==> Copying WASM for web..."
    mkdir -p "$ROOT_DIR/ui/public/wasm"
    cp "$WASM_FILE" "$ROOT_DIR/ui/public/wasm/suna_dsp.wasm"
    
    echo "==> Compiling to AOT for JUCE..."
    WAMRC="$ROOT_DIR/libs/wamr/wamr-compiler/build/wamrc"
    if [ -f "$WAMRC" ]; then
      mkdir -p "$ROOT_DIR/plugin/resources"
      "$WAMRC" --opt-level=3 \
        -o "$ROOT_DIR/plugin/resources/suna_dsp.aot" \
        "$ROOT_DIR/ui/public/wasm/suna_dsp.wasm"
      echo "    AOT: plugin/resources/suna_dsp.aot"
    else
      echo "    Warning: wamrc not found, skipping AOT (run setup:juce first)"
    fi
    
    echo "==> DSP build complete!"
    echo "    WASM: ui/public/wasm/suna_dsp.wasm"
    ```

  **Must NOT do**:
  - サブディレクトリ (`suna/`) を切らない
  - JUCE/WAMR のソースを直接コピー (submodule使用)

  **Parallelizable**: NO (0.1依存)

  **References**:
  - kodama-vst構造: https://github.com/yuichkun/kodama-vst
  - JUCE repo: https://github.com/juce-framework/JUCE
  - WAMR repo: https://github.com/bytecodealliance/wasm-micro-runtime

  **Acceptance Criteria**:
  - [ ] `ls /workspace/dsp/` → `moon.mod.json`, `src/` 存在
  - [ ] `ls /workspace/libs/juce/` → JUCE ファイル存在
  - [ ] `ls /workspace/libs/wamr/` → WAMR ファイル存在
  - [ ] `git submodule status` → juce, wamr 表示
  - [ ] `cat package.json | grep setup:web` → スクリプト存在
  - [ ] `cat package.json | grep setup:juce` → スクリプト存在
  - [ ] `cat package.json | grep "dev:web"` → スクリプト存在
  - [ ] `cat package.json | grep "dev:juce"` → スクリプト存在
  - [ ] `ls scripts/build-dsp.sh && test -x scripts/build-dsp.sh` → 実行権限あり

  **Commit**: YES
  - Message: `chore: create project structure with JUCE and WAMR submodules`
  - Files: `CMakeLists.txt`, `package.json`, `scripts/build-dsp.sh`, `dsp/`, `plugin/`, `ui/`, `libs/`, `tests/`, `.gitmodules`

---

- [ ] 0.3. MoonBit最小WASMビルド検証

  **What to do**:
  - `dsp/moon.mod.json` 作成
  - `dsp/src/moon.pkg.json` にWASM export設定:
    ```json
    {
      "is-main": true,
      "link": {
        "wasm": {
          "exports": ["multiply", "add"],
          "heap-start-address": 65536,
          "export-memory-name": "memory"
        }
      }
    }
    ```
  - `dsp/src/lib.mbt` に最小関数:
    ```moonbit
    pub fn multiply(a : Float, b : Float) -> Float {
      a * b
    }
    
    pub fn add(a : Float, b : Float) -> Float {
      a + b
    }
    ```
  - `moon build --target wasm` 実行
  - `wasm2wat` で出力確認 (exports存在確認)

  **Must NOT do**:
  - `--target wasm-gc` 使用 (WAMR非対応)
  - 複雑なDSPロジック (検証用最小コード)

  **Parallelizable**: NO (0.2依存)

  **References**:
  - MoonBit WASM docs: https://docs.moonbitlang.com/
  - MoonBit FFI: https://docs.moonbitlang.com/language/ffi.html

  **Acceptance Criteria**:
  - [ ] `moon build --target wasm` → 成功 (exit 0)
  - [ ] `ls target/wasm/release/build/` → `.wasm` ファイル存在
  - [ ] `wasm2wat [file].wasm | grep "export"` → `multiply`, `add` 表示
  - [ ] `moon test` → pass (基本テスト)

  **Commit**: YES
  - Message: `feat(dsp): add minimal MoonBit WASM build`
  - Files: `dsp/moon.mod.json`, `dsp/src/moon.pkg.json`, `dsp/src/lib.mbt`
  - Pre-commit: `moon build --target wasm && moon test`

---

- [ ] 0.4. WAMR AOTコンパイル検証

  **What to do**:
  - WAMRのwamrcをビルド:
    ```bash
    cd libs/wamr/wamr-compiler
    mkdir build && cd build
    cmake ..
    make
    ```
  - MoonBit WASMをAOTコンパイル:
    ```bash
    ./wamrc --opt-level=3 -o dsp.aot ../../../target/wasm/release/build/gen/gen.wasm
    ```
  - AOTファイルサイズ確認 (数KB程度を期待)

  **Must NOT do**:
  - JITモード使用 (リアルタイムオーディオ不適)
  - 最適化レベル下げる (--opt-level=3必須)

  **Parallelizable**: NO (0.3依存)

  **References**:
  - WAMR AOT docs: https://github.com/bytecodealliance/wasm-micro-runtime/blob/main/doc/build_wamr.md
  - wamrc usage: https://github.com/bytecodealliance/wasm-micro-runtime/blob/main/wamr-compiler/README.md

  **Acceptance Criteria**:
  - [ ] `./wamrc --version` → バージョン表示
  - [ ] `./wamrc ... -o dsp.aot ...` → 成功 (exit 0)
  - [ ] `ls dsp.aot` → ファイル存在
  - [ ] `file dsp.aot` → ELF/Mach-O (プラットフォーム依存)

  **Commit**: YES
  - Message: `chore: verify WAMR AOT compilation pipeline`
  - Files: (ビルド成果物、gitignore対象)

---

- [ ] 0.5. C++ ↔ WASM統合PoC (状態永続性検証含む)

  **What to do**:
  - MoonBit側に状態保持テスト関数追加 (`dsp/src/lib.mbt`):
    ```moonbit
    // グローバル状態 (linear memory内)
    let mut counter : Int = 0
    
    pub fn increment() -> Int {
      counter = counter + 1
      counter
    }
    
    pub fn get_counter() -> Int {
      counter
    }
    ```
  - `tests/cpp/wasm_poc.cpp` 作成:
    - WAMRランタイム初期化 (`Alloc_With_Pool`)
    - AOTモジュール読み込み
    - `multiply(2.0, 3.0)` 呼び出し → `6.0` 検証
    - **状態永続性テスト**: 
      - `increment()` 3回呼び出し
      - `get_counter()` が `3` を返すことを検証
      - (GCによる状態移動がないことを確認)
  - `tests/cpp/CMakeLists.txt` 作成 (WAMR vmlib リンク)
  - Catch2 でテスト実行

  **Must NOT do**:
  - JUCEとの統合 (純粋なWAMR検証)
  - 複雑なバッファ操作 (単純な関数呼び出しのみ)

  **Parallelizable**: NO (0.4依存)

  **References**:
  - WAMR basic sample: https://github.com/bytecodealliance/wasm-micro-runtime/blob/main/samples/basic/src/main.c
  - WAMR C API: https://github.com/bytecodealliance/wasm-micro-runtime/blob/main/core/iwasm/include/wasm_export.h
  - Catch2: https://github.com/catchorg/Catch2

  **Acceptance Criteria**:
  - [ ] `cmake --build tests/cpp/build` → 成功
  - [ ] `./wasm_poc_test` → `multiply(2.0, 3.0) = 6.0` 出力
  - [ ] **状態永続性テスト**: `increment()` x3 → `get_counter()` = 3
  - [ ] Catch2 test → ALL PASSED
  
  **CRITICAL**: このタスクが失敗した場合、MoonBitの状態管理設計を再検討する必要あり。Phase 1に進む前に必ず解決すること。

  **Commit**: YES
  - Message: `test: verify MoonBit WASM ↔ C++ integration via WAMR`
  - Files: `tests/cpp/wasm_poc.cpp`, `tests/cpp/CMakeLists.txt`
  - Pre-commit: `ctest`

---

### Phase 1: DSP Foundation

- [ ] 1.1. MoonBit Delay DSP実装

  **What to do**:
  - グローバル状態をプリミティブ型で管理 (GC影響を最小化):
    ```moonbit
    // グローバル状態 (モジュールレベル、linear memory内)
    let delay_buffer : FixedArray[Float] = FixedArray::make(96000 * 2, 0.0) // max 2sec @ 48kHz
    let mut write_pos : Int = 0
    let mut sample_rate : Float = 44100.0
    let mut delay_samples : Int = 0
    let mut feedback : Float = 0.3
    let mut mix : Float = 0.5
    ```
  - Delay処理関数実装:
    - `init_delay(sr: Float, max_delay_ms: Float) -> Int` (初期化、0=success)
    - `set_delay_time(ms: Float)` (グローバル状態更新)
    - `set_feedback(value: Float)`
    - `set_mix(value: Float)`
    - `process_sample(input: Float) -> Float`
  - `moon.pkg.json` にexports追加
  - 単体テスト作成 (`moon test`)
  
  **Design Note**: MoonBitには`#valtype`アノテーションは存在しない。代わりにグローバル変数とFixedArrayを使用し、状態をlinear memoryに保持。これによりGCの影響を最小化。

  **Must NOT do**:
  - Multi-tap/Voices実装
  - モジュレーション/LFO
  - `Array`型使用 (`FixedArray`のみ)
  - 処理中のメモリ割り当て
  - 複数インスタンス対応 (単一グローバル状態で十分)

  **Parallelizable**: NO (Phase 0完了後)

  **References**:
  - kodama delay.rs: https://github.com/yuichkun/kodama-vst/blob/main/dsp/src/delay.rs
  - MoonBit language basics: https://docs.moonbitlang.com/language/fundamentals.html

  **Acceptance Criteria**:
  - [ ] `moon build --target wasm` → 成功
  - [ ] `moon test` → Delayテスト pass
  - [ ] exports: `init_delay`, `set_delay_time`, `set_feedback`, `set_mix`, `process_sample`
  - [ ] `wasm2wat` で関数signature確認

  **Commit**: YES
  - Message: `feat(dsp): implement single-tap delay in MoonBit`
  - Files: `dsp/src/delay.mbt`, `dsp/src/lib.mbt`, `dsp/src/moon.pkg.json`
  - Pre-commit: `moon test && moon build --target wasm`

---

- [ ] 1.2. ステレオバッファ処理実装

  **What to do**:
  - バッファポインタ受け渡し用関数:
    ```moonbit
    pub fn process_block(
      state_ptr : Int,
      left_in_ptr : Int,
      right_in_ptr : Int,
      left_out_ptr : Int,
      right_out_ptr : Int,
      num_samples : Int
    ) -> Int
    ```
  - WASM linear memory経由でのバッファアクセス
  - インプレース処理対応 (in_ptr == out_ptr)

  **Must NOT do**:
  - チャンネル数可変対応 (ステレオ固定)
  - SIMDオプティマイズ

  **Parallelizable**: NO (1.1依存)

  **References**:
  - kodama ffi.rs process: https://github.com/yuichkun/kodama-vst/blob/main/dsp/src/ffi.rs#L74-L100
  - MoonBit FFI: https://docs.moonbitlang.com/language/ffi.html

  **Acceptance Criteria**:
  - [ ] `moon test` → バッファ処理テスト pass
  - [ ] export: `process_block`
  - [ ] 入力バッファ → Delay処理 → 出力バッファ の流れ確認

  **Commit**: YES
  - Message: `feat(dsp): add stereo buffer processing`
  - Files: `dsp/src/buffer.mbt`
  - Pre-commit: `moon test`

---

- [ ] 1.3. WASM AOT再ビルド (DSP完全版)

  **What to do**:
  - `npm run build:dsp` 実行 (0.2で作成したスクリプト)
  - ファイルサイズ確認 (数十KB以下を期待)
  - exportsの確認

  **Must NOT do**:
  - 手動でコマンド実行 (スクリプト使用)
  - デバッグビルド使用

  **Parallelizable**: NO (1.2依存)

  **References**:
  - 0.4と同じ
  - `scripts/build-dsp.sh`

  **Acceptance Criteria**:
  - [ ] `npm run build:dsp` → 成功 (exit 0)
  - [ ] `ls plugin/resources/suna_dsp.aot` → ファイル存在
  - [ ] `ls ui/public/suna_dsp.wasm` → ファイル存在
  - [ ] AOTファイルサイズ < 100KB
  - [ ] `wasm2wat ui/public/suna_dsp.wasm | grep export` → 全関数表示

  **Commit**: YES
  - Message: `build: compile DSP to AOT module`
  - Files: `plugin/resources/suna_dsp.aot`, `ui/public/suna_dsp.wasm`

---

- [ ] 1.4. C++ DSPラッパークラス作成

  **What to do**:
  - `plugin/include/suna/WasmDSP.h`:
    ```cpp
    class WasmDSP {
    public:
        bool initialize(const uint8_t* aotData, size_t size);
        void prepareToPlay(double sampleRate, int maxBlockSize);
        void processBlock(float* leftIn, float* rightIn, 
                         float* leftOut, float* rightOut, int numSamples);
        void setDelayTime(float ms);
        void setFeedback(float value);
        void setMix(float value);
    private:
        wasm_module_t module;
        wasm_module_inst_t moduleInst;
        wasm_exec_env_t execEnv;
        // Pre-allocated buffer offsets
        uint32_t leftInOffset, rightInOffset, leftOutOffset, rightOutOffset;
        float* nativeLeftIn, *nativeRightIn, *nativeLeftOut, *nativeRightOut;
    };
    ```
  - `plugin/src/WasmDSP.cpp` 実装
  - Catch2 テスト追加

  **Must NOT do**:
  - JUCEとの結合 (純粋なWAMRラッパー)
  - processBlock内でのmalloc

  **Parallelizable**: NO (1.3依存)

  **References**:
  - WAMR API: https://github.com/bytecodealliance/wasm-micro-runtime/blob/main/core/iwasm/include/wasm_export.h
  - 0.5のPoCコード

  **Acceptance Criteria**:
  - [ ] `WasmDSP` クラスコンパイル成功
  - [ ] Catch2テスト: initialize → prepareToPlay → processBlock → 出力確認
  - [ ] メモリリーク無し (valgrind/AddressSanitizer)

  **Commit**: YES
  - Message: `feat(plugin): add WasmDSP wrapper class`
  - Files: `plugin/include/suna/WasmDSP.h`, `plugin/src/WasmDSP.cpp`, `tests/cpp/wasm_dsp_test.cpp`
  - Pre-commit: `ctest`

---

### Phase 2: JUCE Plugin

- [ ] 2.1. JUCE プラグイン基本構造

  **What to do**:
  - `plugin/CMakeLists.txt` 設定:
    ```cmake
    juce_add_plugin(Suna
        FORMATS AU VST3 Standalone
        PLUGIN_MANUFACTURER_CODE Suna
        PLUGIN_CODE Suna
        PRODUCT_NAME "Suna"
    )
    ```
  - `PluginProcessor.h/cpp` 作成 (AudioProcessor継承)
  - `PluginEditor.h/cpp` 作成 (空のエディタ)
  - WAMR vmlib リンク設定
  - AOTファイルをBinaryDataとして埋め込み

  **Must NOT do**:
  - UI実装 (後回し)
  - パラメータ実装 (次タスク)

  **Parallelizable**: NO (Phase 1完了後)

  **References**:
  - kodama plugin/CMakeLists.txt: https://github.com/yuichkun/kodama-vst/blob/main/plugin/CMakeLists.txt
  - JUCE CMake API: https://github.com/juce-framework/JUCE/blob/master/docs/CMake%20API.md

  **Acceptance Criteria**:
  - [ ] `cmake --build` → プラグインビルド成功
  - [ ] Standalone起動 → クラッシュ無し
  - [ ] `file Suna.vst3/Contents/*/Suna` → 有効なバイナリ

  **Commit**: YES
  - Message: `feat(plugin): add JUCE plugin skeleton`
  - Files: `plugin/CMakeLists.txt`, `plugin/src/PluginProcessor.*`, `plugin/src/PluginEditor.*`

---

- [ ] 2.2. AudioProcessorValueTreeState設定

  **What to do**:
  - パラメータ定義:
    | ID | Name | Range | Default |
    |----|------|-------|---------|
    | delayTime | Delay Time | 0-2000ms | 300ms |
    | feedback | Feedback | 0-100% | 30% |
    | mix | Mix | 0-100% | 50% |
  - `createParameterLayout()` 実装
  - Atomic parameter pointers取得

  **Must NOT do**:
  - UI連携 (後回し)
  - 状態保存/復元

  **Parallelizable**: NO (2.1依存)

  **References**:
  - kodama PluginProcessor.cpp: https://github.com/yuichkun/kodama-vst/blob/main/plugin/src/PluginProcessor.cpp#L29-L60
  - JUCE APVTS: https://docs.juce.com/master/classAudioProcessorValueTreeState.html

  **Acceptance Criteria**:
  - [ ] パラメータが自動的に公開される
  - [ ] DAWでオートメーション可能

  **Commit**: YES
  - Message: `feat(plugin): add audio parameters`
  - Files: `plugin/src/PluginProcessor.cpp`

---

- [ ] 2.3. processBlock実装

  **What to do**:
  - `prepareToPlay()`:
    - WasmDSP初期化
    - サンプルレート設定
    - バッファ事前確保
  - `processBlock()`:
    - パラメータ読み取り (atomic)
    - WasmDSP にパラメータ設定
    - WasmDSP.processBlock() 呼び出し
  - `releaseResources()`:
    - WasmDSP クリーンアップ

  **Must NOT do**:
  - processBlock内でのメモリ割り当て
  - ブロッキング操作

  **Parallelizable**: NO (2.2依存)

  **References**:
  - kodama processBlock: https://github.com/yuichkun/kodama-vst/blob/main/plugin/src/PluginProcessor.cpp#L122-L141

  **Acceptance Criteria**:
  - [ ] Standalone: オーディオ入力 → Delay処理 → 出力
  - [ ] 256サンプルバッファで glitch 無し
  - [ ] パラメータ変更がリアルタイム反映

  **Commit**: YES
  - Message: `feat(plugin): implement audio processing with WASM DSP`
  - Files: `plugin/src/PluginProcessor.cpp`

---

- [ ] 2.4. Catch2 プラグインテスト

  **What to do**:
  - `tests/cpp/plugin_test.cpp`:
    - PluginProcessor インスタンス化テスト
    - processBlock スモークテスト (無音入力 → 無音出力)
    - パラメータ変更テスト

  **Must NOT do**:
  - DAW統合テスト (手動確認)

  **Parallelizable**: NO (2.3依存)

  **References**:
  - Catch2 with JUCE: https://github.com/catchorg/Catch2/blob/devel/docs/cmake-integration.md

  **Acceptance Criteria**:
  - [ ] `ctest` → 全テスト pass
  - [ ] カバレッジ: PluginProcessor主要メソッド

  **Commit**: YES
  - Message: `test(plugin): add Catch2 plugin tests`
  - Files: `tests/cpp/plugin_test.cpp`
  - Pre-commit: `ctest`

---

### Phase 3: Web Version

- [ ] 3.1. Web プロジェクト構造作成

  **What to do**:
  - `ui/package.json` (Vue 3 + Vite + Vitest) with scripts:
    - `dev:web`: `VITE_RUNTIME=web vite`
    - `dev:juce`: `vite`
    - `build:web`: `VITE_RUNTIME=web vue-tsc -b && VITE_RUNTIME=web vite build --outDir dist-web`
    - `build`: `vue-tsc -b && vite build` (single-file for JUCE embed)
    - `test`: `vitest`
  - `ui/vite.config.ts`:
    - `vite-plugin-singlefile` 有効化 (JUCE用)
    - `VITE_RUNTIME` 環境変数で分岐
  - `ui/tsconfig.json`
  - `ui/public/worklet/` ディレクトリ
  - `ui/public/wasm/` ディレクトリ (DSPビルド出力先)
  - kodama UI構造を参考にディレクトリ作成

  **Must NOT do**:
  - 複雑なUI実装

  **Parallelizable**: YES (2.4完了後)

  **References**:
  - kodama ui/package.json: https://github.com/yuichkun/kodama-vst/blob/main/ui/package.json
  - kodama ui/vite.config.ts: https://github.com/yuichkun/kodama-vst/blob/main/ui/vite.config.ts
  - Vite: https://vitejs.dev/
  - vite-plugin-singlefile: https://github.com/nickolanack/vite-plugin-singlefile

  **Acceptance Criteria**:
  - [ ] `cd ui && npm install` → 成功
  - [ ] `npm run dev:web` → Vite dev server 起動 (VITE_RUNTIME=web)
  - [ ] `npm run dev:juce` → Vite dev server 起動 (default)
  - [ ] `npm test` → Vitest 実行 (空テスト pass)
  - [ ] `cat ui/package.json | grep "dev:web"` → スクリプト存在

  **Commit**: YES
  - Message: `feat(ui): setup Vue 3 + Vite project with web/juce modes`
  - Files: `ui/package.json`, `ui/vite.config.ts`, `ui/tsconfig.json`

---

- [ ] 3.2. AudioWorklet DSP統合

  **What to do**:
  - WASM は `npm run build:dsp` で自動コピー済み (`ui/public/suna_dsp.wasm`)
  - `ui/public/worklet/processor.js`:
    - WASM モジュール読み込み
    - linear memory バッファ確保
    - `process()` でDSP呼び出し
  - `ui/src/runtime/WebRuntime.ts`:
    - AudioWorkletNode 作成
    - パラメータ送信 (postMessage)
  - `ui/src/runtime/types.ts`: Runtime interface 定義

  **Must NOT do**:
  - AOT使用 (ブラウザはWASM直接実行)

  **Parallelizable**: NO (3.1依存)

  **References**:
  - kodama processor.js: https://github.com/yuichkun/kodama-vst/blob/main/ui/public/worklet/processor.js
  - kodama WebRuntime.ts: https://github.com/yuichkun/kodama-vst/blob/main/ui/src/runtime/WebRuntime.ts

  **Acceptance Criteria** (Docker内で検証可能):
  - [ ] `npm run build -w ui` → 成功 (TypeScriptコンパイルエラーなし)
  - [ ] `ls ui/public/suna_dsp.wasm` → WASMファイル存在 (1.3で生成済み)
  - [ ] `ui/public/worklet/processor.js` にWASM読み込みコード存在
  - [ ] `ui/src/runtime/WebRuntime.ts` にAudioWorklet初期化コード存在
  - [ ] `grep "suna_dsp.wasm" ui/public/worklet/processor.js` → 参照あり

  **Commit**: YES
  - Message: `feat(ui): implement AudioWorklet with MoonBit WASM`
  - Files: `ui/public/worklet/processor.js`, `ui/src/runtime/WebRuntime.ts`, `ui/src/runtime/types.ts`

---

### Phase 4: UI Integration

- [ ] 4.1. Vue UIコンポーネント作成

  **What to do**:
  - `ui/src/components/SliderControl.vue`:
    - 汎用スライダーコンポーネント
    - min/max/value props
  - `ui/src/App.vue`:
    - Delay Time, Feedback, Mix スライダー
    - Runtime選択 (Web/JUCE自動検出)
  - Vitest テスト

  **Must NOT do**:
  - カスタムノブグラフィック
  - 波形表示
  - プリセット

  **Parallelizable**: YES (3.2, 2.3完了後)

  **References**:
  - kodama KnobControl.vue: https://github.com/yuichkun/kodama-vst/blob/main/ui/src/components/KnobControl.vue
  - kodama App.vue: https://github.com/yuichkun/kodama-vst/blob/main/ui/src/App.vue

  **Acceptance Criteria**:
  - [ ] スライダー3つ表示
  - [ ] Vitest テスト pass
  - [ ] スライダー操作でruntime.setParameter呼び出し

  **Commit**: YES
  - Message: `feat(ui): add parameter slider components`
  - Files: `ui/src/components/SliderControl.vue`, `ui/src/App.vue`
  - Pre-commit: `npm run test`

---

- [ ] 4.2. JUCE WebBrowserComponent統合

  **What to do**:
  - Vue UIビルド: `cd ui && npm run build`
  - `plugin/CMakeLists.txt` にBinaryData設定追加 (ui/dist/埋め込み)
  - `PluginEditor` に WebBrowserComponent 追加
  - WebSliderRelay でパラメータバインド (delayTime, feedback, mix)
  - 開発時は localhost:5173 参照 (HMR)、リリース時はBinaryData参照

  **Must NOT do**:
  - カスタムNative Function

  **Parallelizable**: NO (4.1依存)

  **References**:
  - kodama PluginEditor.cpp: https://github.com/yuichkun/kodama-vst/blob/main/plugin/src/PluginEditor.cpp
  - JUCE WebBrowserComponent: https://docs.juce.com/master/classWebBrowserComponent.html

  **Acceptance Criteria** (Docker内で検証可能):
  - [ ] `cmake --build build` → プラグイン再ビルド成功
  - [ ] BinaryData にUI埋め込み確認: `nm` or `strings` でHTML存在確認
  - [ ] WebSliderRelay 3つ (delayTime, feedback, mix) が PluginEditor.cpp に存在
  - [ ] `#if JUCE_DEBUG` で開発モード分岐存在

  **Commit**: YES
  - Message: `feat(plugin): integrate WebBrowserComponent with Vue UI`
  - Files: `plugin/src/PluginEditor.cpp`, `plugin/src/PluginEditor.h`, `plugin/CMakeLists.txt`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 0.1 | `chore: setup development environment` | (system) | `moon version` |
| 0.2 | `chore: create project structure with JUCE and WAMR submodules` | structure | `git submodule status` |
| 0.3 | `feat(dsp): add minimal MoonBit WASM build` | dsp/ | `moon build && moon test` |
| 0.4 | `chore: verify WAMR AOT compilation pipeline` | (build artifacts) | `wamrc` success |
| 0.5 | `test: verify MoonBit WASM ↔ C++ integration via WAMR` | tests/cpp/ | `ctest` |
| 1.1 | `feat(dsp): implement single-tap delay in MoonBit` | dsp/ | `moon test` |
| 1.2 | `feat(dsp): add stereo buffer processing` | dsp/ | `moon test` |
| 1.3 | `build: compile DSP to AOT module` | plugin/resources/ | file exists |
| 1.4 | `feat(plugin): add WasmDSP wrapper class` | plugin/ | `ctest` |
| 2.1 | `feat(plugin): add JUCE plugin skeleton` | plugin/ | build success |
| 2.2 | `feat(plugin): add audio parameters` | plugin/ | build success |
| 2.3 | `feat(plugin): implement audio processing with WASM DSP` | plugin/ | build success |
| 2.4 | `test(plugin): add Catch2 plugin tests` | tests/cpp/ | `ctest` |
| 3.1 | `feat(ui): setup Vue 3 + Vite project` | ui/ | `npm install` |
| 3.2 | `feat(ui): implement AudioWorklet with MoonBit WASM` | ui/ | `npm run build` |
| 4.1 | `feat(ui): add parameter slider components` | ui/ | `npm test` |
| 4.2 | `feat(plugin): integrate WebBrowserComponent with Vue UI` | plugin/ | build success |

---

## Success Criteria (Docker環境内で完結)

### Verification Commands
```bash
# MoonBit DSP tests
cd dsp && moon test           # Expected: All tests passed

# DSP build (WASM + AOT)
npm run build:dsp             # Expected: ui/public/wasm/suna_dsp.wasm + plugin/resources/suna_dsp.aot

# C++ tests
cd build && ctest             # Expected: 100% tests passed

# JS tests
npm test                      # Expected: All tests passed (runs ui tests)

# Full JUCE setup & build
npm run setup:juce            # Expected: Suna.vst3, Suna.component created

# Full Web release
npm run release:web           # Expected: ui/dist-web/ with all assets
```

### Final Checklist (Docker内完結)
- [ ] MoonBit DSP: Delay実装、テスト pass
- [ ] WASM: 正常生成、AOTコンパイル成功
- [ ] WAMR統合: C++から呼び出し可能、状態永続性確認
- [ ] プラグインビルド: VST3/AU/Standalone 生成成功
- [ ] Web UI ビルド: dist/ 生成成功
- [ ] テスト: `moon test`, `ctest`, `npm test` 全pass
- [ ] **Must NOT Have** 項目全て除外されている

---

## Host Mac 動作確認ガイド (タスク完了後、ユーザーが実施)

> 以下はDocker環境でのタスク完了後、Host Macで手動確認する際の手順です。
> これらはプラン内のタスクではありません。

### プラグインのコピー

```bash
# Docker内のビルド成果物をHost Macにコピー
# (Docker環境の設定によってパスは異なる)

# VST3
cp -r build/plugin/Suna_artefacts/VST3/Suna.vst3 ~/Library/Audio/Plug-Ins/VST3/

# AU (macOS only - Docker内でビルドした場合はクロスコンパイル設定が必要)
cp -r build/plugin/Suna_artefacts/AU/Suna.component ~/Library/Audio/Plug-Ins/Components/

# Standalone
# build/plugin/Suna_artefacts/Standalone/Suna.app
```

### DAWでの確認

1. **Reaper** (推奨 - 最も寛容):
   - Preferences → Plug-ins → VST → Add path
   - Rescan
   - Insert → FX → Suna

2. **Logic Pro**:
   - AU バージョンを使用
   - Logic起動時に自動スキャン
   - Track → Plug-ins → Audio Units → Suna

3. **Ableton Live**:
   - Preferences → Plug-ins → VST3 folder
   - Rescan
   - Browser → Plug-ins → Suna

### Web版の確認

```bash
# Docker内で開発サーバー起動 (ポートフォワード設定済みの場合)
npm run dev:web

# Host Macのブラウザで:
# http://localhost:5173
```

または:

```bash
# ビルド済みファイルを静的サーバーで配信
npm run release:web
npx serve ui/dist-web

# http://localhost:3000
```

### 確認項目

- [ ] VST3: DAWで読み込み成功、オーディオ処理動作
- [ ] AU: Logic/GarageBandで読み込み成功 (macOS)
- [ ] Standalone: アプリ起動、オーディオ入出力動作
- [ ] Web: ブラウザでDelay効果確認
- [ ] UI: スライダー操作でパラメータ変更反映
- [ ] パラメータオートメーション動作 (DAW)

### トラブルシューティング

**VST3が読み込まれない場合**:
```bash
# プラグインの検証
pluginval --validate Suna.vst3
```

**AUが認識されない場合**:
```bash
# AUキャッシュクリア
killall -9 AudioComponentRegistrar
```

**Web版でWASMロードエラー**:
- ブラウザのコンソールでCORSエラー確認
- `npm run dev` でViteの開発サーバー使用推奨

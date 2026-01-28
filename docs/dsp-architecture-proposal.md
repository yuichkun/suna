# DSP Architecture Refactoring Proposal

## 現状の問題点

### 1. MoonBitコードの冗長性

[`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt) で8スロット分の変数が個別に宣言されている:

```rust
// 8個の個別バッファ (各1,440,000サンプル = 5.76MB)
let sample_buffer_0 : FixedArray[Float] = FixedArray::make(1440000, 0.0)
let sample_buffer_1 : FixedArray[Float] = FixedArray::make(1440000, 0.0)
// ... 6個続く

// 8個の長さRef, 再生位置Ref, 再生フラグRef も同様
```

[`dsp/src/blend.mbt`](../dsp/src/blend.mbt) も同様に `gain_0` ~ `gain_7` が個別宣言。

### 2. 意味のない定数

```rust
const MAX_SAMPLES : Int = 8  // ← この定数を変えても何も変わらない
```

### 3. 二重コピー・二重メモリ問題 (最重要)

同じサンプルデータが **Linear Memory** と **MoonBit Heap** の2箇所に存在:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          WASM Linear Memory                             │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ 0x00000 - 0x0FFFF: MoonBit Stack (64KB)                          │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 0x10000 - ...: MoonBit Heap                                      │  │
│  │   ┌────────────────────────────────────────────────────────┐     │  │
│  │   │ sample_buffer_0 ~ sample_buffer_7                      │     │  │
│  │   │ 合計: 46MB (MoonBit FixedArray)                        │     │  │
│  │   └────────────────────────────────────────────────────────┘     │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 0xDBC9F (900000): Audio I/O Buffers                              │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 0xF4240 (1000000): SAMPLE_DATA_START                             │  │
│  │   ┌────────────────────────────────────────────────────────┐     │  │
│  │   │ Slot 0 ~ Slot 7                                        │     │  │
│  │   │ 合計: 46MB (Host書き込み領域)                          │     │  │
│  │   └────────────────────────────────────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  合計メモリ使用量: 約92MB (同じデータが2箇所に存在)                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 現状のコード配置

### Host側 (C++ / JUCE Plugin)

| ファイル | 行 | 内容 |
|----------|-----|------|
| [`plugin/include/suna/WasmDSP.h`](../plugin/include/suna/WasmDSP.h#L90) | L90 | `SAMPLE_DATA_START = 1000000` 定数定義 |
| [`plugin/src/WasmDSP.cpp`](../plugin/src/WasmDSP.cpp#L346) | L346-363 | `loadSample()` - Linear Memoryに書き込み + WASM呼び出し |
| [`plugin/src/WasmDSP.cpp`](../plugin/src/WasmDSP.cpp#L187) | L187 | `nativeSampleData_` ポインタ初期化 |
| [`plugin/src/WasmDSP.cpp`](../plugin/src/WasmDSP.cpp#L349) | L349 | `MAX_SAMPLES_PER_SLOT = 1440000` |

```cpp
// plugin/src/WasmDSP.cpp L346-363
void WasmDSP::loadSample(int slot, const float* data, int length) {
    constexpr int MAX_SAMPLES_PER_SLOT = 1440000;
    uint32_t slotOffset = static_cast<uint32_t>(slot) * MAX_SAMPLES_PER_SLOT;
    
    // ① Linear Memoryにコピー
    std::memcpy(nativeSampleData_ + slotOffset, data, copyLength * sizeof(float));

    // ② MoonBitのload_sample呼び出し (→ MoonBitが再度コピー)
    uint32_t dataPtr = SAMPLE_DATA_START + slotOffset * sizeof(float);
    wasm_runtime_call_wasm_a(execEnv_, loadSampleFunc_, ...);
}
```

### Host側 (JS / Web AudioWorklet)

| ファイル | 行 | 内容 |
|----------|-----|------|
| [`ui/public/worklet/processor.js`](../ui/public/worklet/processor.js#L60) | L60-61 | `SAMPLE_DATA_START`, `MAX_SAMPLES_PER_SLOT` 定数 |
| [`ui/public/worklet/processor.js`](../ui/public/worklet/processor.js#L57) | L57-72 | `handleLoadSample()` - Linear Memoryに書き込み + WASM呼び出し |

```javascript
// ui/public/worklet/processor.js L57-72
handleLoadSample(slot, pcmData, sampleRate) {
    const SAMPLE_DATA_START = 1000000;
    const MAX_SAMPLES_PER_SLOT = 1440000;
    const slotOffset = SAMPLE_DATA_START + (slot * MAX_SAMPLES_PER_SLOT * BYTES_PER_FLOAT);
    
    // ① Linear Memoryにコピー
    const sampleView = new Float32Array(memory.buffer, slotOffset, numSamples);
    sampleView.set(pcmData.subarray(0, numSamples));
    
    // ② MoonBitのload_sample呼び出し (→ MoonBitが再度コピー)
    this.wasm.load_sample(slot, slotOffset, numSamples);
}
```

### MoonBit側 (DSP)

| ファイル | 行 | 内容 |
|----------|-----|------|
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt#L6) | L6 | `MAX_SAMPLES = 8` (意味なし) |
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt#L9) | L9 | `MAX_SAMPLE_LENGTH = 1440000` |
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt#L13) | L13-34 | `sample_buffer_0` ~ `sample_buffer_7` (46MB確保) |
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt#L38) | L38-59 | `sample_length_0` ~ `sample_length_7` |
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt#L63) | L63-84 | `play_pos_0` ~ `play_pos_7` |
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt#L88) | L88-109 | `playing_0` ~ `playing_7` |
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt#L117) | L117-128 | `get_sample_buffer()` - ハードコードされたmatch |
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt#L205) | L205-232 | `load_sample()` - Linear Memoryから自前バッファにコピー |
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt#L305) | L305-331 | `process_sampler_stereo()` - 自前バッファから読み取り |
| [`dsp/src/blend.mbt`](../dsp/src/blend.mbt#L53) | L53-74 | `gain_0` ~ `gain_7` |

```rust
// dsp/src/sampler.mbt L205-232
pub fn load_sample(slot : Int, data_ptr : Int, length : Int) -> Int {
    let buffer = get_sample_buffer(slot)
    // Linear Memoryから自前のFixedArrayにコピー (二重コピーの原因)
    for i = 0; i < length; i = i + 1 {
        buffer[i] = sampler_load_f32(data_ptr + i * 4)
    }
}
```

---

## 現状のデータフロー

```
┌─────────────┐    ① memcpy /     ┌─────────────────────────┐
│ Host        │    Float32Array   │ Linear Memory           │
│ (C++ / JS)  │ ────────────────→ │ @ SAMPLE_DATA_START     │
│ PCMデータ   │                   │ (46MB固定確保)          │
└─────────────┘                   └───────────┬─────────────┘
                                              │
                                              │ ② sampler_load_f32()
                                              │   (forループでコピー)
                                              ▼
                                  ┌─────────────────────────┐
                                  │ MoonBit FixedArray      │
                                  │ sample_buffer_N         │
                                  │ (46MB固定確保)          │
                                  └─────────────────────────┘

問題: 同じデータが2回コピーされ、2箇所に保存される (計92MB)
```

---

## 提案: Option A - 直接読み取り方式

### 概要

MoonBitはバッファを持たず、再生時にLinear Memoryから直接読む。

### 変更後のメモリレイアウト

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          WASM Linear Memory                             │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ 0x00000 - 0x0FFFF: MoonBit Stack                                 │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 0x10000 - ...: MoonBit Heap (最小限のメタデータのみ)            │  │
│  │   ┌──────────────────────────────────────────────┐               │  │
│  │   │ slots: FixedArray[SlotMeta]                  │ ← ポインタ+  │  │
│  │   │   - data_ptr, length, play_pos, playing, ... │   メタデータ │  │
│  │   │ (数百バイト程度)                              │   のみ       │  │
│  │   └──────────────────────────────────────────────┘               │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 0xF4240 (1000000): SAMPLE_DATA_START                             │  │
│  │   ┌────────────────────────────────────────────────────────┐     │  │
│  │   │ Slot 0 ~ Slot 7 (Host管理、MoonBitは参照のみ)          │     │  │
│  │   └────────────────────────────────────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  メモリ使用量: 46MB (Host側のみ) ← 半減!                               │
└─────────────────────────────────────────────────────────────────────────┘
```

### 変更後のデータフロー

```
loadSample:
┌─────────────┐    ① memcpy /     ┌─────────────────────────┐
│ Host        │    Float32Array   │ Linear Memory           │
│ (C++ / JS)  │ ────────────────→ │ @ SAMPLE_DATA_START     │ ← 1箇所のみ
└─────────────┘                   └───────────┬─────────────┘
                                              │
                                              │ ② ポインタと長さを記録
                                              ▼
                                  ┌─────────────────────────┐
                                  │ MoonBit SlotMeta        │
                                  │ { data_ptr, length, ... }│
                                  └─────────────────────────┘

processBlock:
┌─────────────────────────────────┐
│ Linear Memory                   │
│ @ SAMPLE_DATA_START + slot * .. │ ←─── ③ 再生時に直接読む (sampler_load_f32)
└─────────────────────────────────┘
```

### 変更が必要なファイル

| ファイル | 変更内容 |
|----------|----------|
| [`dsp/src/sampler.mbt`](../dsp/src/sampler.mbt) | バッファ削除、SlotMeta構造体導入、直接読み取り |
| [`dsp/src/blend.mbt`](../dsp/src/blend.mbt) | gain配列化 (冗長性解消) |
| [`plugin/src/WasmDSP.cpp`](../plugin/src/WasmDSP.cpp) | 変更なし |
| [`plugin/include/suna/WasmDSP.h`](../plugin/include/suna/WasmDSP.h) | 変更なし |
| [`ui/public/worklet/processor.js`](../ui/public/worklet/processor.js) | 変更なし |

### MoonBit変更案

```rust
// dsp/src/sampler.mbt (変更後)

// スロットのメタデータのみ保持
struct SlotMeta {
  mut data_ptr : Int    // Linear Memoryへのポインタ
  mut length : Int      // サンプル長
  mut play_pos : Int    // 再生位置
  mut playing : Int     // 再生フラグ
}

// 8スロット分のメタデータ (数百バイト)
let slots : FixedArray[SlotMeta] = FixedArray::makei(8, fn(_) {
  { data_ptr: 0, length: 0, play_pos: 0, playing: 0 }
})

// ゲイン値も配列化
let gains : FixedArray[Ref[Float]] = FixedArray::makei(8, fn(_) { { val: 0.125 } })

pub fn load_sample(slot : Int, data_ptr : Int, length : Int) -> Int {
  if slot < 0 || slot >= 8 { return -1 }
  if length <= 0 { return -2 }
  
  // ポインタと長さを記録するだけ (コピーしない!)
  let meta = slots[slot]
  meta.data_ptr = data_ptr
  meta.length = length
  meta.play_pos = 0
  meta.playing = 0
  0
}

pub fn process_sampler_stereo(left_in : Float, right_in : Float) -> (Float, Float) {
  let mut mix_out : Float = 0.0
  
  for slot = 0; slot < 8; slot = slot + 1 {
    let meta = slots[slot]
    if meta.playing == 1 && meta.play_pos < meta.length {
      // Linear Memoryから直接読む
      let sample = sampler_load_f32(meta.data_ptr + meta.play_pos * 4)
      mix_out = mix_out + sample * gains[slot].val
      meta.play_pos = meta.play_pos + 1
    } else if meta.play_pos >= meta.length {
      meta.playing = 0
    }
  }
  
  (left_in + mix_out, right_in + mix_out)
}
```

### 効果

| 項目 | Before | After |
|------|--------|-------|
| メモリ使用量 | ~92MB | ~46MB |
| コピー回数 | 2回 | 1回 |
| MoonBitコード行数 | ~650行 | ~200行 (推定) |
| 変数宣言 | 40個以上の個別変数 | 2つの配列 |

---

## 次のステップ

1. MoonBitで `SlotMeta` 構造体を実装
2. 既存テスト ([`dsp/src/sampler_test.mbt`](../dsp/src/sampler_test.mbt), [`dsp/src/buffer_test.mbt`](../dsp/src/buffer_test.mbt)) をパスする形で段階的に移行
3. `moon build --target wasm && moon test` で検証
4. ユーザーがM1 Macで `npm run build:dsp && npm run release:vst` を実行して最終確認

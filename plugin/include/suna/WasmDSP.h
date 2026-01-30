#pragma once

#include "wasm_export.h"
#include <atomic>
#include <cstdint>
#include <cstddef>

namespace suna {

/**
 * WasmDSP - C++ wrapper for MoonBit DSP functions via WAMR
 * 
 * Encapsulates WAMR runtime and provides a clean interface for calling
 * MoonBit DSP functions. This is a pure WAMR wrapper with no JUCE dependencies.
 * 
 * Usage:
 *   WasmDSP dsp;
 *   dsp.initialize(aotData, size);
 *   dsp.prepareToPlay(44100.0, 512);
 *   dsp.loadSample(0, pcmData, length);
 *   dsp.playAll();
 *   dsp.processBlock(leftIn, rightIn, leftOut, rightOut, numSamples);
 *   dsp.shutdown();
 */
class WasmDSP {
public:
    WasmDSP();
    ~WasmDSP();

    // Non-copyable, non-movable (owns WAMR resources)
    WasmDSP(const WasmDSP&) = delete;
    WasmDSP& operator=(const WasmDSP&) = delete;
    WasmDSP(WasmDSP&&) = delete;
    WasmDSP& operator=(WasmDSP&&) = delete;

    /**
     * Initialize WAMR runtime and load AOT module
     * @param aotData Pointer to AOT binary data
     * @param size Size of AOT binary in bytes
     * @return true on success, false on failure
     */
    bool initialize(const uint8_t* aotData, size_t size);

    void prepareToPlay(double sampleRate, int maxBlockSize);

    void processBlock(const float* leftIn, const float* rightIn,
                      float* leftOut, float* rightOut, int numSamples);

    void loadSample(int slot, const float* data, int length);
    void clearSlot(int slot);
    void playAll();
    void stopAll();
    int getSlotLength(int slot);
    void setBlendX(float value);
    void setBlendY(float value);
    void setPlaybackSpeed(float speed);
    void setGrainLength(int length);
    void setGrainDensity(float density);
    void setFreeze(int value);

    void shutdown();

    /**
     * Check if DSP is initialized and ready
     */
    bool isInitialized() const { return initialized_.load(); }

private:
    wasm_module_t module_ = nullptr;
    wasm_module_inst_t moduleInst_ = nullptr;
    wasm_exec_env_t execEnv_ = nullptr;

    wasm_function_inst_t initSamplerFunc_ = nullptr;
    wasm_function_inst_t loadSampleFunc_ = nullptr;
    wasm_function_inst_t clearSlotFunc_ = nullptr;
    wasm_function_inst_t playAllFunc_ = nullptr;
    wasm_function_inst_t stopAllFunc_ = nullptr;
    wasm_function_inst_t getSlotLengthFunc_ = nullptr;
    wasm_function_inst_t processBlockFunc_ = nullptr;
    wasm_function_inst_t setBlendXFunc_ = nullptr;
    wasm_function_inst_t setBlendYFunc_ = nullptr;
    wasm_function_inst_t setPlaybackSpeedFunc_ = nullptr;
    wasm_function_inst_t setGrainLengthFunc_ = nullptr;
    wasm_function_inst_t setGrainDensityFunc_ = nullptr;
    wasm_function_inst_t setFreezeFunc_ = nullptr;

    uint32_t leftInOffset_ = 0;
    uint32_t rightInOffset_ = 0;
    uint32_t leftOutOffset_ = 0;
    uint32_t rightOutOffset_ = 0;

    float* nativeLeftIn_ = nullptr;
    float* nativeRightIn_ = nullptr;
    float* nativeLeftOut_ = nullptr;
    float* nativeRightOut_ = nullptr;
    float* nativeSampleData_ = nullptr;

    static constexpr uint32_t SAMPLE_DATA_START = 1000000;

    int maxBlockSize_ = 0;
    std::atomic<bool> initialized_{false};
    std::atomic<bool> prepared_{false};

    static constexpr size_t HEAP_BUF_SIZE = 128 * 1024 * 1024;
    char heapBuf_[HEAP_BUF_SIZE];

    uint8_t* aotDataCopy_ = nullptr;
    size_t aotDataSize_ = 0;

    bool lookupFunctions();
    bool allocateBuffers(int maxBlockSize);
};

} // namespace suna

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
 *   dsp.setDelayTime(100.0f);
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

    /**
     * Prepare DSP for playback
     * Allocates buffers in WASM linear memory and initializes delay state
     * @param sampleRate Audio sample rate (e.g., 44100.0)
     * @param maxBlockSize Maximum number of samples per block
     */
    void prepareToPlay(double sampleRate, int maxBlockSize);

    /**
     * Process audio block through delay effect
     * @param leftIn Input left channel buffer
     * @param rightIn Input right channel buffer
     * @param leftOut Output left channel buffer
     * @param rightOut Output right channel buffer
     * @param numSamples Number of samples to process
     */
    void processBlock(const float* leftIn, const float* rightIn,
                      float* leftOut, float* rightOut, int numSamples);

    /**
     * Set delay time in milliseconds
     * @param ms Delay time (0.0 to max_delay_ms set in prepareToPlay)
     */
    void setDelayTime(float ms);

    /**
     * Set feedback amount
     * @param value Feedback (0.0 to 1.0)
     */
    void setFeedback(float value);

    /**
     * Set dry/wet mix
     * @param value Mix (0.0 = dry, 1.0 = wet)
     */
    void setMix(float value);

    /**
     * Clean up all WAMR resources
     * Called automatically by destructor
     */
    void shutdown();

    /**
     * Check if DSP is initialized and ready
     */
    bool isInitialized() const { return initialized_.load(); }

private:
    // WAMR runtime objects
    wasm_module_t module_ = nullptr;
    wasm_module_inst_t moduleInst_ = nullptr;
    wasm_exec_env_t execEnv_ = nullptr;

    // Function lookups (cached)
    wasm_function_inst_t initDelayFunc_ = nullptr;
    wasm_function_inst_t setDelayTimeFunc_ = nullptr;
    wasm_function_inst_t setFeedbackFunc_ = nullptr;
    wasm_function_inst_t setMixFunc_ = nullptr;
    wasm_function_inst_t processBlockFunc_ = nullptr;

    // Pre-allocated buffer offsets in WASM linear memory (byte offsets)
    uint32_t leftInOffset_ = 0;
    uint32_t rightInOffset_ = 0;
    uint32_t leftOutOffset_ = 0;
    uint32_t rightOutOffset_ = 0;

    // Native pointers to WASM memory (for fast access)
    float* nativeLeftIn_ = nullptr;
    float* nativeRightIn_ = nullptr;
    float* nativeLeftOut_ = nullptr;
    float* nativeRightOut_ = nullptr;

    int maxBlockSize_ = 0;
    std::atomic<bool> initialized_{false};
    std::atomic<bool> prepared_{false};

    static constexpr size_t HEAP_BUF_SIZE = 2 * 1024 * 1024;
    char heapBuf_[HEAP_BUF_SIZE];

    // Copy of AOT data (WAMR requires it to stay valid)
    uint8_t* aotDataCopy_ = nullptr;
    size_t aotDataSize_ = 0;

    // Helper to lookup WASM function
    bool lookupFunctions();

    // Helper to allocate buffers in WASM linear memory
    bool allocateBuffers(int maxBlockSize);
};

} // namespace suna

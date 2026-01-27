#include "suna/WasmDSP.h"
#include <cstring>
#include <cstdlib>
#include <juce_core/juce_core.h>

namespace suna {

WasmDSP::WasmDSP() {
    std::memset(heapBuf_, 0, HEAP_BUF_SIZE);
}

WasmDSP::~WasmDSP() {
    shutdown();
}

bool WasmDSP::initialize(const uint8_t* aotData, size_t size) {
    juce::Logger::writeToLog("WasmDSP::initialize() - Loading AOT module...");
    if (initialized_) {
        shutdown();
    }

    aotDataCopy_ = static_cast<uint8_t*>(std::malloc(size));
    if (!aotDataCopy_) {
        juce::Logger::writeToLog("WasmDSP::initialize() - Failed: malloc failed");
        return false;
    }
    std::memcpy(aotDataCopy_, aotData, size);
    aotDataSize_ = size;

    RuntimeInitArgs initArgs;
    std::memset(&initArgs, 0, sizeof(RuntimeInitArgs));
    initArgs.mem_alloc_type = Alloc_With_Pool;
    initArgs.mem_alloc_option.pool.heap_buf = heapBuf_;
    initArgs.mem_alloc_option.pool.heap_size = HEAP_BUF_SIZE;

    if (!wasm_runtime_full_init(&initArgs)) {
        juce::Logger::writeToLog("WasmDSP::initialize() - Failed: wasm_runtime_full_init failed");
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    char errorBuf[128];
    module_ = wasm_runtime_load(aotDataCopy_, static_cast<uint32_t>(aotDataSize_),
                                 errorBuf, sizeof(errorBuf));
    if (!module_) {
        juce::Logger::writeToLog("WasmDSP::initialize() - Failed: wasm_runtime_load failed - " + juce::String(errorBuf));
        wasm_runtime_destroy();
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    constexpr uint32_t stackSize = 16384;
    constexpr uint32_t heapSize = 1024 * 1024;
    moduleInst_ = wasm_runtime_instantiate(module_, stackSize, heapSize,
                                            errorBuf, sizeof(errorBuf));
    if (!moduleInst_) {
        juce::Logger::writeToLog("WasmDSP::initialize() - Failed: wasm_runtime_instantiate failed - " + juce::String(errorBuf));
        wasm_runtime_unload(module_);
        module_ = nullptr;
        wasm_runtime_destroy();
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    execEnv_ = wasm_runtime_create_exec_env(moduleInst_, stackSize);
    if (!execEnv_) {
        juce::Logger::writeToLog("WasmDSP::initialize() - Failed: wasm_runtime_create_exec_env failed");
        wasm_runtime_deinstantiate(moduleInst_);
        moduleInst_ = nullptr;
        wasm_runtime_unload(module_);
        module_ = nullptr;
        wasm_runtime_destroy();
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    if (!lookupFunctions()) {
        juce::Logger::writeToLog("WasmDSP::initialize() - Failed: lookupFunctions failed");
        shutdown();
        return false;
    }

    initialized_ = true;
    juce::Logger::writeToLog("WasmDSP::initialize() - Success");
    return true;
}

bool WasmDSP::lookupFunctions() {
    initDelayFunc_ = wasm_runtime_lookup_function(moduleInst_, "init_delay");
    setDelayTimeFunc_ = wasm_runtime_lookup_function(moduleInst_, "set_delay_time");
    setFeedbackFunc_ = wasm_runtime_lookup_function(moduleInst_, "set_feedback");
    setMixFunc_ = wasm_runtime_lookup_function(moduleInst_, "set_mix");
    processBlockFunc_ = wasm_runtime_lookup_function(moduleInst_, "process_block");

    return initDelayFunc_ && setDelayTimeFunc_ && setFeedbackFunc_ &&
           setMixFunc_ && processBlockFunc_;
}

bool WasmDSP::allocateBuffers(int maxBlockSize) {
    uint32_t bufferBytes = static_cast<uint32_t>(maxBlockSize) * sizeof(float);

    uint8_t* memBase = static_cast<uint8_t*>(
        wasm_runtime_addr_app_to_native(moduleInst_, 0));
    if (!memBase) {
        juce::Logger::writeToLog("WasmDSP::allocateBuffers() - Failed: memBase is null");
        return false;
    }

    /*
     * WASM Linear Memory Layout for MoonBit DSP
     * ==========================================
     * 
     * The MoonBit compiler uses heap-start-address: 65536 (0x10000) in moon.pkg.json.
     * Memory below this is reserved for MoonBit's stack. Memory above is the heap.
     * 
     * Layout:
     * ┌─────────────────────────────────────────────────────────────────┐
     * │ 0x00000 - 0x0FFFF (0-65535):     MoonBit Stack                  │
     * │ 0x10000 - 0xDBFFF (65536-900095): MoonBit Heap (delay buffer)   │
     * │   - Delay buffer: 96000 samples * 2 channels * 4 bytes = 768KB │
     * │   - Plus MoonBit runtime overhead                               │
     * │ 0xDBC9F (900000):                Audio Buffer Region Start      │
     * │   - Left Input  (maxBlockSize * sizeof(float))                  │
     * │   - Right Input (maxBlockSize * sizeof(float))                  │
     * │   - Left Output (maxBlockSize * sizeof(float))                  │
     * │   - Right Output(maxBlockSize * sizeof(float))                  │
     * └─────────────────────────────────────────────────────────────────┘
     * 
     * BUFFER_START = 900000 is chosen to:
     * 1. Be safely above MoonBit's heap usage (delay buffer ~768KB + overhead)
     * 2. Leave room for future DSP state expansion
     * 3. Align with WAMR's 1MB heap allocation (heapSize = 1024 * 1024)
     * 
     * WARNING: Do not change this value without updating MoonBit code.
     * The MoonBit DSP expects audio buffers at this exact offset.
     */
    constexpr uint32_t BUFFER_START = 900000;

    // Validate WASM memory is large enough for our buffer layout
    uint32_t requiredSize = BUFFER_START + (4 * bufferBytes);
    wasm_memory_inst_t memoryInst = wasm_runtime_get_default_memory(moduleInst_);
    if (memoryInst) {
        uint64_t pageCount = wasm_memory_get_cur_page_count(memoryInst);
        uint64_t bytesPerPage = wasm_memory_get_bytes_per_page(memoryInst);
        uint64_t actualSize = pageCount * bytesPerPage;
        if (actualSize < requiredSize) {
            juce::Logger::writeToLog("WasmDSP: WASM memory too small: " + juce::String(actualSize) + " bytes < required " + juce::String(requiredSize) + " bytes");
            return false;
        }
    }

    leftInOffset_ = BUFFER_START;
    rightInOffset_ = BUFFER_START + bufferBytes;
    leftOutOffset_ = BUFFER_START + 2 * bufferBytes;
    rightOutOffset_ = BUFFER_START + 3 * bufferBytes;

    nativeLeftIn_ = reinterpret_cast<float*>(memBase + leftInOffset_);
    nativeRightIn_ = reinterpret_cast<float*>(memBase + rightInOffset_);
    nativeLeftOut_ = reinterpret_cast<float*>(memBase + leftOutOffset_);
    nativeRightOut_ = reinterpret_cast<float*>(memBase + rightOutOffset_);

    std::memset(nativeLeftIn_, 0, bufferBytes);
    std::memset(nativeRightIn_, 0, bufferBytes);
    std::memset(nativeLeftOut_, 0, bufferBytes);
    std::memset(nativeRightOut_, 0, bufferBytes);

    maxBlockSize_ = maxBlockSize;
    juce::Logger::writeToLog("WasmDSP::allocateBuffers() - Success, maxBlockSize=" + juce::String(maxBlockSize));
    return true;
}

void WasmDSP::prepareToPlay(double sampleRate, int maxBlockSize) {
    juce::Logger::writeToLog("WasmDSP::prepareToPlay() - sampleRate=" + juce::String(sampleRate) + " blockSize=" + juce::String(maxBlockSize));
    if (!initialized_) {
        juce::Logger::writeToLog("WasmDSP::prepareToPlay() - Aborted: not initialized");
        return;
    }

    if (prepared_ && maxBlockSize_ >= maxBlockSize) {
        wasm_val_t args[2] = {
            { .kind = WASM_F32, .of = { .f32 = static_cast<float>(sampleRate) } },
            { .kind = WASM_F32, .of = { .f32 = 2000.0f } }
        };
        wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
        wasm_runtime_call_wasm_a(execEnv_, initDelayFunc_, 1, results, 2, args);
        return;
    }

    if (prepared_) {
        leftInOffset_ = rightInOffset_ = leftOutOffset_ = rightOutOffset_ = 0;
        nativeLeftIn_ = nativeRightIn_ = nativeLeftOut_ = nativeRightOut_ = nullptr;
    }

    if (!allocateBuffers(maxBlockSize)) {
        juce::Logger::writeToLog("WasmDSP::prepareToPlay() - Failed: allocateBuffers returned false");
        return;
    }

    wasm_val_t args[2] = {
        { .kind = WASM_F32, .of = { .f32 = static_cast<float>(sampleRate) } },
        { .kind = WASM_F32, .of = { .f32 = 2000.0f } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, initDelayFunc_, 1, results, 2, args);

    prepared_ = true;
    juce::Logger::writeToLog("WasmDSP::prepareToPlay() - Success, prepared_=true");
}

void WasmDSP::processBlock(const float* leftIn, const float* rightIn,
                           float* leftOut, float* rightOut, int numSamples) {
    static bool firstCall = true;
    if (firstCall) {
        juce::Logger::writeToLog("WasmDSP::processBlock() - First call with " + juce::String(numSamples) + " samples");
        firstCall = false;
    }

    // Initialize WAMR thread environment for audio thread (if not already initialized)
    // This is required because processBlock runs on the DAW's audio thread,
    // which is different from the main thread where wasm_runtime_full_init() was called.
    // See: https://github.com/bytecodealliance/wasm-micro-runtime/blob/main/core/iwasm/include/wasm_export.h#L1030-L1044
    static thread_local bool threadEnvInitialized = false;
    if (!threadEnvInitialized) {
        if (!wasm_runtime_thread_env_inited()) {
            if (!wasm_runtime_init_thread_env()) {
                juce::Logger::writeToLog("WasmDSP::processBlock() - FATAL: Failed to init thread env");
                // Fallback to passthrough
                if (numSamples > 0) {
                    size_t copyBytes = static_cast<size_t>(numSamples) * sizeof(float);
                    std::memcpy(leftOut, leftIn, copyBytes);
                    std::memcpy(rightOut, rightIn, copyBytes);
                }
                return;
            }
            juce::Logger::writeToLog("WasmDSP::processBlock() - Thread env initialized for audio thread");
        }
        threadEnvInitialized = true;
    }

    // Handle uninitialized/unprepared state with passthrough
    static bool passthroughLogged = false;
    if (!prepared_ || numSamples <= 0 || numSamples > maxBlockSize_) {
        if (!passthroughLogged) {
            juce::Logger::writeToLog("WasmDSP::processBlock() - PASSTHROUGH MODE: prepared_=" +
                juce::String(prepared_.load() ? "true" : "false") + ", numSamples=" + juce::String(numSamples) +
                ", maxBlockSize_=" + juce::String(maxBlockSize_));
            passthroughLogged = true;
        }
        if (numSamples > 0) {
            size_t copyBytes = static_cast<size_t>(numSamples) * sizeof(float);
            std::memcpy(leftOut, leftIn, copyBytes);
            std::memcpy(rightOut, rightIn, copyBytes);
        }
        return;
    }

    size_t copyBytes = static_cast<size_t>(numSamples) * sizeof(float);
    std::memcpy(nativeLeftIn_, leftIn, copyBytes);
    std::memcpy(nativeRightIn_, rightIn, copyBytes);

    wasm_val_t args[6] = {
        { .kind = WASM_I32, .of = { .i32 = 0 } },
        { .kind = WASM_I32, .of = { .i32 = static_cast<int32_t>(leftInOffset_) } },
        { .kind = WASM_I32, .of = { .i32 = static_cast<int32_t>(rightInOffset_) } },
        { .kind = WASM_I32, .of = { .i32 = static_cast<int32_t>(leftOutOffset_) } },
        { .kind = WASM_I32, .of = { .i32 = static_cast<int32_t>(rightOutOffset_) } },
        { .kind = WASM_I32, .of = { .i32 = numSamples } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = -999 } } };
    bool success = wasm_runtime_call_wasm_a(execEnv_, processBlockFunc_, 1, results, 6, args);
    
    static bool wasmCallLogged = false;
    if (!wasmCallLogged) {
        juce::Logger::writeToLog("WasmDSP::processBlock() - WASM call success=" + 
            juce::String(success ? "true" : "false"));
        wasmCallLogged = true;
    }
    
    if (!success) {
        const char* exception = wasm_runtime_get_exception(moduleInst_);
        juce::Logger::writeToLog("WASM call failed: " + juce::String(exception ? exception : "unknown error"));
        
        std::memcpy(leftOut, leftIn, copyBytes);
        std::memcpy(rightOut, rightIn, copyBytes);
        return;
    }

    std::memcpy(leftOut, nativeLeftOut_, copyBytes);
    std::memcpy(rightOut, nativeRightOut_, copyBytes);
}

void WasmDSP::setDelayTime(float ms) {
    if (!initialized_) return;

    wasm_val_t args[1] = {
        { .kind = WASM_F32, .of = { .f32 = ms } }
    };
    wasm_runtime_call_wasm_a(execEnv_, setDelayTimeFunc_, 0, nullptr, 1, args);
}

void WasmDSP::setFeedback(float value) {
    if (!initialized_) return;

    wasm_val_t args[1] = {
        { .kind = WASM_F32, .of = { .f32 = value } }
    };
    wasm_runtime_call_wasm_a(execEnv_, setFeedbackFunc_, 0, nullptr, 1, args);
}

void WasmDSP::setMix(float value) {
    if (!initialized_) return;

    wasm_val_t args[1] = {
        { .kind = WASM_F32, .of = { .f32 = value } }
    };
    wasm_runtime_call_wasm_a(execEnv_, setMixFunc_, 0, nullptr, 1, args);
}

void WasmDSP::shutdown() {
    // Clear flags FIRST to prevent audio thread from accessing resources during destruction
    const bool wasInitialized = initialized_.exchange(false);
    prepared_.store(false);

    if (execEnv_) {
        wasm_runtime_destroy_exec_env(execEnv_);
        execEnv_ = nullptr;
    }

    if (moduleInst_) {
        wasm_runtime_deinstantiate(moduleInst_);
        moduleInst_ = nullptr;
    }

    if (module_) {
        wasm_runtime_unload(module_);
        module_ = nullptr;
    }

    if (wasInitialized) {
        wasm_runtime_destroy();
    }

    if (aotDataCopy_) {
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
    }

    initDelayFunc_ = nullptr;
    setDelayTimeFunc_ = nullptr;
    setFeedbackFunc_ = nullptr;
    setMixFunc_ = nullptr;
    processBlockFunc_ = nullptr;

    leftInOffset_ = rightInOffset_ = leftOutOffset_ = rightOutOffset_ = 0;
    nativeLeftIn_ = nativeRightIn_ = nativeLeftOut_ = nativeRightOut_ = nullptr;
    maxBlockSize_ = 0;
    aotDataSize_ = 0;
}

} // namespace suna

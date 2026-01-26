#include "suna/WasmDSP.h"
#include <cstring>
#include <cstdlib>

namespace suna {

WasmDSP::WasmDSP() {
    std::memset(heapBuf_, 0, HEAP_BUF_SIZE);
}

WasmDSP::~WasmDSP() {
    shutdown();
}

bool WasmDSP::initialize(const uint8_t* aotData, size_t size) {
    if (initialized_) {
        shutdown();
    }

    aotDataCopy_ = static_cast<uint8_t*>(std::malloc(size));
    if (!aotDataCopy_) {
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
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    char errorBuf[128];
    module_ = wasm_runtime_load(aotDataCopy_, static_cast<uint32_t>(aotDataSize_),
                                 errorBuf, sizeof(errorBuf));
    if (!module_) {
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
        wasm_runtime_unload(module_);
        module_ = nullptr;
        wasm_runtime_destroy();
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    execEnv_ = wasm_runtime_create_exec_env(moduleInst_, stackSize);
    if (!execEnv_) {
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
        shutdown();
        return false;
    }

    initialized_ = true;
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
    if (!memBase) return false;

    constexpr uint32_t BUFFER_START = 900000;
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
    return true;
}

void WasmDSP::prepareToPlay(double sampleRate, int maxBlockSize) {
    if (!initialized_) return;

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
        return;
    }

    wasm_val_t args[2] = {
        { .kind = WASM_F32, .of = { .f32 = static_cast<float>(sampleRate) } },
        { .kind = WASM_F32, .of = { .f32 = 2000.0f } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, initDelayFunc_, 1, results, 2, args);

    prepared_ = true;
}

void WasmDSP::processBlock(const float* leftIn, const float* rightIn,
                           float* leftOut, float* rightOut, int numSamples) {
    if (!prepared_ || numSamples <= 0 || numSamples > maxBlockSize_) return;

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
    
    if (!success) {
        const char* exception = wasm_runtime_get_exception(moduleInst_);
        if (exception) {
            return;
        }
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

    if (initialized_) {
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
    initialized_ = false;
    prepared_ = false;
}

} // namespace suna

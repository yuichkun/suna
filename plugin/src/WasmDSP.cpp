#include "suna/WasmDSP.h"
#include <cstring>
#include <cstdlib>
#include <thread>
#include <functional>
#include <string>

// Conditional JUCE support for standalone test builds
#if __has_include(<juce_core/juce_core.h>)
#include <juce_core/juce_core.h>
#define SUNA_HAS_JUCE 1
#else
#define SUNA_HAS_JUCE 0
#endif

// Logging macro - no-op when JUCE is not available
#if SUNA_HAS_JUCE
#define SUNA_LOG(msg) juce::Logger::writeToLog(msg)
#else
#define SUNA_LOG(msg) ((void)0)
#endif

namespace suna {

static void spectestPrintChar(wasm_exec_env_t exec_env, int32_t charCode) {
    (void)exec_env;
    static std::string printBuffer;
    if (charCode == 10) {
        SUNA_LOG("[WASM] " + printBuffer);
        printBuffer.clear();
    } else {
        printBuffer += static_cast<char>(charCode);
    }
}

static NativeSymbol nativeSymbols[] = {
    { "print_char", (void*)spectestPrintChar, "(i)", nullptr }
};

WasmDSP::WasmDSP() {
    std::memset(heapBuf_, 0, HEAP_BUF_SIZE);
}

WasmDSP::~WasmDSP() {
    shutdown();
}

bool WasmDSP::initialize(const uint8_t* aotData, size_t size) {
    SUNA_LOG("WasmDSP::initialize() - Loading AOT module...");
    if (initialized_) {
        shutdown();
    }

    aotDataCopy_ = static_cast<uint8_t*>(std::malloc(size));
    if (!aotDataCopy_) {
        SUNA_LOG("WasmDSP::initialize() - Failed: malloc failed");
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
        SUNA_LOG("WasmDSP::initialize() - Failed: wasm_runtime_full_init failed");
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    if (!wasm_runtime_register_natives("spectest", nativeSymbols,
                                        sizeof(nativeSymbols) / sizeof(NativeSymbol))) {
        SUNA_LOG("WasmDSP::initialize() - Failed: wasm_runtime_register_natives failed");
        wasm_runtime_destroy();
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    char errorBuf[128];
    module_ = wasm_runtime_load(aotDataCopy_, static_cast<uint32_t>(aotDataSize_),
                                 errorBuf, sizeof(errorBuf));
    if (!module_) {
        SUNA_LOG(std::string("WasmDSP::initialize() - Failed: wasm_runtime_load failed - ") + errorBuf);
        wasm_runtime_destroy();
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    constexpr uint32_t stackSize = 16384;
    constexpr uint32_t heapSize = 64 * 1024 * 1024;
    moduleInst_ = wasm_runtime_instantiate(module_, stackSize, heapSize,
                                            errorBuf, sizeof(errorBuf));
    if (!moduleInst_) {
        SUNA_LOG(std::string("WasmDSP::initialize() - Failed: wasm_runtime_instantiate failed - ") + errorBuf);
        wasm_runtime_unload(module_);
        module_ = nullptr;
        wasm_runtime_destroy();
        std::free(aotDataCopy_);
        aotDataCopy_ = nullptr;
        return false;
    }

    execEnv_ = wasm_runtime_create_exec_env(moduleInst_, stackSize);
    if (!execEnv_) {
        SUNA_LOG("WasmDSP::initialize() - Failed: wasm_runtime_create_exec_env failed");
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
        SUNA_LOG("WasmDSP::initialize() - Failed: lookupFunctions failed");
        shutdown();
        return false;
    }

    initialized_ = true;
    SUNA_LOG("WasmDSP::initialize() - Success");
    return true;
}

bool WasmDSP::lookupFunctions() {
    initSamplerFunc_ = wasm_runtime_lookup_function(moduleInst_, "init_sampler");
    loadSampleFunc_ = wasm_runtime_lookup_function(moduleInst_, "load_sample");
    clearSlotFunc_ = wasm_runtime_lookup_function(moduleInst_, "clear_slot");
    playAllFunc_ = wasm_runtime_lookup_function(moduleInst_, "play_all");
    stopAllFunc_ = wasm_runtime_lookup_function(moduleInst_, "stop_all");
    getSlotLengthFunc_ = wasm_runtime_lookup_function(moduleInst_, "get_slot_length");
    processBlockFunc_ = wasm_runtime_lookup_function(moduleInst_, "process_block");
    setBlendXFunc_ = wasm_runtime_lookup_function(moduleInst_, "set_blend_x");
    setBlendYFunc_ = wasm_runtime_lookup_function(moduleInst_, "set_blend_y");
    setPlaybackSpeedFunc_ = wasm_runtime_lookup_function(moduleInst_, "set_playback_speed");
    setGrainLengthFunc_ = wasm_runtime_lookup_function(moduleInst_, "set_grain_length");
    setGrainDensityFunc_ = wasm_runtime_lookup_function(moduleInst_, "set_grain_density");
    setFreezeFunc_ = wasm_runtime_lookup_function(moduleInst_, "set_freeze");

    return initSamplerFunc_ && loadSampleFunc_ && clearSlotFunc_ &&
           playAllFunc_ && stopAllFunc_ && getSlotLengthFunc_ && processBlockFunc_ &&
           setBlendXFunc_ && setBlendYFunc_ && setPlaybackSpeedFunc_ &&
           setGrainLengthFunc_ && setGrainDensityFunc_ && setFreezeFunc_;
}

bool WasmDSP::allocateBuffers(int maxBlockSize) {
    uint32_t bufferBytes = static_cast<uint32_t>(maxBlockSize) * sizeof(float);

    uint8_t* memBase = static_cast<uint8_t*>(
        wasm_runtime_addr_app_to_native(moduleInst_, 0));
    if (!memBase) {
        SUNA_LOG("WasmDSP::allocateBuffers() - Failed: memBase is null");
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
            SUNA_LOG("WasmDSP: WASM memory too small: " + std::to_string(actualSize) + " bytes < required " + std::to_string(requiredSize) + " bytes");
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
    nativeSampleData_ = reinterpret_cast<float*>(memBase + SAMPLE_DATA_START);

    std::memset(nativeLeftIn_, 0, bufferBytes);
    std::memset(nativeRightIn_, 0, bufferBytes);
    std::memset(nativeLeftOut_, 0, bufferBytes);
    std::memset(nativeRightOut_, 0, bufferBytes);

    maxBlockSize_ = maxBlockSize;
    
    SUNA_LOG("ALLOC_BUFFERS: memBase=" + std::to_string(reinterpret_cast<uintptr_t>(memBase)) +
             " leftInOff=" + std::to_string(leftInOffset_) +
             " rightInOff=" + std::to_string(rightInOffset_) +
             " leftOutOff=" + std::to_string(leftOutOffset_) +
             " rightOutOff=" + std::to_string(rightOutOffset_));
    SUNA_LOG("ALLOC_BUFFERS: SAMPLE_DATA_START=" + std::to_string(SAMPLE_DATA_START) +
             " nativeSampleData=" + std::to_string(reinterpret_cast<uintptr_t>(nativeSampleData_)) +
             " bufferBytes=" + std::to_string(bufferBytes) +
             " maxBlockSize=" + std::to_string(maxBlockSize));
    
    return true;
}

void WasmDSP::prepareToPlay(double sampleRate, int maxBlockSize) {
    SUNA_LOG("WasmDSP::prepareToPlay() - sampleRate=" + std::to_string(sampleRate) + " blockSize=" + std::to_string(maxBlockSize));
    if (!initialized_) {
        SUNA_LOG("WasmDSP::prepareToPlay() - Aborted: not initialized");
        return;
    }

    if (prepared_ && maxBlockSize_ >= maxBlockSize) {
        wasm_val_t args[1] = {
            { .kind = WASM_F32, .of = { .f32 = static_cast<float>(sampleRate) } }
        };
        wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
        wasm_runtime_call_wasm_a(execEnv_, initSamplerFunc_, 1, results, 1, args);
        return;
    }

    if (prepared_) {
        leftInOffset_ = rightInOffset_ = leftOutOffset_ = rightOutOffset_ = 0;
        nativeLeftIn_ = nativeRightIn_ = nativeLeftOut_ = nativeRightOut_ = nullptr;
        nativeSampleData_ = nullptr;
    }

    if (!allocateBuffers(maxBlockSize)) {
        SUNA_LOG("WasmDSP::prepareToPlay() - Failed: allocateBuffers returned false");
        return;
    }

    wasm_val_t args[1] = {
        { .kind = WASM_F32, .of = { .f32 = static_cast<float>(sampleRate) } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, initSamplerFunc_, 1, results, 1, args);

    prepared_ = true;
    SUNA_LOG("WasmDSP::prepareToPlay() - Success, prepared_=true");
}

void WasmDSP::processBlock(const float* leftIn, const float* rightIn,
                           float* leftOut, float* rightOut, int numSamples) {
    static bool firstCall = true;
    if (firstCall) {
        SUNA_LOG("WasmDSP::processBlock() - First call with " + std::to_string(numSamples) + " samples");
        firstCall = false;
    }
    
    // === THREAD ENV INITIALIZATION WITH DIAGNOSTICS ===
    // WAMR requires thread env to be initialized on any thread calling WASM functions.
    // processBlock runs on DAW's audio thread, different from main thread where
    // wasm_runtime_full_init() was called.
    //
    // Known issue: On some builds, init() returns true but env_inited() stays false.
    // This diagnostic code helps identify the root cause.
    static thread_local bool threadEnvInitialized = false;
    static thread_local int threadInitAttempts = 0;
    
    if (!threadEnvInitialized) {
        threadInitAttempts++;
        
        // Get thread ID for logging (truncated for readability)
        auto threadIdHash = std::hash<std::thread::id>{}(std::this_thread::get_id()) % 10000;
        
        bool envInitedBefore = wasm_runtime_thread_env_inited();
        SUNA_LOG("WasmDSP DIAG: Thread " + std::to_string(threadIdHash) +
            " - env_inited_before=" + std::string(envInitedBefore ? "true" : "false") +
            " - attempt=" + std::to_string(threadInitAttempts));
        
        if (!envInitedBefore) {
            bool initResult = wasm_runtime_init_thread_env();
            bool envInitedAfter = wasm_runtime_thread_env_inited();
            
            SUNA_LOG("WasmDSP DIAG: Thread " + std::to_string(threadIdHash) +
                " - init_result=" + std::string(initResult ? "true" : "false") +
                " - env_inited_after=" + std::string(envInitedAfter ? "true" : "false"));
            
            if (!initResult) {
                SUNA_LOG("WasmDSP DIAG: FATAL - init_thread_env returned false");
                if (numSamples > 0) {
                    size_t copyBytes = static_cast<size_t>(numSamples) * sizeof(float);
                    std::memset(leftOut, 0, copyBytes);
                    std::memset(rightOut, 0, copyBytes);
                }
                return;
            }
            
            if (!envInitedAfter) {
                // THIS IS THE KEY DIAGNOSTIC:
                // If we reach here, init returned true but env_inited is still false.
                // This confirms a TLS issue, symbol resolution problem, or library build issue.
                SUNA_LOG("WasmDSP DIAG: ANOMALY - init=true but env_inited=false after init!");
            }
        }
        threadEnvInitialized = true;
    }
    // === END THREAD ENV INITIALIZATION ===

    // Handle uninitialized/unprepared state with passthrough
    static bool passthroughLogged = false;
    if (!prepared_ || numSamples <= 0 || numSamples > maxBlockSize_) {
        if (!passthroughLogged) {
            SUNA_LOG("WasmDSP::processBlock() - PASSTHROUGH MODE: prepared_=" +
                std::string(prepared_.load() ? "true" : "false") + ", numSamples=" + std::to_string(numSamples) +
                ", maxBlockSize_=" + std::to_string(maxBlockSize_));
            passthroughLogged = true;
        }
        if (numSamples > 0) {
            size_t copyBytes = static_cast<size_t>(numSamples) * sizeof(float);
            std::memset(leftOut, 0, copyBytes);
            std::memset(rightOut, 0, copyBytes);
        }
        return;
    }

    size_t copyBytes = static_cast<size_t>(numSamples) * sizeof(float);

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
        SUNA_LOG(std::string("WASM call failed: ") + (exception ? exception : "unknown error"));
        
        std::memset(leftOut, 0, copyBytes);
        std::memset(rightOut, 0, copyBytes);
        return;
    }

    static int debugCounter = 0;
    if (++debugCounter % 500 == 0) {
        float maxSample = 0.0f;
        for (int i = 0; i < numSamples; i++) {
            float absVal = nativeLeftOut_[i] < 0 ? -nativeLeftOut_[i] : nativeLeftOut_[i];
            if (absVal > maxSample) maxSample = absVal;
        }
        
        std::string slotInfo = "";
        for (int s = 0; s < 8; s++) {
            slotInfo += "s" + std::to_string(s) + "=" + std::to_string(getSlotLength(s)) + " ";
        }
        
        SUNA_LOG("DSP_OUT: peak=" + std::to_string(maxSample) + 
                 " result=" + std::to_string(results[0].of.i32) +
                 " | " + slotInfo);
        
        SUNA_LOG("DSP_ARGS: leftIn=" + std::to_string(leftInOffset_) +
                 " rightIn=" + std::to_string(rightInOffset_) +
                 " leftOut=" + std::to_string(leftOutOffset_) +
                 " rightOut=" + std::to_string(rightOutOffset_) +
                 " samples=" + std::to_string(numSamples));
        
        SUNA_LOG("DSP_PTR: nativeLeftOut=" + std::to_string(reinterpret_cast<uintptr_t>(nativeLeftOut_)) +
                 " nativeSampleData=" + std::to_string(reinterpret_cast<uintptr_t>(nativeSampleData_)));
    }

    std::memcpy(leftOut, nativeLeftOut_, copyBytes);
    std::memcpy(rightOut, nativeRightOut_, copyBytes);
}

void WasmDSP::loadSample(int slot, const float* data, int length) {
    SUNA_LOG("LOAD_SAMPLE_START: slot=" + std::to_string(slot) + 
             " length=" + std::to_string(length) +
             " initialized=" + std::string(initialized_ ? "true" : "false") +
             " nativeSampleData=" + std::to_string(reinterpret_cast<uintptr_t>(nativeSampleData_)));
    
    if (!initialized_ || !nativeSampleData_) {
        SUNA_LOG("LOAD_SAMPLE_ABORT: not initialized or no sample data ptr");
        return;
    }

    constexpr int MAX_SAMPLES_PER_SLOT = 1440000;
    int copyLength = (length > MAX_SAMPLES_PER_SLOT) ? MAX_SAMPLES_PER_SLOT : length;
    
    uint32_t slotOffset = static_cast<uint32_t>(slot) * MAX_SAMPLES_PER_SLOT;
    std::memcpy(nativeSampleData_ + slotOffset, data, static_cast<size_t>(copyLength) * sizeof(float));

    uint32_t dataPtr = SAMPLE_DATA_START + slotOffset * sizeof(float);
    
    float firstSample = data[0];
    float lastSample = data[copyLength - 1];
    float maxInSample = 0.0f;
    for (int i = 0; i < std::min(copyLength, 1000); i++) {
        float absVal = data[i] < 0 ? -data[i] : data[i];
        if (absVal > maxInSample) maxInSample = absVal;
    }
    
    SUNA_LOG("LOAD_SAMPLE_DATA: slotOffset=" + std::to_string(slotOffset) +
             " dataPtr=" + std::to_string(dataPtr) +
             " copyLength=" + std::to_string(copyLength) +
             " firstSample=" + std::to_string(firstSample) +
             " lastSample=" + std::to_string(lastSample) +
             " maxIn1000=" + std::to_string(maxInSample));
    
    wasm_val_t args[3] = {
        { .kind = WASM_I32, .of = { .i32 = slot } },
        { .kind = WASM_I32, .of = { .i32 = static_cast<int32_t>(dataPtr) } },
        { .kind = WASM_I32, .of = { .i32 = copyLength } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = -999 } } };
    bool success = wasm_runtime_call_wasm_a(execEnv_, loadSampleFunc_, 1, results, 3, args);
    
    int slotLenAfter = getSlotLength(slot);
    
    SUNA_LOG("LOAD_SAMPLE_RESULT: success=" + std::string(success ? "true" : "false") +
             " wasmResult=" + std::to_string(results[0].of.i32) +
             " slotLengthAfter=" + std::to_string(slotLenAfter));
}

void WasmDSP::clearSlot(int slot) {
    if (!initialized_) return;

    wasm_val_t args[1] = {
        { .kind = WASM_I32, .of = { .i32 = slot } }
    };
    wasm_runtime_call_wasm_a(execEnv_, clearSlotFunc_, 0, nullptr, 1, args);
}

void WasmDSP::playAll() {
    SUNA_LOG("PLAY_ALL called");
    if (!initialized_) {
        SUNA_LOG("PLAY_ALL aborted: not initialized");
        return;
    }
    wasm_runtime_call_wasm_a(execEnv_, playAllFunc_, 0, nullptr, 0, nullptr);
    
    std::string slotInfo = "";
    for (int s = 0; s < 8; s++) {
        slotInfo += "s" + std::to_string(s) + "=" + std::to_string(getSlotLength(s)) + " ";
    }
    SUNA_LOG("PLAY_ALL done, slots: " + slotInfo);
}

void WasmDSP::stopAll() {
    SUNA_LOG("STOP_ALL called");
    if (!initialized_) return;
    wasm_runtime_call_wasm_a(execEnv_, stopAllFunc_, 0, nullptr, 0, nullptr);
}

void WasmDSP::setBlendX(float value) {
    if (!initialized_) return;
    
    static float lastLoggedX = -999.0f;
    if (std::abs(value - lastLoggedX) > 0.01f) {
        SUNA_LOG("SET_BLEND_X: " + std::to_string(value));
        lastLoggedX = value;
    }
    
    wasm_val_t args[1] = {
        { .kind = WASM_F32, .of = { .f32 = value } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, setBlendXFunc_, 1, results, 1, args);
}

void WasmDSP::setBlendY(float value) {
    if (!initialized_) return;
    
    static float lastLoggedY = -999.0f;
    if (std::abs(value - lastLoggedY) > 0.01f) {
        SUNA_LOG("SET_BLEND_Y: " + std::to_string(value));
        lastLoggedY = value;
    }
    
    wasm_val_t args[1] = {
        { .kind = WASM_F32, .of = { .f32 = value } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, setBlendYFunc_, 1, results, 1, args);
}

void WasmDSP::setPlaybackSpeed(float speed) {
    if (!initialized_) return;
    
    static float lastLoggedSpeed = -999.0f;
    if (std::abs(speed - lastLoggedSpeed) > 0.01f) {
        SUNA_LOG("SET_SPEED: " + std::to_string(speed));
        lastLoggedSpeed = speed;
    }
    
    wasm_val_t args[1] = {
        { .kind = WASM_F32, .of = { .f32 = speed } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, setPlaybackSpeedFunc_, 1, results, 1, args);
}

void WasmDSP::setGrainLength(int length) {
    if (!initialized_) return;
    
    static int lastLoggedLen = -999;
    if (length != lastLoggedLen) {
        SUNA_LOG("SET_GRAIN_LEN: " + std::to_string(length));
        lastLoggedLen = length;
    }
    
    wasm_val_t args[1] = {
        { .kind = WASM_I32, .of = { .i32 = length } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, setGrainLengthFunc_, 1, results, 1, args);
}

void WasmDSP::setGrainDensity(float density) {
    if (!initialized_) return;
    
    static float lastLoggedDensity = -999.0f;
    if (std::abs(density - lastLoggedDensity) > 0.001f) {
        SUNA_LOG("SET_DENSITY: " + std::to_string(density));
        lastLoggedDensity = density;
    }
    
    wasm_val_t args[1] = {
        { .kind = WASM_F32, .of = { .f32 = density } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, setGrainDensityFunc_, 1, results, 1, args);
}

void WasmDSP::setFreeze(int value) {
    if (!initialized_) return;
    
    static int lastLoggedFreeze = -999;
    if (value != lastLoggedFreeze) {
        SUNA_LOG("SET_FREEZE: " + std::to_string(value));
        lastLoggedFreeze = value;
    }
    
    wasm_val_t args[1] = {
        { .kind = WASM_I32, .of = { .i32 = value } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, setFreezeFunc_, 1, results, 1, args);
}

int WasmDSP::getSlotLength(int slot) {
    if (!initialized_) return 0;

    wasm_val_t args[1] = {
        { .kind = WASM_I32, .of = { .i32 = slot } }
    };
    wasm_val_t results[1] = { { .kind = WASM_I32, .of = { .i32 = 0 } } };
    wasm_runtime_call_wasm_a(execEnv_, getSlotLengthFunc_, 1, results, 1, args);
    return results[0].of.i32;
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

    initSamplerFunc_ = nullptr;
    loadSampleFunc_ = nullptr;
    clearSlotFunc_ = nullptr;
    playAllFunc_ = nullptr;
    stopAllFunc_ = nullptr;
    getSlotLengthFunc_ = nullptr;
    processBlockFunc_ = nullptr;
    setBlendXFunc_ = nullptr;
    setBlendYFunc_ = nullptr;
    setPlaybackSpeedFunc_ = nullptr;
    setGrainLengthFunc_ = nullptr;
    setGrainDensityFunc_ = nullptr;
    setFreezeFunc_ = nullptr;

    leftInOffset_ = rightInOffset_ = leftOutOffset_ = rightOutOffset_ = 0;
    nativeLeftIn_ = nativeRightIn_ = nativeLeftOut_ = nativeRightOut_ = nullptr;
    nativeSampleData_ = nullptr;
    maxBlockSize_ = 0;
    aotDataSize_ = 0;
}

} // namespace suna

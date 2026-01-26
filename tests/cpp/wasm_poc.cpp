/**
 * Task 0.5: C++ <-> WASM Integration PoC
 * 
 * Verifies WAMR can call MoonBit WASM functions AND that MoonBit global state
 * persists across calls (critical for audio DSP).
 */

#define CATCH_CONFIG_MAIN
#include "include/catch_amalgamated.hpp"

#include "wasm_export.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>

// Path to AOT module (relative to test execution directory in build/)
static const char* AOT_FILE_PATH = "../../../libs/wamr/wamr-compiler/build/dsp.aot";

// Global heap buffer for WAMR runtime
static char global_heap_buf[512 * 1024];

// Helper to read file into buffer
static char* read_file_to_buffer(const char* filename, uint32_t* size) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        return nullptr;
    }
    
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    char* buffer = (char*)malloc(file_size);
    if (!buffer) {
        fclose(file);
        return nullptr;
    }
    
    size_t read_size = fread(buffer, 1, file_size, file);
    fclose(file);
    
    if (read_size != (size_t)file_size) {
        free(buffer);
        return nullptr;
    }
    
    *size = (uint32_t)file_size;
    return buffer;
}

// WAMR runtime wrapper for tests
class WamrRuntime {
public:
    wasm_module_t module = nullptr;
    wasm_module_inst_t module_inst = nullptr;
    wasm_exec_env_t exec_env = nullptr;
    char* buffer = nullptr;
    uint32_t buf_size = 0;
    char error_buf[128];
    
    bool init() {
        RuntimeInitArgs init_args;
        memset(&init_args, 0, sizeof(RuntimeInitArgs));
        
        init_args.mem_alloc_type = Alloc_With_Pool;
        init_args.mem_alloc_option.pool.heap_buf = global_heap_buf;
        init_args.mem_alloc_option.pool.heap_size = sizeof(global_heap_buf);
        
        if (!wasm_runtime_full_init(&init_args)) {
            return false;
        }
        
        // Load AOT file
        buffer = read_file_to_buffer(AOT_FILE_PATH, &buf_size);
        if (!buffer) {
            wasm_runtime_destroy();
            return false;
        }
        
        // Load module
        module = wasm_runtime_load((uint8_t*)buffer, buf_size, error_buf, sizeof(error_buf));
        if (!module) {
            free(buffer);
            wasm_runtime_destroy();
            return false;
        }
        
        // Instantiate module
        uint32_t stack_size = 8192;
        uint32_t heap_size = 8192;
        module_inst = wasm_runtime_instantiate(module, stack_size, heap_size, error_buf, sizeof(error_buf));
        if (!module_inst) {
            wasm_runtime_unload(module);
            free(buffer);
            wasm_runtime_destroy();
            return false;
        }
        
        // Create execution environment
        exec_env = wasm_runtime_create_exec_env(module_inst, stack_size);
        if (!exec_env) {
            wasm_runtime_deinstantiate(module_inst);
            wasm_runtime_unload(module);
            free(buffer);
            wasm_runtime_destroy();
            return false;
        }
        
        return true;
    }
    
    void cleanup() {
        if (exec_env) {
            wasm_runtime_destroy_exec_env(exec_env);
            exec_env = nullptr;
        }
        if (module_inst) {
            wasm_runtime_deinstantiate(module_inst);
            module_inst = nullptr;
        }
        if (module) {
            wasm_runtime_unload(module);
            module = nullptr;
        }
        if (buffer) {
            free(buffer);
            buffer = nullptr;
        }
        wasm_runtime_destroy();
    }
    
    wasm_function_inst_t lookup_function(const char* name) {
        return wasm_runtime_lookup_function(module_inst, name);
    }
    
    bool call_wasm(wasm_function_inst_t func, uint32_t argc, uint32_t* argv) {
        return wasm_runtime_call_wasm(exec_env, func, argc, argv);
    }
    
    const char* get_exception() {
        return wasm_runtime_get_exception(module_inst);
    }
};

TEST_CASE("WAMR runtime initialization", "[wamr]") {
    WamrRuntime runtime;
    
    REQUIRE(runtime.init());
    
    SECTION("module loaded successfully") {
        REQUIRE(runtime.module != nullptr);
        REQUIRE(runtime.module_inst != nullptr);
        REQUIRE(runtime.exec_env != nullptr);
    }
    
    runtime.cleanup();
}

TEST_CASE("multiply function", "[wamr][dsp]") {
    WamrRuntime runtime;
    REQUIRE(runtime.init());
    
    auto func = runtime.lookup_function("multiply");
    REQUIRE(func != nullptr);
    
    // Call multiply(2.0, 3.0)
    // For f32 arguments, we need to use wasm_val_t
    wasm_val_t args[2] = {
        { .kind = WASM_F32, .of = { .f32 = 2.0f } },
        { .kind = WASM_F32, .of = { .f32 = 3.0f } }
    };
    wasm_val_t results[1] = {
        { .kind = WASM_F32, .of = { .f32 = 0.0f } }
    };
    
    bool success = wasm_runtime_call_wasm_a(runtime.exec_env, func, 1, results, 2, args);
    REQUIRE(success);
    
    float result = results[0].of.f32;
    INFO("multiply(2.0, 3.0) = " << result);
    REQUIRE(result == Catch::Approx(6.0f));
    
    runtime.cleanup();
}

TEST_CASE("add function", "[wamr][dsp]") {
    WamrRuntime runtime;
    REQUIRE(runtime.init());
    
    auto func = runtime.lookup_function("add");
    REQUIRE(func != nullptr);
    
    // Call add(1.0, 2.0)
    wasm_val_t args[2] = {
        { .kind = WASM_F32, .of = { .f32 = 1.0f } },
        { .kind = WASM_F32, .of = { .f32 = 2.0f } }
    };
    wasm_val_t results[1] = {
        { .kind = WASM_F32, .of = { .f32 = 0.0f } }
    };
    
    bool success = wasm_runtime_call_wasm_a(runtime.exec_env, func, 1, results, 2, args);
    REQUIRE(success);
    
    float result = results[0].of.f32;
    INFO("add(1.0, 2.0) = " << result);
    REQUIRE(result == Catch::Approx(3.0f));
    
    runtime.cleanup();
}

TEST_CASE("state persistence", "[wamr][dsp][critical]") {
    WamrRuntime runtime;
    REQUIRE(runtime.init());
    
    // First, call _start to initialize the module (runs main)
    auto start_func = runtime.lookup_function("_start");
    if (start_func) {
        uint32_t argv[1] = {0};
        runtime.call_wasm(start_func, 0, argv);
    }
    
    auto increment_func = runtime.lookup_function("increment");
    auto get_counter_func = runtime.lookup_function("get_counter");
    
    REQUIRE(increment_func != nullptr);
    REQUIRE(get_counter_func != nullptr);
    
    SECTION("increment returns incremented value") {
        // increment() returns Int (i32)
        wasm_val_t results[1] = {
            { .kind = WASM_I32, .of = { .i32 = 0 } }
        };
        
        // First call: should return 1
        bool success = wasm_runtime_call_wasm_a(runtime.exec_env, increment_func, 1, results, 0, nullptr);
        REQUIRE(success);
        INFO("increment() call 1 = " << results[0].of.i32);
        REQUIRE(results[0].of.i32 == 1);
        
        // Second call: should return 2
        success = wasm_runtime_call_wasm_a(runtime.exec_env, increment_func, 1, results, 0, nullptr);
        REQUIRE(success);
        INFO("increment() call 2 = " << results[0].of.i32);
        REQUIRE(results[0].of.i32 == 2);
        
        // Third call: should return 3
        success = wasm_runtime_call_wasm_a(runtime.exec_env, increment_func, 1, results, 0, nullptr);
        REQUIRE(success);
        INFO("increment() call 3 = " << results[0].of.i32);
        REQUIRE(results[0].of.i32 == 3);
    }
    
    SECTION("get_counter returns current state") {
        // Call increment 3 times
        wasm_val_t inc_results[1] = {
            { .kind = WASM_I32, .of = { .i32 = 0 } }
        };
        
        for (int i = 0; i < 3; i++) {
            bool success = wasm_runtime_call_wasm_a(runtime.exec_env, increment_func, 1, inc_results, 0, nullptr);
            REQUIRE(success);
        }
        
        // Now get_counter should return 3
        wasm_val_t counter_results[1] = {
            { .kind = WASM_I32, .of = { .i32 = 0 } }
        };
        
        bool success = wasm_runtime_call_wasm_a(runtime.exec_env, get_counter_func, 1, counter_results, 0, nullptr);
        REQUIRE(success);
        
        int counter = counter_results[0].of.i32;
        INFO("get_counter() after 3 increments = " << counter);
        
        // CRITICAL: State must persist across function calls
        // This verifies MoonBit's Ref[Int] state is maintained in linear memory
        REQUIRE(counter == 3);
    }
    
    runtime.cleanup();
}

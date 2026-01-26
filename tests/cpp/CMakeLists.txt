cmake_minimum_required(VERSION 3.22)
project(wasm_tests CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(WAMR_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../libs/wamr)
set(WAMR_BUILD_DIR ${WAMR_ROOT}/product-mini/platforms/linux/build)
set(PLUGIN_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../plugin)

add_executable(wasm_poc_test
    wasm_poc.cpp
    include/catch_amalgamated.cpp
)

target_include_directories(wasm_poc_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${WAMR_ROOT}/core/iwasm/include
)

target_link_libraries(wasm_poc_test PRIVATE
    ${WAMR_BUILD_DIR}/libiwasm.a
    pthread
    m
    dl
)

add_executable(wasm_dsp_test
    wasm_dsp_test.cpp
    include/catch_amalgamated.cpp
    ${PLUGIN_ROOT}/src/WasmDSP.cpp
)

target_include_directories(wasm_dsp_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${WAMR_ROOT}/core/iwasm/include
    ${PLUGIN_ROOT}/include
)

target_link_libraries(wasm_dsp_test PRIVATE
    ${WAMR_BUILD_DIR}/libiwasm.a
    pthread
    m
    dl
)

enable_testing()
add_test(NAME wasm_poc_test COMMAND wasm_poc_test)
add_test(NAME wasm_dsp_test COMMAND wasm_dsp_test)

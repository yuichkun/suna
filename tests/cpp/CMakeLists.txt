set(WORKSPACE_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../..)
set(WAMR_ROOT ${WORKSPACE_ROOT}/libs/wamr)
if(APPLE)
    set(WAMR_BUILD_DIR ${WAMR_ROOT}/product-mini/platforms/darwin/build)
else()
    set(WAMR_BUILD_DIR ${WAMR_ROOT}/product-mini/platforms/linux/build)
endif()
set(PLUGIN_ROOT ${WORKSPACE_ROOT}/plugin)

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

add_executable(plugin_test
    plugin_test.cpp
    include/catch_amalgamated.cpp
    ${PLUGIN_ROOT}/src/PluginProcessor.cpp
    ${PLUGIN_ROOT}/src/PluginEditor.cpp
    ${PLUGIN_ROOT}/src/WasmDSP.cpp
)

target_include_directories(plugin_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${PLUGIN_ROOT}/include
    ${WAMR_ROOT}/core/iwasm/include
    ${CMAKE_BINARY_DIR}/plugin/Suna_artefacts/JuceLibraryCode
    ${WORKSPACE_ROOT}/libs/juce/modules
)

target_compile_definitions(plugin_test PRIVATE
    JUCE_STANDALONE_APPLICATION=1
    JUCE_WEB_BROWSER=1
    JUCE_USE_CURL=0
    JUCE_VST3_CAN_REPLACE_VST2=0
)

target_link_libraries(plugin_test PRIVATE
    SunaBinaryData
    ${WAMR_BUILD_DIR}/libiwasm.a
    juce::juce_audio_utils
    juce::juce_gui_extra
    pthread
    m
    dl
)

add_test(NAME wasm_poc_test COMMAND wasm_poc_test)
add_test(NAME wasm_dsp_test COMMAND wasm_dsp_test)
add_test(NAME plugin_test COMMAND plugin_test)

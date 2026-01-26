# Suna Plugin CMakeLists.txt

# WAMR paths
set(WAMR_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../libs/wamr)
set(WAMR_BUILD_DIR ${WAMR_ROOT}/product-mini/platforms/linux/build)

# Add binary data for AOT file
juce_add_binary_data(SunaBinaryData
    HEADER_NAME "SunaBinaryData.h"
    NAMESPACE SunaBinaryData
    SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/resources/suna_dsp.aot"
)

# Add UI BinaryData (for embedded Vue UI)
juce_add_binary_data(SunaUIBinaryData
    HEADER_NAME "UIBinaryData.h"
    NAMESPACE SunaUI
    SOURCES
        "${CMAKE_SOURCE_DIR}/ui/dist/index.html"
)

# Add the plugin
juce_add_plugin(Suna
    COMPANY_NAME "SunaAudio"
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT FALSE
    NEEDS_MIDI_OUTPUT FALSE
    NEEDS_WEB_BROWSER TRUE
    PLUGIN_MANUFACTURER_CODE Suna
    PLUGIN_CODE Suna
    FORMATS AU VST3 Standalone
    PRODUCT_NAME "Suna"
    COPY_PLUGIN_AFTER_BUILD FALSE
)

# Generate JuceHeader.h
juce_generate_juce_header(Suna)

# Source files
target_sources(Suna
    PRIVATE
        src/PluginProcessor.cpp
        src/PluginEditor.cpp
        src/WasmDSP.cpp
)

# Include directories
target_include_directories(Suna
    PRIVATE
        include
        ${WAMR_ROOT}/core/iwasm/include
)

# Link libraries
target_link_libraries(Suna
    PRIVATE
        SunaBinaryData
        SunaUIBinaryData
        ${WAMR_BUILD_DIR}/libiwasm.a
        juce::juce_audio_utils
        juce::juce_gui_extra
        pthread
        m
        dl
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)

# Compile definitions
target_compile_definitions(Suna
    PUBLIC
        JUCE_WEB_BROWSER=1
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
)

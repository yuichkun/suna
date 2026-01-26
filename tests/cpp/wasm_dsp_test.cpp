#define CATCH_CONFIG_MAIN
#include "include/catch_amalgamated.hpp"
#include "suna/WasmDSP.h"
#include <fstream>
#include <vector>
#include <cmath>

static std::vector<uint8_t> loadAOTFile(const char* path) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file) return {};
    auto size = file.tellg();
    file.seekg(0);
    std::vector<uint8_t> buffer(static_cast<size_t>(size));
    file.read(reinterpret_cast<char*>(buffer.data()), size);
    return buffer;
}

TEST_CASE("WasmDSP initialization", "[wasmdsp]") {
    suna::WasmDSP dsp;
    auto aot = loadAOTFile("../../../plugin/resources/suna_dsp.aot");
    REQUIRE(!aot.empty());
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    REQUIRE(dsp.isInitialized());
}

TEST_CASE("WasmDSP double initialization", "[wasmdsp]") {
    suna::WasmDSP dsp;
    auto aot = loadAOTFile("../../../plugin/resources/suna_dsp.aot");
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    REQUIRE(dsp.isInitialized());
}

TEST_CASE("WasmDSP prepareToPlay", "[wasmdsp]") {
    suna::WasmDSP dsp;
    auto aot = loadAOTFile("../../../plugin/resources/suna_dsp.aot");
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    
    dsp.prepareToPlay(44100.0, 512);
    REQUIRE(dsp.isInitialized());
}

TEST_CASE("WasmDSP processBlock passthrough", "[wasmdsp]") {
    suna::WasmDSP dsp;
    auto aot = loadAOTFile("../../../plugin/resources/suna_dsp.aot");
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    
    dsp.prepareToPlay(44100.0, 512);
    dsp.setDelayTime(0.0f);
    dsp.setFeedback(0.0f);
    dsp.setMix(0.0f);
    
    constexpr int numSamples = 64;
    float leftIn[numSamples], rightIn[numSamples];
    float leftOut[numSamples], rightOut[numSamples];
    
    for (int i = 0; i < numSamples; ++i) {
        leftIn[i] = static_cast<float>(i) / numSamples;
        rightIn[i] = static_cast<float>(numSamples - i) / numSamples;
    }
    
    dsp.processBlock(leftIn, rightIn, leftOut, rightOut, numSamples);
    
    for (int i = 0; i < numSamples; ++i) {
        REQUIRE(leftOut[i] == Catch::Approx(leftIn[i]).margin(0.001f));
        REQUIRE(rightOut[i] == Catch::Approx(rightIn[i]).margin(0.001f));
    }
}

TEST_CASE("WasmDSP delay effect", "[wasmdsp]") {
    suna::WasmDSP dsp;
    auto aot = loadAOTFile("../../../plugin/resources/suna_dsp.aot");
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    
    dsp.prepareToPlay(44100.0, 512);
    dsp.setDelayTime(10.0f);
    dsp.setFeedback(0.0f);
    dsp.setMix(1.0f);
    
    constexpr int numSamples = 512;
    float leftIn[numSamples] = {0};
    float rightIn[numSamples] = {0};
    float leftOut[numSamples] = {0};
    float rightOut[numSamples] = {0};
    
    leftIn[0] = 1.0f;
    rightIn[0] = 1.0f;
    
    dsp.processBlock(leftIn, rightIn, leftOut, rightOut, numSamples);
    
    REQUIRE(leftOut[0] == Catch::Approx(0.0f).margin(0.001f));
    
    bool foundDelayedImpulse = false;
    for (int i = 10; i < numSamples; ++i) {
        if (std::abs(leftOut[i]) > 0.5f) {
            foundDelayedImpulse = true;
            break;
        }
    }
    
    if (!foundDelayedImpulse) {
        for (int i = 0; i < numSamples; ++i) {
            leftIn[i] = 0;
            rightIn[i] = 0;
        }
        dsp.processBlock(leftIn, rightIn, leftOut, rightOut, numSamples);
        for (int i = 0; i < numSamples; ++i) {
            if (std::abs(leftOut[i]) > 0.5f) {
                foundDelayedImpulse = true;
                break;
            }
        }
    }
    
    REQUIRE(foundDelayedImpulse);
}

TEST_CASE("WasmDSP parameter setters", "[wasmdsp]") {
    suna::WasmDSP dsp;
    auto aot = loadAOTFile("../../../plugin/resources/suna_dsp.aot");
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    
    dsp.prepareToPlay(44100.0, 512);
    
    dsp.setDelayTime(100.0f);
    dsp.setFeedback(0.5f);
    dsp.setMix(0.7f);
    
    REQUIRE(dsp.isInitialized());
}

TEST_CASE("WasmDSP shutdown and reinitialize", "[wasmdsp]") {
    suna::WasmDSP dsp;
    auto aot = loadAOTFile("../../../plugin/resources/suna_dsp.aot");
    
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    dsp.prepareToPlay(44100.0, 512);
    dsp.shutdown();
    REQUIRE(!dsp.isInitialized());
    
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    REQUIRE(dsp.isInitialized());
}

TEST_CASE("WasmDSP multiple blocks", "[wasmdsp]") {
    suna::WasmDSP dsp;
    auto aot = loadAOTFile("../../../plugin/resources/suna_dsp.aot");
    REQUIRE(dsp.initialize(aot.data(), aot.size()));
    
    dsp.prepareToPlay(44100.0, 256);
    dsp.setDelayTime(50.0f);
    dsp.setFeedback(0.3f);
    dsp.setMix(0.5f);
    
    constexpr int numSamples = 256;
    float leftIn[numSamples], rightIn[numSamples];
    float leftOut[numSamples], rightOut[numSamples];
    
    for (int block = 0; block < 10; ++block) {
        for (int i = 0; i < numSamples; ++i) {
            leftIn[i] = std::sin(2.0f * 3.14159f * 440.0f * (block * numSamples + i) / 44100.0f);
            rightIn[i] = leftIn[i];
        }
        
        dsp.processBlock(leftIn, rightIn, leftOut, rightOut, numSamples);
        
        for (int i = 0; i < numSamples; ++i) {
            REQUIRE(std::isfinite(leftOut[i]));
            REQUIRE(std::isfinite(rightOut[i]));
        }
    }
}

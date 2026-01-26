#define CATCH_CONFIG_MAIN
#include "include/catch_amalgamated.hpp"
#include "../../plugin/src/PluginProcessor.h"

TEST_CASE("PluginProcessor instantiation", "[plugin]") {
    SunaAudioProcessor processor;
    REQUIRE(processor.getName() == "Suna");
    REQUIRE(processor.acceptsMidi() == false);
    REQUIRE(processor.producesMidi() == false);
}

TEST_CASE("PluginProcessor prepareToPlay", "[plugin]") {
    SunaAudioProcessor processor;
    
    // Prepare with typical settings
    processor.prepareToPlay(44100.0, 512);
    
    // Should not crash
    REQUIRE(true);
}

TEST_CASE("PluginProcessor processBlock smoke test", "[plugin]") {
    SunaAudioProcessor processor;
    processor.prepareToPlay(44100.0, 512);
    
    // Create silent input buffer
    juce::AudioBuffer<float> buffer(2, 512);
    buffer.clear();
    juce::MidiBuffer midiBuffer;
    
    // Process
    processor.processBlock(buffer, midiBuffer);
    
    // Verify output is not NaN or Inf
    for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
        auto* data = buffer.getReadPointer(ch);
        for (int i = 0; i < buffer.getNumSamples(); ++i) {
            REQUIRE(std::isfinite(data[i]));
        }
    }
}

TEST_CASE("PluginProcessor parameter changes", "[plugin]") {
    SunaAudioProcessor processor;
    auto& params = processor.getParameters();
    
    // Get parameters via APVTS
    auto* delayTimeParam = params.getParameter("delayTime");
    auto* feedbackParam = params.getParameter("feedback");
    auto* mixParam = params.getParameter("mix");
    
    REQUIRE(delayTimeParam != nullptr);
    REQUIRE(feedbackParam != nullptr);
    REQUIRE(mixParam != nullptr);
    
    // Check default values (normalized 0-1 range)
    // delayTime: 300 / 2000 = 0.15
    // feedback: 30 / 100 = 0.3
    // mix: 50 / 100 = 0.5
    REQUIRE(delayTimeParam->getValue() == Catch::Approx(0.15f).margin(0.01f));
    REQUIRE(feedbackParam->getValue() == Catch::Approx(0.3f).margin(0.01f));
    REQUIRE(mixParam->getValue() == Catch::Approx(0.5f).margin(0.01f));
    
    // Change values (normalized)
    delayTimeParam->setValueNotifyingHost(0.25f);  // 500ms
    feedbackParam->setValueNotifyingHost(0.5f);    // 50%
    mixParam->setValueNotifyingHost(0.75f);        // 75%
    
    REQUIRE(delayTimeParam->getValue() == Catch::Approx(0.25f).margin(0.01f));
    REQUIRE(feedbackParam->getValue() == Catch::Approx(0.5f).margin(0.01f));
    REQUIRE(mixParam->getValue() == Catch::Approx(0.75f).margin(0.01f));
}

TEST_CASE("PluginProcessor state save/restore", "[plugin]") {
    SunaAudioProcessor processor;
    auto& params = processor.getParameters();
    
    // Change parameter
    auto* delayTimeParam = params.getParameter("delayTime");
    delayTimeParam->setValueNotifyingHost(0.5f);  // 1000ms
    
    // Save state
    juce::MemoryBlock state;
    processor.getStateInformation(state);
    REQUIRE(state.getSize() > 0);
    
    // Reset parameter
    delayTimeParam->setValueNotifyingHost(0.15f);  // 300ms
    REQUIRE(delayTimeParam->getValue() == Catch::Approx(0.15f).margin(0.01f));
    
    // Restore state
    processor.setStateInformation(state.getData(), static_cast<int>(state.getSize()));
    
    // Verify restored
    REQUIRE(delayTimeParam->getValue() == Catch::Approx(0.5f).margin(0.01f));
}

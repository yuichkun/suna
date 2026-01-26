#pragma once

#include <JuceHeader.h>
#include "suna/WasmDSP.h"

class SunaAudioProcessor : public juce::AudioProcessor {
public:
    SunaAudioProcessor();
    ~SunaAudioProcessor() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;
    using juce::AudioProcessor::processBlock;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }

    const juce::String getName() const override { return "Suna"; }
    bool acceptsMidi() const override { return false; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 0.0; }

    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram(int) override {}
    const juce::String getProgramName(int) override { return {}; }
    void changeProgramName(int, const juce::String&) override {}

    void getStateInformation(juce::MemoryBlock&) override;
    void setStateInformation(const void*, int) override;

    juce::AudioProcessorValueTreeState& getParameters() { return parameters_; }

private:
    juce::AudioProcessorValueTreeState parameters_;
    
    // Atomic parameter pointers (for fast access in processBlock)
    std::atomic<float>* delayTimeParam_ = nullptr;
    std::atomic<float>* feedbackParam_ = nullptr;
    std::atomic<float>* mixParam_ = nullptr;
    
    static juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();
    
    suna::WasmDSP wasmDSP_;
    bool dspInitialized_ = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SunaAudioProcessor)
};

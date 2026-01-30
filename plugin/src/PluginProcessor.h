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
    bool acceptsMidi() const override { return true; }
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
    suna::WasmDSP& getWasmDSP() { return wasmDSP_; }

private:
    juce::AudioProcessorValueTreeState parameters_;
    
    static juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();
    
    // Raw parameter pointers for efficient processBlock access
    std::atomic<float>* blendXParam_ = nullptr;
    std::atomic<float>* blendYParam_ = nullptr;
    std::atomic<float>* playbackSpeedParam_ = nullptr;
    std::atomic<float>* grainLengthParam_ = nullptr;
    std::atomic<float>* grainDensityParam_ = nullptr;
    std::atomic<float>* freezeParam_ = nullptr;
    
    suna::WasmDSP wasmDSP_;
    bool dspInitialized_ = false;
    
    std::unique_ptr<juce::FileLogger> fileLogger_;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SunaAudioProcessor)
};

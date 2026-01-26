#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "SunaBinaryData.h"

SunaAudioProcessor::SunaAudioProcessor()
    : AudioProcessor(BusesProperties()
                         .withInput("Input", juce::AudioChannelSet::stereo(), true)
                         .withOutput("Output", juce::AudioChannelSet::stereo(), true))
{
    dspInitialized_ = wasmDSP_.initialize(
        reinterpret_cast<const uint8_t*>(SunaBinaryData::suna_dsp_aot),
        SunaBinaryData::suna_dsp_aotSize
    );

    if (!dspInitialized_) {
        DBG("Failed to initialize WasmDSP");
    }
}

SunaAudioProcessor::~SunaAudioProcessor()
{
    wasmDSP_.shutdown();
}

void SunaAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    if (dspInitialized_) {
        wasmDSP_.prepareToPlay(sampleRate, samplesPerBlock);
    }
}

void SunaAudioProcessor::releaseResources()
{
}

void SunaAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&)
{
    juce::ScopedNoDenormals noDenormals;

    auto totalNumInputChannels = getTotalNumInputChannels();
    auto totalNumOutputChannels = getTotalNumOutputChannels();

    for (auto i = totalNumInputChannels; i < totalNumOutputChannels; ++i)
        buffer.clear(i, 0, buffer.getNumSamples());

    if (!dspInitialized_ || buffer.getNumChannels() < 2)
        return;

    const int numSamples = buffer.getNumSamples();
    
    float* leftChannel = buffer.getWritePointer(0);
    float* rightChannel = buffer.getWritePointer(1);

    wasmDSP_.processBlock(leftChannel, rightChannel, leftChannel, rightChannel, numSamples);
}

juce::AudioProcessorEditor* SunaAudioProcessor::createEditor()
{
    return new SunaAudioProcessorEditor(*this);
}

void SunaAudioProcessor::getStateInformation(juce::MemoryBlock&)
{
}

void SunaAudioProcessor::setStateInformation(const void*, int)
{
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new SunaAudioProcessor();
}

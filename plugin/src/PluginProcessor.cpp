#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "SunaBinaryData.h"

SunaAudioProcessor::SunaAudioProcessor()
    : AudioProcessor(BusesProperties()
                         .withInput("Input", juce::AudioChannelSet::stereo(), true)
                         .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
      parameters_(*this, nullptr, "Parameters", createParameterLayout())
{
    // Initialize FileLogger to Desktop
    auto logFile = juce::File::getSpecialLocation(
        juce::File::userDesktopDirectory).getChildFile("suna_debug.log");
    fileLogger_ = std::make_unique<juce::FileLogger>(logFile, "Suna Debug Log");
    juce::Logger::setCurrentLogger(fileLogger_.get());
    
    juce::Logger::writeToLog("SunaAudioProcessor: Constructor started at " + 
        juce::Time::getCurrentTime().toString(true, true, true, true));
    
    delayTimeParam_ = parameters_.getRawParameterValue("delayTime");
    feedbackParam_ = parameters_.getRawParameterValue("feedback");
    mixParam_ = parameters_.getRawParameterValue("mix");
    
    dspInitialized_ = wasmDSP_.initialize(
        reinterpret_cast<const uint8_t*>(SunaBinaryData::suna_dsp_aot),
        SunaBinaryData::suna_dsp_aotSize
    );

    juce::Logger::writeToLog("SunaAudioProcessor: WasmDSP initialized: " + 
        juce::String(dspInitialized_ ? "SUCCESS" : "FAILED"));
}

SunaAudioProcessor::~SunaAudioProcessor()
{
    juce::Logger::writeToLog("SunaAudioProcessor: Destructor");
    juce::Logger::setCurrentLogger(nullptr);
}

void SunaAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    juce::Logger::writeToLog("SunaAudioProcessor::prepareToPlay - sampleRate: " + 
        juce::String(sampleRate) + ", blockSize: " + juce::String(samplesPerBlock));
    
    if (dspInitialized_) {
        wasmDSP_.prepareToPlay(sampleRate, samplesPerBlock);
    }
}

void SunaAudioProcessor::releaseResources()
{
}

void SunaAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&)
{
    static bool firstCall = true;
    if (firstCall) {
        juce::Logger::writeToLog("SunaAudioProcessor::processBlock - First call with " + 
            juce::String(buffer.getNumSamples()) + " samples");
        firstCall = false;
    }
    
    juce::ScopedNoDenormals noDenormals;

    auto totalNumInputChannels = getTotalNumInputChannels();
    auto totalNumOutputChannels = getTotalNumOutputChannels();

    for (auto i = totalNumInputChannels; i < totalNumOutputChannels; ++i)
        buffer.clear(i, 0, buffer.getNumSamples());

    if (!dspInitialized_) {
        buffer.clear();
        return;
    }

    float delayTime = delayTimeParam_->load();
    float feedback = feedbackParam_->load() / 100.0f;
    float mix = mixParam_->load() / 100.0f;

    wasmDSP_.setDelayTime(delayTime);
    wasmDSP_.setFeedback(feedback);
    wasmDSP_.setMix(mix);

    auto* leftChannel = buffer.getWritePointer(0);
    auto* rightChannel = buffer.getNumChannels() > 1 
                         ? buffer.getWritePointer(1) 
                         : leftChannel;

    int numSamples = buffer.getNumSamples();

    wasmDSP_.processBlock(leftChannel, rightChannel, 
                         leftChannel, rightChannel, 
                         numSamples);
}

juce::AudioProcessorEditor* SunaAudioProcessor::createEditor()
{
    return new SunaAudioProcessorEditor(*this);
}

void SunaAudioProcessor::getStateInformation(juce::MemoryBlock& destData)
{
    auto state = parameters_.copyState();
    std::unique_ptr<juce::XmlElement> xml(state.createXml());
    copyXmlToBinary(*xml, destData);
}

void SunaAudioProcessor::setStateInformation(const void* data, int sizeInBytes)
{
    std::unique_ptr<juce::XmlElement> xmlState(getXmlFromBinary(data, sizeInBytes));
    if (xmlState.get() != nullptr && xmlState->hasTagName(parameters_.state.getType())) {
        parameters_.replaceState(juce::ValueTree::fromXml(*xmlState));
    }
}

juce::AudioProcessorValueTreeState::ParameterLayout 
SunaAudioProcessor::createParameterLayout() {
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> params;
    
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "delayTime",
        "Delay Time",
        juce::NormalisableRange<float>(0.0f, 2000.0f, 1.0f),
        300.0f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value, 1) + " ms"; }
    ));
    
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "feedback",
        "Feedback",
        juce::NormalisableRange<float>(0.0f, 100.0f, 0.1f),
        30.0f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value, 1) + " %"; }
    ));
    
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "mix",
        "Mix",
        juce::NormalisableRange<float>(0.0f, 100.0f, 0.1f),
        50.0f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value, 1) + " %"; }
    ));
    
    return { params.begin(), params.end() };
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new SunaAudioProcessor();
}

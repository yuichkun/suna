#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "SunaBinaryData.h"

SunaAudioProcessor::SunaAudioProcessor()
    : AudioProcessor(BusesProperties()
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
    
    // Cache raw parameter pointers for efficient processBlock access
    blendXParam_ = parameters_.getRawParameterValue("blendX");
    blendYParam_ = parameters_.getRawParameterValue("blendY");
    playbackSpeedParam_ = parameters_.getRawParameterValue("playbackSpeed");
    grainLengthParam_ = parameters_.getRawParameterValue("grainLength");
    grainDensityParam_ = parameters_.getRawParameterValue("grainDensity");
    freezeParam_ = parameters_.getRawParameterValue("freeze");
    
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

    if (!dspInitialized_) {
        buffer.clear();
        return;
    }

    // Read all parameters and update DSP
    wasmDSP_.setBlendX(blendXParam_->load());
    wasmDSP_.setBlendY(blendYParam_->load());
    wasmDSP_.setPlaybackSpeed(playbackSpeedParam_->load());
    wasmDSP_.setGrainLength(static_cast<int>(grainLengthParam_->load()));
    wasmDSP_.setGrainDensity(grainDensityParam_->load());
    wasmDSP_.setFreeze(freezeParam_->load() > 0.5f ? 1 : 0);

    // Clear buffer since we have no input bus
    buffer.clear();

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
        "blendX", "Blend X", -1.0f, 1.0f, 0.0f));
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "blendY", "Blend Y", -1.0f, 1.0f, 0.0f));
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "playbackSpeed", "Playback Speed", -2.0f, 2.0f, 1.0f));
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "grainLength", "Grain Length", 100.0f, 44100.0f, 4224.0f));
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "grainDensity", "Grain Density", 0.0f, 1.0f, 0.0f));
    params.push_back(std::make_unique<juce::AudioParameterBool>(
        "freeze", "Freeze", false));
    
    return { params.begin(), params.end() };
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new SunaAudioProcessor();
}

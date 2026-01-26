#include "PluginEditor.h"

SunaAudioProcessorEditor::SunaAudioProcessorEditor(SunaAudioProcessor& p)
    : AudioProcessorEditor(&p), audioProcessor(p)
{
    setSize(400, 300);
}

SunaAudioProcessorEditor::~SunaAudioProcessorEditor()
{
}

void SunaAudioProcessorEditor::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colours::darkgrey);
    g.setColour(juce::Colours::white);
    g.setFont(24.0f);
    g.drawFittedText("Suna Delay", getLocalBounds(), juce::Justification::centred, 1);
}

void SunaAudioProcessorEditor::resized()
{
}

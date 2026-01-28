#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"

class SunaAudioProcessorEditor : public juce::AudioProcessorEditor {
public:
    SunaAudioProcessorEditor(SunaAudioProcessor&);
    ~SunaAudioProcessorEditor() override;

    void paint(juce::Graphics&) override;
    void resized() override;
    
    void visibilityChanged() override;
    void parentHierarchyChanged() override;
    void mouseDown(const juce::MouseEvent&) override;

private:
    SunaAudioProcessor& audioProcessor;
    
    std::unique_ptr<juce::WebBrowserComponent> browser;
    
    std::optional<juce::WebBrowserComponent::Resource> getResource(const juce::String& url);
    void grabWebViewFocusIfSafe();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SunaAudioProcessorEditor)
};

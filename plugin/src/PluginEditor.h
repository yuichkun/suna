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
    
    // Web parameter relays
    std::unique_ptr<juce::WebSliderRelay> blendXRelay_;
    std::unique_ptr<juce::WebSliderRelay> blendYRelay_;
    std::unique_ptr<juce::WebSliderRelay> playbackSpeedRelay_;
    std::unique_ptr<juce::WebSliderRelay> grainLengthRelay_;
    std::unique_ptr<juce::WebSliderRelay> grainDensityRelay_;
    std::unique_ptr<juce::WebToggleButtonRelay> freezeRelay_;
    
    // Web parameter attachments
    std::unique_ptr<juce::WebSliderParameterAttachment> blendXAttachment_;
    std::unique_ptr<juce::WebSliderParameterAttachment> blendYAttachment_;
    std::unique_ptr<juce::WebSliderParameterAttachment> playbackSpeedAttachment_;
    std::unique_ptr<juce::WebSliderParameterAttachment> grainLengthAttachment_;
    std::unique_ptr<juce::WebSliderParameterAttachment> grainDensityAttachment_;
    std::unique_ptr<juce::WebToggleButtonParameterAttachment> freezeAttachment_;
    
    std::optional<juce::WebBrowserComponent::Resource> getResource(const juce::String& url);
    void grabWebViewFocusIfSafe();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SunaAudioProcessorEditor)
};

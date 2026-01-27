#include "PluginEditor.h"

#if !JUCE_DEBUG
#include "UIBinaryData.h"
#endif

SunaAudioProcessorEditor::SunaAudioProcessorEditor(SunaAudioProcessor& p)
    : AudioProcessorEditor(&p), audioProcessor(p)
{
    juce::Logger::writeToLog("SunaAudioProcessorEditor: Constructor started");
    
    delayTimeRelay = std::make_unique<juce::WebSliderRelay>("delayTime");
    feedbackRelay = std::make_unique<juce::WebSliderRelay>("feedback");
    mixRelay = std::make_unique<juce::WebSliderRelay>("mix");
    
    browser = std::make_unique<juce::WebBrowserComponent>(
        juce::WebBrowserComponent::Options{}
            .withNativeIntegrationEnabled()
            .withResourceProvider([this](const auto& url) { return getResource(url); })
            .withKeepPageLoadedWhenBrowserIsHidden()
            .withOptionsFrom(*delayTimeRelay)
            .withOptionsFrom(*feedbackRelay)
            .withOptionsFrom(*mixRelay));
    
    delayTimeAttachment = std::make_unique<juce::WebSliderParameterAttachment>(
        *audioProcessor.getParameters().getParameter("delayTime"),
        *delayTimeRelay,
        nullptr);
    
    feedbackAttachment = std::make_unique<juce::WebSliderParameterAttachment>(
        *audioProcessor.getParameters().getParameter("feedback"),
        *feedbackRelay,
        nullptr);
    
    mixAttachment = std::make_unique<juce::WebSliderParameterAttachment>(
        *audioProcessor.getParameters().getParameter("mix"),
        *mixRelay,
        nullptr);
    
    addAndMakeVisible(*browser);
    
#if JUCE_DEBUG
    browser->goToURL("http://localhost:5173");
#else
    browser->goToURL(juce::WebBrowserComponent::getResourceProviderRoot());
#endif
    
    setSize(400, 350);
    setResizable(true, true);
    
    juce::Logger::writeToLog("SunaAudioProcessorEditor: Constructor complete");
}

SunaAudioProcessorEditor::~SunaAudioProcessorEditor()
{
    juce::Logger::writeToLog("~SunaAudioProcessorEditor: Destructor started");
    
    // Destroy browser first (while relays are still valid)
    browser.reset();
    
    juce::Logger::writeToLog("~SunaAudioProcessorEditor: browser reset complete");
    
    // Relays and attachments will auto-destruct after this
    juce::Logger::writeToLog("~SunaAudioProcessorEditor: Destructor complete");
}

void SunaAudioProcessorEditor::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colours::black);
}

void SunaAudioProcessorEditor::resized()
{
    browser->setBounds(getLocalBounds());
}

std::optional<juce::WebBrowserComponent::Resource> SunaAudioProcessorEditor::getResource(const juce::String& url)
{
#if JUCE_DEBUG
    return std::nullopt;
#else
    if (url == "/" || url == "/index.html")
    {
        return juce::WebBrowserComponent::Resource{
            std::vector<std::byte>(
                reinterpret_cast<const std::byte*>(SunaUI::index_html),
                reinterpret_cast<const std::byte*>(SunaUI::index_html) + SunaUI::index_htmlSize
            ),
            "text/html"
        };
    }
    return std::nullopt;
#endif
}

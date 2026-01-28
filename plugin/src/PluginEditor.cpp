#include "PluginEditor.h"

#if !JUCE_DEBUG
#include "UIBinaryData.h"
#endif

SunaAudioProcessorEditor::SunaAudioProcessorEditor(SunaAudioProcessor& p)
    : AudioProcessorEditor(&p), audioProcessor(p)
{
    juce::Logger::writeToLog("SunaAudioProcessorEditor: Constructor started");
    
    browser = std::make_unique<juce::WebBrowserComponent>(
        juce::WebBrowserComponent::Options{}
            .withNativeIntegrationEnabled()
            .withResourceProvider([this](const auto& url) { return getResource(url); })
            .withKeepPageLoadedWhenBrowserIsHidden()
            .withNativeFunction("loadSample", [this](const auto& params, auto complete) {
                // Expected params from JS: [slot, base64PCM, sampleRate]
                if (params.size() < 3)
                {
                    complete({});
                    return;
                }
                
                int slot = static_cast<int>(params[0]);
                juce::String base64PCM = params[1].toString();
                double sampleRate = static_cast<double>(params[2]);
                
                juce::MemoryOutputStream decoded;
                if (!juce::Base64::convertFromBase64(decoded, base64PCM))
                {
                    juce::Logger::writeToLog("loadSample: Base64 decode failed");
                    complete({});
                    return;
                }
                
                // Convert to float array (assuming 32-bit float PCM)
                const float* floatData = reinterpret_cast<const float*>(decoded.getData());
                size_t numSamples = decoded.getDataSize() / sizeof(float);
                
                audioProcessor.getWasmDSP().loadSample(slot, floatData, numSamples);
                
                juce::Logger::writeToLog("loadSample: Loaded " + juce::String(numSamples) + 
                                         " samples into slot " + juce::String(slot));
                complete(juce::var(true));
            })
            .withNativeFunction("clearSlot", [this](const auto& params, auto complete) {
                // Expected params from JS: [slot]
                if (params.size() < 1)
                {
                    complete({});
                    return;
                }
                
                int slot = static_cast<int>(params[0]);
                audioProcessor.getWasmDSP().clearSlot(slot);
                
                juce::Logger::writeToLog("clearSlot: Cleared slot " + juce::String(slot));
                complete(juce::var(true));
            })
            .withNativeFunction("playAll", [this](const auto& params, auto complete) {
                audioProcessor.getWasmDSP().playAll();
                juce::Logger::writeToLog("playAll: Triggered");
                complete(juce::var(true));
            })
            .withNativeFunction("stopAll", [this](const auto& params, auto complete) {
                audioProcessor.getWasmDSP().stopAll();
                juce::Logger::writeToLog("stopAll: Triggered");
                complete(juce::var(true));
            })
            .withNativeFunction("setBlendX", [this](const auto& params, auto complete) {
                if (params.size() < 1) {
                    complete({});
                    return;
                }
                
                float value = static_cast<float>(params[0]);
                audioProcessor.getWasmDSP().setBlendX(value);
                
                juce::Logger::writeToLog("setBlendX: " + juce::String(value));
                complete(juce::var(true));
            })
            .withNativeFunction("setBlendY", [this](const auto& params, auto complete) {
                if (params.size() < 1) {
                    complete({});
                    return;
                }
                
                float value = static_cast<float>(params[0]);
                audioProcessor.getWasmDSP().setBlendY(value);
                
                juce::Logger::writeToLog("setBlendY: " + juce::String(value));
                complete(juce::var(true));
            }));
    
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
    browser.reset();
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

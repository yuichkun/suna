#include "PluginEditor.h"

#if !JUCE_DEBUG
#include "UIBinaryData.h"
#endif

SunaAudioProcessorEditor::SunaAudioProcessorEditor(SunaAudioProcessor &p)
    : AudioProcessorEditor(&p), audioProcessor(p) {
  juce::Logger::writeToLog("SunaAudioProcessorEditor: Constructor started");

  // Create web parameter relays
  blendXRelay_ = std::make_unique<juce::WebSliderRelay>("blendX");
  blendYRelay_ = std::make_unique<juce::WebSliderRelay>("blendY");
  playbackSpeedRelay_ = std::make_unique<juce::WebSliderRelay>("playbackSpeed");
  grainLengthRelay_ = std::make_unique<juce::WebSliderRelay>("grainLength");
  grainDensityRelay_ = std::make_unique<juce::WebSliderRelay>("grainDensity");
  freezeRelay_ = std::make_unique<juce::WebToggleButtonRelay>("freeze");

  browser = std::make_unique<juce::WebBrowserComponent>(
      juce::WebBrowserComponent::Options{}
          .withNativeIntegrationEnabled()
          .withOptionsFrom(*blendXRelay_)
          .withOptionsFrom(*blendYRelay_)
          .withOptionsFrom(*playbackSpeedRelay_)
          .withOptionsFrom(*grainLengthRelay_)
          .withOptionsFrom(*grainDensityRelay_)
          .withOptionsFrom(*freezeRelay_)
          .withResourceProvider(
              [this](const auto &url) { return getResource(url); })
          .withKeepPageLoadedWhenBrowserIsHidden()
          .withNativeFunction(
              "loadSample",
              [this](const auto &params, auto complete) {
                // Expected params from JS: [slot, base64PCM, sampleRate]
                if (params.size() < 3) {
                  complete({});
                  return;
                }

                int slot = static_cast<int>(params[0]);
                juce::String base64PCM = params[1].toString();
                double sampleRate = static_cast<double>(params[2]);

                juce::MemoryOutputStream decoded;
                if (!juce::Base64::convertFromBase64(decoded, base64PCM)) {
                  juce::Logger::writeToLog("loadSample: Base64 decode failed");
                  complete({});
                  return;
                }

                // Convert to float array (assuming 32-bit float PCM)
                const float *floatData =
                    reinterpret_cast<const float *>(decoded.getData());
                size_t numSamples = decoded.getDataSize() / sizeof(float);

                audioProcessor.getWasmDSP().loadSample(slot, floatData,
                                                       numSamples);

                juce::Logger::writeToLog(
                    "loadSample: Loaded " + juce::String(numSamples) +
                    " samples into slot " + juce::String(slot));
                complete(juce::var(true));
              })
          .withNativeFunction("clearSlot",
                              [this](const auto &params, auto complete) {
                                // Expected params from JS: [slot]
                                if (params.size() < 1) {
                                  complete({});
                                  return;
                                }

                                int slot = static_cast<int>(params[0]);
                                audioProcessor.getWasmDSP().clearSlot(slot);
                                complete(juce::var(true));
                              })
          .withNativeFunction("playAll",
                              [this](const auto &params, auto complete) {
                                audioProcessor.getWasmDSP().playAll();
                                complete(juce::var(true));
                              })
          .withNativeFunction("stopAll",
                              [this](const auto &params, auto complete) {
                                audioProcessor.getWasmDSP().stopAll();
                                complete(juce::var(true));
                              })
          .withNativeFunction("setBlendX",
                              [this](const auto &params, auto complete) {
                                if (params.size() < 1) {
                                  complete({});
                                  return;
                                }

                                float value = static_cast<float>(params[0]);
                                audioProcessor.getWasmDSP().setBlendX(value);
                                complete(juce::var(true));
                              })
          .withNativeFunction("setBlendY",
                              [this](const auto &params, auto complete) {
                                if (params.size() < 1) {
                                  complete({});
                                  return;
                                }

                                float value = static_cast<float>(params[0]);
                                audioProcessor.getWasmDSP().setBlendY(value);
                                complete(juce::var(true));
                              })
          .withNativeFunction("setPlaybackSpeed",
                              [this](const auto &params, auto complete) {
                                if (params.size() < 1) {
                                  complete({});
                                  return;
                                }

                                float speed = static_cast<float>(params[0]);
                                audioProcessor.getWasmDSP().setPlaybackSpeed(
                                    speed);
                                complete(juce::var(true));
                              })
          .withNativeFunction("setGrainLength",
                              [this](const auto &params, auto complete) {
                                if (params.size() < 1) {
                                  complete({});
                                  return;
                                }

                                int length = static_cast<int>(params[0]);
                                audioProcessor.getWasmDSP().setGrainLength(
                                    length);
                                complete(juce::var(true));
                              })
          .withNativeFunction("setGrainDensity",
                              [this](const auto &params, auto complete) {
                                if (params.size() < 1) {
                                  complete({});
                                  return;
                                }

                                float density = static_cast<float>(params[0]);
                                audioProcessor.getWasmDSP().setGrainDensity(
                                    density);
                                complete(juce::var(true));
                              })
          .withNativeFunction("setFreeze",
                              [this](const auto &params, auto complete) {
                                if (params.size() < 1) {
                                  complete({});
                                  return;
                                }

                                int value = static_cast<int>(params[0]);
                                audioProcessor.getWasmDSP().setFreeze(value);
                                complete(juce::var(true));
                              })
          .withNativeFunction("setSpeedTarget",
                              [this](const auto &params, auto complete) {
                                if (params.size() < 1) {
                                  complete({});
                                  return;
                                }

                                float target = static_cast<float>(params[0]);
                                audioProcessor.getWasmDSP().setSpeedTarget(target);
                                complete(juce::var(true));
                              }));

  addAndMakeVisible(*browser);

  // Create web parameter attachments
  blendXAttachment_ = std::make_unique<juce::WebSliderParameterAttachment>(
      *audioProcessor.getParameters().getParameter("blendX"), *blendXRelay_,
      nullptr);
  blendYAttachment_ = std::make_unique<juce::WebSliderParameterAttachment>(
      *audioProcessor.getParameters().getParameter("blendY"), *blendYRelay_,
      nullptr);
  playbackSpeedAttachment_ =
      std::make_unique<juce::WebSliderParameterAttachment>(
          *audioProcessor.getParameters().getParameter("playbackSpeed"),
          *playbackSpeedRelay_, nullptr);
  grainLengthAttachment_ = std::make_unique<juce::WebSliderParameterAttachment>(
      *audioProcessor.getParameters().getParameter("grainLength"),
      *grainLengthRelay_, nullptr);
  grainDensityAttachment_ =
      std::make_unique<juce::WebSliderParameterAttachment>(
          *audioProcessor.getParameters().getParameter("grainDensity"),
          *grainDensityRelay_, nullptr);
  freezeAttachment_ =
      std::make_unique<juce::WebToggleButtonParameterAttachment>(
          *audioProcessor.getParameters().getParameter("freeze"), *freezeRelay_,
          nullptr);

#if JUCE_DEBUG
  browser->goToURL("http://localhost:5173");
#else
  browser->goToURL(juce::WebBrowserComponent::getResourceProviderRoot());
#endif

  setSize(662, 862);
  setResizable(true, true);

  juce::Logger::writeToLog("SunaAudioProcessorEditor: Constructor complete");
}

SunaAudioProcessorEditor::~SunaAudioProcessorEditor() {
  juce::Logger::writeToLog("~SunaAudioProcessorEditor: Destructor started");
  browser.reset();
  juce::Logger::writeToLog("~SunaAudioProcessorEditor: Destructor complete");
}

void SunaAudioProcessorEditor::paint(juce::Graphics &g) {
  g.fillAll(juce::Colours::black);
}

void SunaAudioProcessorEditor::resized() {
  browser->setBounds(getLocalBounds());
}

std::optional<juce::WebBrowserComponent::Resource>
SunaAudioProcessorEditor::getResource(const juce::String &url) {
#if JUCE_DEBUG
  return std::nullopt;
#else
  if (url == "/" || url == "/index.html") {
    return juce::WebBrowserComponent::Resource{
        std::vector<std::byte>(
            reinterpret_cast<const std::byte *>(SunaUI::index_html),
            reinterpret_cast<const std::byte *>(SunaUI::index_html) +
                SunaUI::index_htmlSize),
        "text/html"};
  }
  return std::nullopt;
#endif
}

void SunaAudioProcessorEditor::grabWebViewFocusIfSafe() {
  if (auto *window = getTopLevelComponent()) {
    bool isActive = window->isOnDesktop() &&
                    !window->isCurrentlyBlockedByAnotherModalComponent();
    if (isActive && isShowing() && browser != nullptr) {
      browser->grabKeyboardFocus();
      juce::Logger::writeToLog("WebView focus grabbed");
    }
  }
}

void SunaAudioProcessorEditor::visibilityChanged() {
  AudioProcessorEditor::visibilityChanged();
  if (isVisible()) {
    grabWebViewFocusIfSafe();
  }
}

void SunaAudioProcessorEditor::parentHierarchyChanged() {
  AudioProcessorEditor::parentHierarchyChanged();
  grabWebViewFocusIfSafe();
}

void SunaAudioProcessorEditor::mouseDown(const juce::MouseEvent &event) {
  AudioProcessorEditor::mouseDown(event);
  grabWebViewFocusIfSafe();
}

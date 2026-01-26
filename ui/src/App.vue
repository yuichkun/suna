<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import SliderControl from './components/SliderControl.vue'
import { WebRuntime } from './runtime/WebRuntime'
import type { Runtime } from './runtime/types'

// Detect runtime (JUCE or Web)
const isJuce = ref(false)
let runtime: Runtime | null = null

// Parameter state with defaults
const delayTime = ref(300)
const feedback = ref(30)
const mix = ref(50)

// Update runtime when parameters change
function updateDelayTime(value: number) {
  delayTime.value = value
  runtime?.setDelayTime(value)
}

function updateFeedback(value: number) {
  feedback.value = value
  runtime?.setFeedback(value)
}

function updateMix(value: number) {
  mix.value = value
  runtime?.setMix(value)
}

onMounted(async () => {
  // Check if running in JUCE WebView
  isJuce.value = !!(window as any).juce

  if (!isJuce.value) {
    // Web mode - initialize WebRuntime
    runtime = new WebRuntime()
    try {
      await runtime.initialize()
      // Apply initial parameter values
      runtime.setDelayTime(delayTime.value)
      runtime.setFeedback(feedback.value)
      runtime.setMix(mix.value)
    } catch (e) {
      console.error('Failed to initialize audio:', e)
    }
  }
  // JUCE mode will use WebSliderRelay (handled in PluginEditor)
})

onUnmounted(() => {
  runtime?.destroy()
})
</script>

<template>
  <div class="app">
    <header class="header">
      <div class="logo">
        <span class="logo-text">SUNA</span>
        <span class="logo-sub">DELAY</span>
      </div>
    </header>

    <main class="controls">
      <SliderControl
        :modelValue="delayTime"
        @update:modelValue="updateDelayTime"
        :min="0"
        :max="2000"
        label="Delay Time"
        unit="ms"
      />
      <SliderControl
        :modelValue="feedback"
        @update:modelValue="updateFeedback"
        :min="0"
        :max="100"
        label="Feedback"
        unit="%"
      />
      <SliderControl
        :modelValue="mix"
        @update:modelValue="updateMix"
        :min="0"
        :max="100"
        label="Mix"
        unit="%"
      />
    </main>

    <footer class="footer">
      <span class="runtime-badge" :class="{ juce: isJuce }">
        {{ isJuce ? 'JUCE' : 'WEB' }}
      </span>
    </footer>
  </div>
</template>

<style scoped>
.app {
  --bg-primary: #0d0d14;
  --bg-secondary: #14141e;
  --accent: #628494;
  --accent-glow: rgba(98, 132, 148, 0.3);
  --text-primary: #e8e8ec;
  --text-muted: #5a5a70;

  min-height: 100vh;
  background: var(--bg-primary);
  background-image: 
    radial-gradient(ellipse at 50% 0%, rgba(98, 132, 148, 0.08) 0%, transparent 60%),
    linear-gradient(180deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
  display: flex;
  flex-direction: column;
  padding: 32px 24px;
  max-width: 420px;
  margin: 0 auto;
  font-family: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
}

.header {
  text-align: center;
  margin-bottom: 40px;
}

.logo {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.logo-text {
  font-size: 32px;
  font-weight: 700;
  letter-spacing: 0.3em;
  color: var(--text-primary);
  text-shadow: 0 0 30px var(--accent-glow);
}

.logo-sub {
  font-size: 10px;
  font-weight: 500;
  letter-spacing: 0.5em;
  color: var(--accent);
  text-transform: uppercase;
}

.controls {
  display: flex;
  flex-direction: column;
  gap: 12px;
  flex: 1;
}

.footer {
  display: flex;
  justify-content: center;
  margin-top: 32px;
}

.runtime-badge {
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.15em;
  padding: 6px 14px;
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
  color: var(--text-muted);
  text-transform: uppercase;
}

.runtime-badge.juce {
  color: var(--accent);
  border-color: var(--accent);
  background: rgba(98, 132, 148, 0.1);
  box-shadow: 0 0 12px var(--accent-glow);
}
</style>

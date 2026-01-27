<script setup lang="ts">
import { ref } from 'vue'
import SliderControl from './components/SliderControl.vue'
import { useRuntime } from './composables/useRuntime'

const { runtime, isWeb, isInitialized, initError } = useRuntime()

const fileInput = ref<HTMLInputElement | null>(null)
const fileName = ref<string | null>(null)
const isPlaying = ref(false)
const hasAudio = ref(false)

const handleFileSelect = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file || !runtime.value) return

  try {
    await runtime.value.loadAudioFile?.(file)
    fileName.value = file.name
    hasAudio.value = true
  } catch (e) {
    console.error('Failed to load audio file:', e)
  }
}

const togglePlayback = () => {
  if (!runtime.value) return

  if (isPlaying.value) {
    runtime.value.stop?.()
    isPlaying.value = false
  } else {
    runtime.value.play?.()
    isPlaying.value = true
  }
}

const openFilePicker = () => {
  fileInput.value?.click()
}
</script>

<template>
  <div class="app">
    <header class="header">
      <div class="logo">
        <span class="logo-text">SUNA</span>
        <span class="logo-sub">DELAY</span>
      </div>
    </header>

    <div v-if="isWeb && !isInitialized && !initError" class="init-state">
      <p>Initializing audio engine...</p>
    </div>

    <div v-else-if="initError" class="init-state error">
      <p>Error: {{ initError }}</p>
    </div>

    <template v-else>
      <main class="controls">
        <SliderControl
          parameter-id="delayTime"
          label="Delay Time"
          unit="ms"
        />
        <SliderControl
          parameter-id="feedback"
          label="Feedback"
          unit="%"
        />
        <SliderControl
          parameter-id="mix"
          label="Mix"
          unit="%"
        />
      </main>

      <section v-if="isWeb" class="audio-controls">
        <input
          ref="fileInput"
          type="file"
          accept="audio/*"
          class="file-input"
          @change="handleFileSelect"
        />
        
        <button @click="openFilePicker" class="btn btn-file">
          Choose Audio File
        </button>
        
        <div class="file-info">
          <span v-if="fileName" class="file-name">{{ fileName }}</span>
          <span v-else class="no-file">No file selected</span>
        </div>
        
        <button
          @click="togglePlayback"
          :disabled="!hasAudio"
          class="btn btn-playback"
          :class="{ 'btn-playing': isPlaying, 'btn-disabled': !hasAudio }"
        >
          {{ isPlaying ? 'Stop' : 'Play' }}
        </button>
      </section>
    </template>

    <footer class="footer">
      <span class="runtime-badge" :class="{ juce: !isWeb }">
        {{ isWeb ? 'WEB' : 'JUCE' }}
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

.file-input {
  display: none;
}

.audio-controls {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 24px;
  padding-top: 24px;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
}

.btn {
  padding: 12px 20px;
  border-radius: 6px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  background: rgba(255, 255, 255, 0.03);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 12px;
  font-weight: 500;
  letter-spacing: 0.05em;
  cursor: pointer;
  transition: all 0.2s ease;
  text-transform: uppercase;
}

.btn:hover:not(.btn-disabled) {
  background: rgba(255, 255, 255, 0.08);
  border-color: var(--accent);
  box-shadow: 0 0 12px var(--accent-glow);
}

.btn-disabled {
  opacity: 0.3;
  cursor: not-allowed;
}

.btn-playing {
  background: rgba(98, 132, 148, 0.15);
  border-color: var(--accent);
  color: var(--accent);
}

.file-info {
  text-align: center;
  padding: 8px;
  font-size: 11px;
  color: var(--text-muted);
}

.file-name {
  color: var(--accent);
  font-weight: 500;
}

.no-file {
  font-style: italic;
}

.init-state {
  text-align: center;
  padding: 40px 20px;
  color: var(--text-muted);
  font-size: 12px;
  letter-spacing: 0.05em;
}

.init-state.error {
  color: #e57373;
}
</style>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRuntime } from './composables/useRuntime'
import { useSampler } from './composables/useSampler'
import { useGamepad } from './composables/useGamepad'
import XYPadDisplay from './components/XYPadDisplay.vue'
import WaveformCanvas from './components/WaveformCanvas.vue'

const { runtime, isWeb, isInitialized, initError } = useRuntime()
const { loadedBuffers, loadSample, clearSlot, getNextAvailableSlot, MAX_SAMPLES } = useSampler()
const { isConnected, leftStickX, leftStickY, rightStickX, rightStickY, grainLength, triggerState } = useGamepad()

// Right stick -> blend control
watch([rightStickX, rightStickY], ([x, y]) => {
  runtime.value?.setBlendX?.(x)
  runtime.value?.setBlendY?.(y)
})

// Left stick X -> playback speed: center=1x, right=2x, left=-2x
watch(leftStickX, (x) => {
  const speed = x >= 0 ? 1 + x : 1 + 3 * x
  runtime.value?.setPlaybackSpeed?.(speed)
})

const isDragging = ref(false)

async function onDrop(event: DragEvent) {
  isDragging.value = false
  if (!event.dataTransfer) return

  const files = Array.from(event.dataTransfer.files)
  const audioFiles = files.filter(f =>
    f.type.startsWith('audio/') || /\.(mp3|wav|ogg|flac|aiff|m4a)$/i.test(f.name)
  )

  for (const file of audioFiles) {
    const slot = getNextAvailableSlot()
    if (slot !== null) {
      await loadSample(file, slot)
      const buffer = loadedBuffers.value.get(slot)
      if (buffer && runtime.value) {
        await runtime.value.loadSample?.(slot, buffer.pcmData, buffer.sampleRate)
      }
    }
  }
}

function handleClearSlot(slotIndex: number) {
  clearSlot(slotIndex)
  runtime.value?.clearSlot?.(slotIndex)
}

function getSlotData(index: number) {
  return loadedBuffers.value.get(index)
}
</script>

<template>
  <div class="app">
    <header class="header">
      <div class="logo">
        <span class="logo-text">SUNA</span>
        <span class="logo-sub">SAMPLER</span>
      </div>
    </header>

    <div v-if="isWeb && !isInitialized && !initError" class="init-state">
      <p>Initializing audio engine...</p>
    </div>

    <div v-else-if="initError" class="init-state error">
      <p>Error: {{ initError }}</p>
    </div>

    <template v-else>
      <main class="sampler-container">
        <!-- Drop Zone -->
        <div
          class="drop-zone"
          :class="{ 'drag-over': isDragging }"
          @dragover.prevent
          @dragenter.prevent="isDragging = true"
          @dragleave.prevent="isDragging = false"
          @drop.prevent="onDrop"
        >
          <div class="drop-zone-content">
            <svg class="drop-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M12 4v12m0 0l-4-4m4 4l4-4" stroke-linecap="round" stroke-linejoin="round"/>
              <path d="M4 17v2a2 2 0 002 2h12a2 2 0 002-2v-2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            <span class="drop-text">Drop audio files</span>
            <span class="drop-hint">WAV, MP3, OGG, FLAC</span>
          </div>
        </div>

        <!-- Buffer List -->
        <div class="buffer-list">
          <div
            v-for="index in MAX_SAMPLES"
            :key="index - 1"
            class="buffer-slot"
            :class="{ 'slot-filled': getSlotData(index - 1) }"
          >
            <span class="slot-index">{{ index }}</span>
            <template v-if="getSlotData(index - 1)">
              <div class="slot-content">
                <WaveformCanvas :pcm-data="getSlotData(index - 1)?.pcmData ?? null" />
                <span class="slot-name">{{ getSlotData(index - 1)?.fileName }}</span>
              </div>
              <button
                class="slot-delete"
                @click="handleClearSlot(index - 1)"
                title="Remove sample"
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M18 6L6 18M6 6l12 12" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </button>
            </template>
            <span v-else class="slot-empty">Empty</span>
          </div>
        </div>

        <!-- Controls Row: XYPads + Playback -->
         <div class="controls-row">
           <!-- Left Stick: Speed Control -->
           <div class="pad-group">
             <span class="pad-label">SPEED</span>
             <XYPadDisplay
               :x="leftStickX"
               :y="leftStickY"
               :is-connected="isConnected"
             />
             <span class="pad-value">{{ grainLength }} samples</span>
           </div>

          <!-- Right Stick: Blend Control -->
          <div class="pad-group">
            <span class="pad-label">BLEND</span>
            <XYPadDisplay
              :x="rightStickX"
              :y="rightStickY"
              :is-connected="isConnected"
              :slot-count="loadedBuffers.size"
            />
          </div>

          <!-- Trigger Indicator -->
          <div class="pad-group">
            <span class="pad-label">TRIGGER</span>
            <div class="trigger-indicator" :class="triggerState">
              <span class="trigger-text">{{ triggerState.toUpperCase() }}</span>
            </div>
            <span class="pad-value">LT / RT</span>
          </div>
        </div>
      </main>
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
  --bg-primary: #0a0a0f;
  --bg-secondary: #12121a;
  --bg-tertiary: #1a1a24;
  --accent: #ff6b4a;
  --accent-dim: #cc5540;
  --accent-glow: rgba(255, 107, 74, 0.25);
  --accent-subtle: rgba(255, 107, 74, 0.08);
  --text-primary: #f0f0f4;
  --text-secondary: #a0a0b0;
  --text-muted: #505068;
  --border: rgba(255, 255, 255, 0.06);
  --border-hover: rgba(255, 255, 255, 0.12);

  min-height: 100vh;
  background: var(--bg-primary);
  background-image:
    radial-gradient(ellipse at 30% 0%, rgba(255, 107, 74, 0.04) 0%, transparent 50%),
    radial-gradient(ellipse at 70% 100%, rgba(255, 107, 74, 0.03) 0%, transparent 50%),
    linear-gradient(180deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
  display: flex;
  flex-direction: column;
  padding: 28px 20px;
  margin: 0 auto;
  font-family: 'IBM Plex Mono', 'Fira Code', 'SF Mono', monospace;
}

.header {
  text-align: center;
  margin-bottom: 32px;
}

.logo {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}

.logo-text {
  font-size: 28px;
  font-weight: 600;
  letter-spacing: 0.35em;
  color: var(--text-primary);
  text-shadow: 0 0 40px var(--accent-glow);
}

.logo-sub {
  font-size: 9px;
  font-weight: 500;
  letter-spacing: 0.6em;
  color: var(--accent);
  text-transform: uppercase;
  opacity: 0.9;
}

.sampler-container {
  display: flex;
  width: 500px;
  margin: 0 auto;
  flex-direction: column;
  gap: 16px;
  flex: 1;
}

/* Drop Zone */
.drop-zone {
  position: relative;
  border: 1px dashed var(--border-hover);
  border-radius: 8px;
  padding: 28px 20px;
  background: var(--bg-secondary);
  transition: all 0.2s ease;
  cursor: pointer;
}

.drop-zone::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 8px;
  background: linear-gradient(135deg, var(--accent-subtle) 0%, transparent 60%);
  opacity: 0;
  transition: opacity 0.2s ease;
}

.drop-zone:hover,
.drop-zone.drag-over {
  border-color: var(--accent);
  background: var(--bg-tertiary);
}

.drop-zone:hover::before,
.drop-zone.drag-over::before {
  opacity: 1;
}

.drop-zone.drag-over {
  box-shadow: 0 0 24px var(--accent-glow), inset 0 0 20px var(--accent-subtle);
  transform: scale(1.01);
}

.drop-zone-content {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  z-index: 1;
}

.drop-icon {
  width: 32px;
  height: 32px;
  color: var(--text-muted);
  transition: color 0.2s ease, transform 0.2s ease;
}

.drop-zone:hover .drop-icon,
.drop-zone.drag-over .drop-icon {
  color: var(--accent);
  transform: translateY(-2px);
}

.drop-text {
  font-size: 12px;
  font-weight: 500;
  letter-spacing: 0.08em;
  color: var(--text-secondary);
  text-transform: uppercase;
}

.drop-hint {
  font-size: 10px;
  color: var(--text-muted);
  letter-spacing: 0.05em;
}

/* Buffer List */
.buffer-list {
  display: flex;
  flex-direction: column;
  gap: 4px;
  background: var(--bg-secondary);
  border-radius: 8px;
  padding: 8px;
  border: 1px solid var(--border);
}

.buffer-slot {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 4px;
  background: var(--bg-primary);
  border: 1px solid transparent;
  transition: all 0.15s ease;
}

.buffer-slot.slot-filled {
  border-color: var(--border);
  background: var(--bg-tertiary);
}

.buffer-slot.slot-filled:hover {
  border-color: var(--border-hover);
}

.slot-index {
  font-size: 10px;
  font-weight: 600;
  color: var(--text-muted);
  width: 16px;
  text-align: center;
  flex-shrink: 0;
}

.slot-filled .slot-index {
  color: var(--accent);
}

.slot-content {
  flex: 1;
  position: relative;
  height: 32px;
  display: flex;
  align-items: center;
  overflow: hidden;
}

.slot-name {
  position: relative;
  z-index: 1;
  font-size: 11px;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  letter-spacing: 0.02em;
  text-shadow: 0 1px 2px var(--bg-primary);
}

.slot-empty {
  flex: 1;
  font-size: 11px;
  color: var(--text-muted);
  font-style: italic;
  letter-spacing: 0.02em;
}

.slot-delete {
  width: 22px;
  height: 22px;
  padding: 4px;
  border: none;
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.15s ease;
  flex-shrink: 0;
}

.slot-delete:hover {
  background: rgba(255, 107, 74, 0.15);
  color: var(--accent);
}

.slot-delete svg {
  width: 100%;
  height: 100%;
}

/* Controls Row */
.controls-row {
  display: flex;
  flex-direction: row;
  justify-content: center;
  align-items: flex-start;
  gap: 16px;
  flex-wrap: wrap;
}

.pad-group {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.pad-label {
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.15em;
  color: var(--text-muted);
  text-transform: uppercase;
}

.pad-value {
  font-size: 8px;
  color: var(--text-muted);
  letter-spacing: 0.05em;
  margin-top: 4px;
}

/* Trigger Indicator */
.trigger-indicator {
  width: 60px;
  height: 24px;
  background: var(--bg-primary);
  border: 1px solid var(--border);
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.1s ease;
}

.trigger-indicator.on {
  background: var(--accent);
  border-color: var(--accent);
  box-shadow: 0 0 12px var(--accent-glow);
}

.trigger-indicator.freeze {
  background: #4a9eff;
  border-color: #4a9eff;
  box-shadow: 0 0 12px rgba(74, 158, 255, 0.4);
}

.trigger-text {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.1em;
  color: var(--text-muted);
}

.trigger-indicator.on .trigger-text,
.trigger-indicator.freeze .trigger-text {
  color: var(--bg-primary);
}

/* Footer */
.footer {
  display: flex;
  justify-content: center;
  margin-top: 24px;
}

.runtime-badge {
  font-size: 8px;
  font-weight: 600;
  letter-spacing: 0.2em;
  padding: 5px 12px;
  border-radius: 3px;
  background: rgba(255, 255, 255, 0.02);
  border: 1px solid var(--border);
  color: var(--text-muted);
  text-transform: uppercase;
}

.runtime-badge.juce {
  color: var(--accent);
  border-color: var(--accent-dim);
  background: var(--accent-subtle);
  box-shadow: 0 0 12px var(--accent-glow);
}

/* Init States */
.init-state {
  text-align: center;
  padding: 48px 20px;
  color: var(--text-muted);
  font-size: 11px;
  letter-spacing: 0.06em;
}

.init-state.error {
  color: #ff6b6b;
}
</style>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useParameter } from '../composables/useRuntime';

const props = defineProps<{
  parameterId: string
  label: string
  unit?: string
}>()

// Match kodama-vst: only use normalizedValue, displayValue, setNormalizedValue
const { normalizedValue, displayValue, setNormalizedValue } =
  useParameter(props.parameterId)

// Get parameter state for gesture calls
const parameterState = computed(() => {
  const { runtime } = useParameter(props.parameterId)
  return runtime?.value?.getParameter(props.parameterId) ?? null
})

// Custom drag state (matching kodama-vst KnobControl pattern)
const isDragging = ref(false)
const startX = ref(0)
const startValue = ref(0)

const fillPercent = computed(() => {
  return normalizedValue.value * 100
})

const formattedDisplay = computed(() => {
  return props.unit ? `${displayValue.value} ${props.unit}` : displayValue.value
})

// Match kodama-vst: custom drag handling with window-level listeners
const onMouseDown = (e: MouseEvent) => {
  isDragging.value = true
  startX.value = e.clientX
  startValue.value = normalizedValue.value
  parameterState.value?.sliderDragStarted?.()
  window.addEventListener('mousemove', onMouseMove)
  window.addEventListener('mouseup', onMouseUp)
}

const onMouseMove = (e: MouseEvent) => {
  if (!isDragging.value) return
  
  // Horizontal drag: 200px for full range (adjusted for slider UX)
  const delta = (e.clientX - startX.value) / 200
  const newValue = Math.max(0, Math.min(1, startValue.value + delta))
  setNormalizedValue(newValue)
}

const onMouseUp = () => {
  isDragging.value = false
  parameterState.value?.sliderDragEnded?.()
  window.removeEventListener('mousemove', onMouseMove)
  window.removeEventListener('mouseup', onMouseUp)
}

const onBlur = () => {
  if (isDragging.value) {
    isDragging.value = false
    parameterState.value?.sliderDragEnded?.()
  }
}
</script>

<template>
  <div class="slider-control">
    <div class="slider-header">
      <span class="label">{{ label }}</span>
      <span class="value">{{ formattedDisplay }}</span>
    </div>
    <div 
      class="slider-track-container"
      @mousedown="onMouseDown"
      @blur="onBlur"
    >
      <div class="slider-track">
        <div class="slider-fill" :style="{ width: `${fillPercent}%` }"></div>
      </div>
      <div 
        class="slider-thumb" 
        :style="{ left: `${fillPercent}%` }"
      ></div>
    </div>
  </div>
</template>

<style scoped>
.slider-control {
  --slider-bg: #1a1a24;
  --slider-track: #2a2a3a;
  --slider-fill: #628494;
  --slider-fill-glow: rgba(98, 132, 148, 0.4);
  --slider-thumb: #8ab4c4;
  --text-primary: #e8e8ec;
  --text-secondary: #8888a0;
  
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 16px 20px;
  background: var(--slider-bg);
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.05);
  user-select: none;
}

.slider-header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
}

.label {
  font-family: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-secondary);
}

.value {
  font-family: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
  text-shadow: 0 0 8px var(--slider-fill-glow);
}

.slider-track-container {
  position: relative;
  height: 20px;
  cursor: grab;
  display: flex;
  align-items: center;
}

.slider-track-container:active {
  cursor: grabbing;
}

.slider-track {
  position: absolute;
  top: 50%;
  left: 0;
  right: 0;
  height: 8px;
  transform: translateY(-50%);
  background: var(--slider-track);
  border-radius: 4px;
  overflow: hidden;
}

.slider-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--slider-fill), var(--slider-thumb));
  border-radius: 4px;
  box-shadow: 0 0 12px var(--slider-fill-glow);
}

.slider-thumb {
  position: absolute;
  top: 50%;
  width: 18px;
  height: 18px;
  transform: translate(-50%, -50%);
  background: var(--slider-thumb);
  border-radius: 50%;
  box-shadow: 
    0 0 0 3px var(--slider-bg),
    0 0 16px var(--slider-fill-glow),
    0 2px 8px rgba(0, 0, 0, 0.4);
  transition: transform 0.1s ease, box-shadow 0.15s ease;
  pointer-events: none;
}

.slider-track-container:hover .slider-thumb {
  transform: translate(-50%, -50%) scale(1.1);
  box-shadow: 
    0 0 0 3px var(--slider-bg),
    0 0 24px var(--slider-fill-glow),
    0 2px 12px rgba(0, 0, 0, 0.5);
}

.slider-track-container:active .slider-thumb {
  transform: translate(-50%, -50%) scale(1.05);
}
</style>

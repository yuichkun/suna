<script setup lang="ts">
import { computed } from 'vue'
import { useParameter } from '@/composables/useRuntime'

const props = defineProps<{
  parameterId: string
  min: number
  max: number
  label: string
  unit?: string
}>()

const { normalizedValue, displayValue, setNormalizedValue } =
  useParameter(props.parameterId)

const sliderValue = computed(() => {
  return normalizedValue.value * (props.max - props.min) + props.min
})

const fillPercent = computed(() => {
  return normalizedValue.value * 100
})

const formattedDisplay = computed(() => {
  return props.unit ? `${displayValue.value} ${props.unit}` : displayValue.value
})

function onInput(event: Event) {
  const target = event.target as HTMLInputElement
  const value = parseFloat(target.value)
  const normalized = (value - props.min) / (props.max - props.min)
  setNormalizedValue(normalized)
}
</script>

<template>
  <div class="slider-control">
    <div class="slider-header">
      <span class="label">{{ label }}</span>
      <span class="value">{{ formattedDisplay }}</span>
    </div>
    <div class="slider-track-container">
      <div class="slider-track">
        <div class="slider-fill" :style="{ width: `${fillPercent}%` }"></div>
      </div>
      <input
        type="range"
        :min="min"
        :max="max"
        :value="sliderValue"
        step="0.1"
        @input="onInput"
      />
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
  height: 8px;
}

.slider-track {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 8px;
  background: var(--slider-track);
  border-radius: 4px;
  overflow: hidden;
}

.slider-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--slider-fill), var(--slider-thumb));
  border-radius: 4px;
  box-shadow: 0 0 12px var(--slider-fill-glow);
  transition: width 0.05s ease-out;
}

input[type="range"] {
  position: absolute;
  top: -6px;
  left: 0;
  width: 100%;
  height: 20px;
  -webkit-appearance: none;
  appearance: none;
  background: transparent;
  cursor: pointer;
  margin: 0;
}

input[type="range"]::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 18px;
  height: 18px;
  background: var(--slider-thumb);
  border-radius: 50%;
  cursor: grab;
  box-shadow: 
    0 0 0 3px var(--slider-bg),
    0 0 16px var(--slider-fill-glow),
    0 2px 8px rgba(0, 0, 0, 0.4);
  transition: transform 0.1s ease, box-shadow 0.15s ease;
}

input[type="range"]::-webkit-slider-thumb:hover {
  transform: scale(1.1);
  box-shadow: 
    0 0 0 3px var(--slider-bg),
    0 0 24px var(--slider-fill-glow),
    0 2px 12px rgba(0, 0, 0, 0.5);
}

input[type="range"]::-webkit-slider-thumb:active {
  cursor: grabbing;
  transform: scale(1.05);
}

input[type="range"]::-moz-range-thumb {
  width: 18px;
  height: 18px;
  background: var(--slider-thumb);
  border: none;
  border-radius: 50%;
  cursor: grab;
  box-shadow: 
    0 0 0 3px var(--slider-bg),
    0 0 16px var(--slider-fill-glow),
    0 2px 8px rgba(0, 0, 0, 0.4);
}

input[type="range"]::-moz-range-track {
  background: transparent;
  height: 8px;
}

input[type="range"]:focus {
  outline: none;
}

input[type="range"]:focus-visible::-webkit-slider-thumb {
  box-shadow: 
    0 0 0 3px var(--slider-bg),
    0 0 0 5px var(--slider-fill),
    0 0 24px var(--slider-fill-glow);
}
</style>

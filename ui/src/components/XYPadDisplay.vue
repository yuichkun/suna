<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  x: number
  y: number
  isConnected: boolean
}

const props = defineProps<Props>()

// Pad dimensions
const PAD_SIZE = 200
const MARGIN = 10
const USABLE_RANGE = PAD_SIZE / 2 - MARGIN // 90px from center

// Map x/y (-1 to 1) to pixel coordinates
// Center is at (100, 100), edges at 10px and 190px
const cursorX = computed(() => {
  return PAD_SIZE / 2 + props.x * USABLE_RANGE
})

const cursorY = computed(() => {
  // Invert Y: positive Y should move cursor UP (lower pixel value)
  return PAD_SIZE / 2 - props.y * USABLE_RANGE
})
</script>

<template>
  <div class="xy-pad-container">
    <div class="connection-indicator" :class="{ connected: isConnected }">
      <span class="indicator-dot"></span>
      <span class="indicator-text">{{ isConnected ? 'Connected' : 'Disconnected' }}</span>
    </div>
    
    <div class="xy-pad">
      <!-- Grid lines for visual depth -->
      <div class="grid-line grid-h-1"></div>
      <div class="grid-line grid-h-2"></div>
      <div class="grid-line grid-v-1"></div>
      <div class="grid-line grid-v-2"></div>
      
      <!-- Center crosshair -->
      <div class="crosshair crosshair-h"></div>
      <div class="crosshair crosshair-v"></div>
      
      <!-- Position cursor -->
      <div 
        class="cursor" 
        :class="{ active: isConnected }"
        :style="{ 
          left: `${cursorX}px`, 
          top: `${cursorY}px` 
        }"
      >
        <div class="cursor-inner"></div>
      </div>
      
      <!-- Corner markers -->
      <div class="corner corner-tl"></div>
      <div class="corner corner-tr"></div>
      <div class="corner corner-bl"></div>
      <div class="corner corner-br"></div>
    </div>
    
    <!-- Coordinate readout -->
    <div class="coord-readout">
      <span class="coord">X: {{ x.toFixed(2) }}</span>
      <span class="coord">Y: {{ y.toFixed(2) }}</span>
    </div>
  </div>
</template>

<style scoped>
.xy-pad-container {
  --pad-bg: #0d0d12;
  --pad-border: #2a2a3a;
  --pad-grid: rgba(255, 255, 255, 0.03);
  --crosshair: rgba(255, 107, 74, 0.15);
  --cursor-color: #ff6b4a;
  --cursor-glow: rgba(255, 107, 74, 0.4);
  --text-primary: #e8e8ec;
  --text-secondary: #8888a0;
  --text-muted: #505068;
  --connected: #4ade80;
  --disconnected: #666;
  
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 16px;
  background: #12121a;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.05);
}

.connection-indicator {
  display: flex;
  align-items: center;
  gap: 6px;
  font-family: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
  font-size: 10px;
  font-weight: 500;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--disconnected);
  transition: color 0.2s ease;
}

.connection-indicator.connected {
  color: var(--connected);
}

.indicator-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--disconnected);
  transition: background 0.2s ease, box-shadow 0.2s ease;
}

.connection-indicator.connected .indicator-dot {
  background: var(--connected);
  box-shadow: 0 0 8px var(--connected);
}

.xy-pad {
  position: relative;
  width: 200px;
  height: 200px;
  background: var(--pad-bg);
  border: 1px solid var(--pad-border);
  border-radius: 6px;
  overflow: hidden;
  box-shadow: 
    inset 0 0 40px rgba(0, 0, 0, 0.5),
    0 4px 20px rgba(0, 0, 0, 0.3);
}

/* Grid lines for depth */
.grid-line {
  position: absolute;
  background: var(--pad-grid);
}

.grid-h-1, .grid-h-2 {
  left: 0;
  right: 0;
  height: 1px;
}

.grid-v-1, .grid-v-2 {
  top: 0;
  bottom: 0;
  width: 1px;
}

.grid-h-1 { top: 25%; }
.grid-h-2 { top: 75%; }
.grid-v-1 { left: 25%; }
.grid-v-2 { left: 75%; }

/* Center crosshair */
.crosshair {
  position: absolute;
  background: var(--crosshair);
}

.crosshair-h {
  top: 50%;
  left: 0;
  right: 0;
  height: 1px;
  transform: translateY(-0.5px);
}

.crosshair-v {
  left: 50%;
  top: 0;
  bottom: 0;
  width: 1px;
  transform: translateX(-0.5px);
}

/* Corner markers */
.corner {
  position: absolute;
  width: 8px;
  height: 8px;
  border-color: rgba(255, 255, 255, 0.08);
  border-style: solid;
  border-width: 0;
}

.corner-tl {
  top: 8px;
  left: 8px;
  border-top-width: 1px;
  border-left-width: 1px;
}

.corner-tr {
  top: 8px;
  right: 8px;
  border-top-width: 1px;
  border-right-width: 1px;
}

.corner-bl {
  bottom: 8px;
  left: 8px;
  border-bottom-width: 1px;
  border-left-width: 1px;
}

.corner-br {
  bottom: 8px;
  right: 8px;
  border-bottom-width: 1px;
  border-right-width: 1px;
}

/* Position cursor */
.cursor {
  position: absolute;
  width: 20px;
  height: 20px;
  transform: translate(-50%, -50%);
  pointer-events: none;
  transition: opacity 0.2s ease;
}

.cursor::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: var(--cursor-color);
  opacity: 0.15;
  transform: scale(1.5);
}

.cursor-inner {
  position: absolute;
  inset: 4px;
  border-radius: 50%;
  background: var(--cursor-color);
  border: 2px solid rgba(255, 255, 255, 0.9);
  box-shadow: 
    0 0 12px var(--cursor-glow),
    0 0 24px var(--cursor-glow);
  transition: transform 0.1s ease, box-shadow 0.2s ease;
}

.cursor.active .cursor-inner {
  box-shadow: 
    0 0 16px var(--cursor-glow),
    0 0 32px var(--cursor-glow);
}

/* Coordinate readout */
.coord-readout {
  display: flex;
  gap: 16px;
  font-family: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
  font-size: 11px;
  color: var(--text-muted);
  letter-spacing: 0.04em;
}

.coord {
  min-width: 60px;
}
</style>

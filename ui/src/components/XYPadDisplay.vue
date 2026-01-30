<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  x: number
  y: number
  isConnected: boolean
  slotCount?: number
}

const props = withDefaults(defineProps<Props>(), {
  slotCount: 0
})

// Pad dimensions
const PAD_SIZE = 200
const RADIUS = PAD_SIZE / 2 - 10 // 90px radius for usable area

// Map x/y (-1 to 1) to pixel coordinates
const cursorX = computed(() => {
  return PAD_SIZE / 2 + props.x * RADIUS
})

const cursorY = computed(() => {
  // Invert Y: positive Y should move cursor UP (lower pixel value)
  return PAD_SIZE / 2 - props.y * RADIUS
})

// Calculate slot marker positions on the circle
const slotMarkers = computed(() => {
  if (props.slotCount <= 0) return []
  
  const markers = []
  for (let i = 0; i < props.slotCount; i++) {
    const angle = (2 * Math.PI * i) / props.slotCount
    markers.push({
      x: PAD_SIZE / 2 + Math.cos(angle) * RADIUS,
      y: PAD_SIZE / 2 - Math.sin(angle) * RADIUS, // Invert Y for screen coords
      index: i
    })
  }
  return markers
})
</script>

<template>
  <div class="xy-pad-container">
    <div class="connection-indicator" :class="{ connected: isConnected }">
      <span class="indicator-dot"></span>
      <span class="indicator-text">{{ isConnected ? 'Connected' : 'Disconnected' }}</span>
    </div>
    
    <div class="xy-pad">
      <!-- Circle boundary -->
      <div class="circle-boundary"></div>
      
      <!-- Center crosshair -->
      <div class="crosshair crosshair-h"></div>
      <div class="crosshair crosshair-v"></div>
      
      <!-- Slot markers on circle -->
      <div
        v-for="marker in slotMarkers"
        :key="marker.index"
        class="slot-marker"
        :style="{
          left: `${marker.x}px`,
          top: `${marker.y}px`
        }"
      >
        <span class="slot-marker-label">{{ marker.index + 1 }}</span>
      </div>
      
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
  --circle-border: rgba(255, 255, 255, 0.1);
  --crosshair: rgba(255, 107, 74, 0.15);
  --cursor-color: #ff6b4a;
  --cursor-glow: rgba(255, 107, 74, 0.4);
  --text-primary: #e8e8ec;
  --text-secondary: #8888a0;
  --text-muted: #505068;
  --connected: #4ade80;
  --disconnected: #666;
  --marker-color: rgba(255, 255, 255, 0.4);
  
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
  border-radius: 50%;
  overflow: hidden;
  box-shadow: 
    inset 0 0 40px rgba(0, 0, 0, 0.5),
    0 4px 20px rgba(0, 0, 0, 0.3);
}

/* Circle boundary showing usable range */
.circle-boundary {
  position: absolute;
  top: 10px;
  left: 10px;
  right: 10px;
  bottom: 10px;
  border: 1px solid var(--circle-border);
  border-radius: 50%;
  pointer-events: none;
}

/* Center crosshair */
.crosshair {
  position: absolute;
  background: var(--crosshair);
}

.crosshair-h {
  top: 50%;
  left: 10px;
  right: 10px;
  height: 1px;
  transform: translateY(-0.5px);
}

.crosshair-v {
  left: 50%;
  top: 10px;
  bottom: 10px;
  width: 1px;
  transform: translateX(-0.5px);
}

/* Slot markers on circle */
.slot-marker {
  position: absolute;
  width: 20px;
  height: 20px;
  transform: translate(-50%, -50%);
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.slot-marker::before {
  content: '';
  position: absolute;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--marker-color);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.slot-marker-label {
  position: absolute;
  font-family: 'JetBrains Mono', 'SF Mono', monospace;
  font-size: 8px;
  font-weight: 600;
  color: var(--text-muted);
  top: -12px;
}

/* Position cursor */
.cursor {
  position: absolute;
  width: 20px;
  height: 20px;
  transform: translate(-50%, -50%);
  pointer-events: none;
  transition: opacity 0.2s ease;
  z-index: 10;
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

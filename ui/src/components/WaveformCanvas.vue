<script setup lang="ts">
import { ref, watch, onMounted } from 'vue'

const props = defineProps<{
  pcmData: Float32Array | null
}>()

const canvasRef = ref<HTMLCanvasElement | null>(null)

function drawWaveform() {
  const canvas = canvasRef.value
  if (!canvas || !props.pcmData || props.pcmData.length === 0) {
    return
  }

  const ctx = canvas.getContext('2d')
  if (!ctx) return

  // Get actual display size
  const rect = canvas.getBoundingClientRect()
  const width = rect.width
  const height = rect.height

  // Set canvas resolution to match display size (for crisp rendering)
  const dpr = window.devicePixelRatio || 1
  canvas.width = width * dpr
  canvas.height = height * dpr
  ctx.scale(dpr, dpr)

  // Clear canvas
  ctx.clearRect(0, 0, width, height)

  const pcm = props.pcmData
  const samplesPerPixel = pcm.length / width

  const accentColor = '#493e3c'
  ctx.strokeStyle = accentColor
  ctx.lineWidth = 1

  const centerY = height / 2

  ctx.beginPath()

  for (let x = 0; x < width; x++) {
    const startSample = Math.floor(x * samplesPerPixel)
    const endSample = Math.floor((x + 1) * samplesPerPixel)

    // Find min/max in this sample range
    let min = 0
    let max = 0
    for (let i = startSample; i < endSample && i < pcm.length; i++) {
      const sample = pcm[i]
      if (sample < min) min = sample
      if (sample > max) max = sample
    }

    // Scale to canvas height (amplitude -1 to 1 -> 0 to height)
    const yMin = centerY - max * centerY * 0.9
    const yMax = centerY - min * centerY * 0.9

    // Draw vertical line from min to max
    ctx.moveTo(x + 0.5, yMin)
    ctx.lineTo(x + 0.5, yMax)
  }

  ctx.stroke()
}

onMounted(() => {
  drawWaveform()
})

watch(() => props.pcmData, () => {
  drawWaveform()
}, { immediate: true })

// Redraw on resize
let resizeObserver: ResizeObserver | null = null
onMounted(() => {
  if (canvasRef.value) {
    resizeObserver = new ResizeObserver(() => {
      drawWaveform()
    })
    resizeObserver.observe(canvasRef.value)
  }
})
</script>

<template>
  <canvas ref="canvasRef" class="waveform-canvas" />
</template>

<style scoped>
.waveform-canvas {
  --accent: #ff6b4a;
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
}
</style>

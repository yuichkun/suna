import { ref } from 'vue'
import type { Ref } from 'vue'

export const MAX_SAMPLES = 8
export const MAX_SAMPLE_LENGTH = 1440000

export interface LoadedBuffer {
  pcmData: Float32Array
  fileName: string
  sampleRate: number
  duration: number
}

const loadedBuffers: Ref<Map<number, LoadedBuffer>> = ref(new Map())
const isPlaying: Ref<boolean> = ref(false)
const loadTimestamps: Map<number, number> = new Map()

function extractMonoPCM(audioBuffer: AudioBuffer): Float32Array {
  if (audioBuffer.numberOfChannels === 1) {
    return audioBuffer.getChannelData(0)
  }

  const left = audioBuffer.getChannelData(0)
  const right = audioBuffer.getChannelData(1)
  const mono = new Float32Array(audioBuffer.length)

  for (let i = 0; i < audioBuffer.length; i++) {
    mono[i] = (left[i] + right[i]) / 2
  }

  return mono
}

async function decodeAudioFile(file: File): Promise<{ pcmData: Float32Array; sampleRate: number; duration: number }> {
  const audioContext = new AudioContext()
  try {
    const arrayBuffer = await file.arrayBuffer()
    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer)
    const pcmData = extractMonoPCM(audioBuffer)

    return {
      pcmData,
      sampleRate: audioBuffer.sampleRate,
      duration: audioBuffer.duration,
    }
  } finally {
    await audioContext.close()
  }
}

function getNextAvailableSlot(): number | null {
  for (let i = 0; i < MAX_SAMPLES; i++) {
    if (!loadedBuffers.value.has(i)) {
      return i
    }
  }

  let oldestSlot = 0
  let oldestTime = Infinity

  for (let i = 0; i < MAX_SAMPLES; i++) {
    const timestamp = loadTimestamps.get(i) ?? 0
    if (timestamp < oldestTime) {
      oldestTime = timestamp
      oldestSlot = i
    }
  }

  return oldestSlot
}

async function loadSample(file: File, slotIndex: number): Promise<void> {
  if (slotIndex < 0 || slotIndex >= MAX_SAMPLES) {
    throw new Error(`Invalid slot index: ${slotIndex}. Must be 0-${MAX_SAMPLES - 1}`)
  }

  const { pcmData, sampleRate } = await decodeAudioFile(file)

  const truncatedPcm = pcmData.length > MAX_SAMPLE_LENGTH
    ? pcmData.slice(0, MAX_SAMPLE_LENGTH)
    : pcmData

  const buffer: LoadedBuffer = {
    pcmData: truncatedPcm,
    fileName: file.name,
    sampleRate,
    duration: truncatedPcm.length / sampleRate,
  }

  const newMap = new Map(loadedBuffers.value)
  newMap.set(slotIndex, buffer)
  loadedBuffers.value = newMap
  loadTimestamps.set(slotIndex, Date.now())
}

function clearSlot(slotIndex: number): void {
  if (slotIndex < 0 || slotIndex >= MAX_SAMPLES) {
    return
  }

  const newMap = new Map(loadedBuffers.value)
  newMap.delete(slotIndex)
  loadedBuffers.value = newMap
  loadTimestamps.delete(slotIndex)
}

function play(): void {
  isPlaying.value = true
}

function stop(): void {
  isPlaying.value = false
}

export function useSampler() {
  return {
    loadedBuffers,
    isPlaying,
    loadSample,
    clearSlot,
    getNextAvailableSlot,
    play,
    stop,
    decodeAudioFile,
    extractMonoPCM,
    MAX_SAMPLES,
    MAX_SAMPLE_LENGTH,
  }
}

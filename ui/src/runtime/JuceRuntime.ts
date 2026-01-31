import type { AudioRuntime, ParameterState } from './types'
import { getSliderState, getNativeFunction } from '../juce/index.js'

function encodeFloat32ToBase64(float32Array: Float32Array): string {
  const uint8Array = new Uint8Array(float32Array.buffer)
  let binary = ''
  for (let i = 0; i < uint8Array.length; i++) {
    binary += String.fromCharCode(uint8Array[i])
  }
  return btoa(binary)
}

export class JuceRuntime implements AudioRuntime {
  readonly type = 'juce' as const

  getParameter(id: string): ParameterState | null {
    if (typeof window === 'undefined' || !window.__JUCE__) return null

    const sliderState = getSliderState(id)
    if (!sliderState) return null

    return {
      getNormalisedValue: () => sliderState.getNormalisedValue(),
      setNormalisedValue: (value: number) => sliderState.setNormalisedValue(value),
      getScaledValue: () => sliderState.getScaledValue(),
      setScaledValue: (value: number) => sliderState.setScaledValue(value),
      properties: sliderState.properties,
      onValueChanged: (callback: (value: number) => void) => {
        const listenerId = sliderState.valueChangedEvent.addListener(() => {
          callback(sliderState.getNormalisedValue())
        })
        return () => {
          sliderState.valueChangedEvent.removeListener(listenerId)
        }
      },
      sliderDragStarted: () => sliderState.sliderDragStarted(),
      sliderDragEnded: () => sliderState.sliderDragEnded(),
    }
  }

  setParameter(id: string, value: number): void {
    const param = this.getParameter(id)
    param?.setScaledValue(value)
  }

  async loadAudioFile(): Promise<void> {}
  play(): void {}
  stop(): void {}
  getIsPlaying(): boolean { return false }
  hasAudioLoaded(): boolean { return false }
  dispose(): void {}

  async loadSample(slot: number, pcmData: Float32Array, sampleRate: number): Promise<void> {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    const base64String = encodeFloat32ToBase64(pcmData)
    await getNativeFunction('loadSample')(slot, base64String, sampleRate)
  }

  clearSlot(slot: number): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('clearSlot')(slot)
  }

  playAll(): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('playAll')()
  }

  stopAll(): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('stopAll')()
  }

  setBlendX(value: number): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('setBlendX')(value)
  }

  setBlendY(value: number): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('setBlendY')(value)
  }

  setPlaybackSpeed(speed: number): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('setPlaybackSpeed')(speed)
  }

  setGrainLength(length: number): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('setGrainLength')(length)
  }

  setGrainDensity(density: number): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('setGrainDensity')(density)
  }

  setFreeze(freeze: boolean): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('setFreeze')(freeze ? 1 : 0)
  }

  setSpeedTarget(target: number): void {
    if (typeof window === 'undefined' || !window.__JUCE__) return
    getNativeFunction('setSpeedTarget')(target)
  }
}

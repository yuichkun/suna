import type { AudioRuntime, ParameterState } from './types'
import { getSliderState } from '../juce/index.js'

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
}

interface SliderState {
  getNormalisedValue(): number
  setNormalisedValue(value: number): void
  getScaledValue(): number
  setScaledValue(value: number): void
  properties: {
    start: number
    end: number
    skew: number
    name: string
    label: string
    numSteps: number
    interval: number
    parameterIndex: number
  }
  valueChangedCallback: ((value: number) => void) | null
}

interface ToggleState {
  getValue(): boolean
  setValue(value: boolean): void
  valueChangedCallback: ((value: boolean) => void) | null
}

interface Backend {
  addEventListener(eventId: string, callback: (data: unknown) => void): () => void
  emitEvent(eventId: string, data: unknown): void
}

interface JuceInterface {
  backend: Backend
  initialisationData: Record<string, unknown>
  getSliderState(name: string): SliderState
  getToggleState(name: string): ToggleState
}

declare global {
  interface Window {
    __JUCE__: JuceInterface
  }
}

export type { SliderState, ToggleState, Backend, JuceInterface }

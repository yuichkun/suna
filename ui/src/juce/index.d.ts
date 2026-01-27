export interface SliderState {
  getNormalisedValue(): number
  setNormalisedValue(value: number): void
  getScaledValue(): number
  setScaledValue(value: number): void
  sliderDragStarted(): void
  sliderDragEnded(): void
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
  valueChangedEvent: {
    addListener(fn: () => void): number
    removeListener(id: number): void
  }
  propertiesChangedEvent: {
    addListener(fn: () => void): number
    removeListener(id: number): void
  }
}

export function getSliderState(name: string): SliderState
export function getToggleState(name: string): unknown
export function getComboBoxState(name: string): unknown
export function getNativeFunction(name: string): (...args: unknown[]) => Promise<unknown>
export function getBackendResourceAddress(path: string): string

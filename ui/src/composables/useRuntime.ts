import { ref, shallowRef, onMounted, onUnmounted, computed, watch } from 'vue'
import type { AudioRuntime, ParameterState } from '../runtime/types'

const runtime = shallowRef<AudioRuntime | null>(null)
const isInitialized = ref(false)
const initError = ref<string | null>(null)
let isInitializing = false

export function useRuntime() {
  const isWeb = import.meta.env.VITE_RUNTIME === 'web'

  onMounted(async () => {
    if (runtime.value || isInitializing) return
    isInitializing = true

    try {
      if (isWeb) {
        const { WebRuntime } = await import('../runtime/WebRuntime')
        const webRuntime = new WebRuntime()
        await webRuntime.initialize()
        runtime.value = webRuntime as unknown as AudioRuntime
      } else {
        const { JuceRuntime } = await import('../runtime/JuceRuntime')
        runtime.value = new JuceRuntime()
      }
      isInitialized.value = true
    } catch (e) {
      initError.value = e instanceof Error ? e.message : 'Unknown error'
    }
  })

  return {
    runtime: computed(() => runtime.value),
    isWeb,
    isInitialized,
    initError,
  }
}

export function useParameter(parameterId: string) {
  const normalizedValue = ref(0)
  const scaledValue = ref(0)
  const properties = ref<ParameterState['properties'] | null>(null)
  let unsubscribe: (() => void) | null = null

  const { runtime: runtimeRef, isInitialized } = useRuntime()

  const updateFromRuntime = () => {
    const rt = runtimeRef.value
    if (!rt) return

    const param = rt.getParameter(parameterId)
    if (!param) return

    normalizedValue.value = param.getNormalisedValue()
    scaledValue.value = param.getScaledValue()
    properties.value = param.properties

    unsubscribe?.()
    unsubscribe = param.onValueChanged((newNormalized: number) => {
      normalizedValue.value = newNormalized
      scaledValue.value = param.getScaledValue()
    })
  }

  watch(isInitialized, (newVal) => {
    if (newVal) {
      updateFromRuntime()
    }
  }, { immediate: true })

  onUnmounted(() => {
    unsubscribe?.()
  })

  const setNormalizedValue = (value: number) => {
    const rt = runtimeRef.value
    if (!rt) return

    const param = rt.getParameter(parameterId)
    param?.setNormalisedValue(value)
  }

  const displayValue = computed(() => {
    if (!properties.value) return '0'
    return Math.round(scaledValue.value).toString()
  })

  return {
    normalizedValue,
    scaledValue,
    properties,
    displayValue,
    setNormalizedValue,
    isInitialized,
  }
}

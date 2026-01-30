import { ref, onMounted, onUnmounted, watch } from 'vue'
import type { Ref } from 'vue'
import { useRuntime } from './useRuntime'

// Module-level reactive state (singleton pattern)
const isConnected: Ref<boolean> = ref(false)
const leftStickX: Ref<number> = ref(0)
const leftStickY: Ref<number> = ref(0)
const rightStickX: Ref<number> = ref(0)
const rightStickY: Ref<number> = ref(0)
const leftTrigger: Ref<number> = ref(0)
const rightTrigger: Ref<number> = ref(0)
const gamepadId: Ref<string | null> = ref(null)
const grainLength: Ref<number> = ref(4224)
const triggerState: Ref<'off' | 'on' | 'freeze'> = ref('off')

const POLL_INTERVAL_MS_250HZ = 4

let pollIntervalId: number | null = null
let gamepadIndex: number | null = null

function pollGamepad(): void {
  const gamepads = navigator.getGamepads()

  if (gamepadIndex !== null) {
    const gamepad = gamepads[gamepadIndex]
    if (gamepad) {
      leftStickX.value = gamepad.axes[0] ?? 0
      leftStickY.value = -(gamepad.axes[1] ?? 0)
      rightStickX.value = gamepad.axes[2] ?? 0
      rightStickY.value = -(gamepad.axes[3] ?? 0)
      leftTrigger.value = gamepad.buttons[6]?.value ?? 0
      rightTrigger.value = gamepad.buttons[7]?.value ?? 0
    }
  }
}

function startPolling(): void {
  if (pollIntervalId === null) {
    pollIntervalId = window.setInterval(pollGamepad, POLL_INTERVAL_MS_250HZ)
  }
}

function stopPolling(): void {
  if (pollIntervalId !== null) {
    clearInterval(pollIntervalId)
    pollIntervalId = null
  }
}

function onGamepadConnected(event: GamepadEvent): void {
  // Only track first connected gamepad
  if (gamepadIndex === null) {
    gamepadIndex = event.gamepad.index
    gamepadId.value = event.gamepad.id
    isConnected.value = true
    startPolling()
  }
}

function onGamepadDisconnected(event: GamepadEvent): void {
  if (event.gamepad.index === gamepadIndex) {
    gamepadIndex = null
    gamepadId.value = null
    isConnected.value = false
    leftStickX.value = 0
    leftStickY.value = 0
    rightStickX.value = 0
    rightStickY.value = 0
    leftTrigger.value = 0
    rightTrigger.value = 0
    stopPolling()
  }
}

export function useGamepad() {
  const { runtime } = useRuntime()

  onMounted(() => {
    window.addEventListener('gamepadconnected', onGamepadConnected)
    window.addEventListener('gamepaddisconnected', onGamepadDisconnected)

    // Check for already-connected gamepads
    const gamepads = navigator.getGamepads()
    for (const gamepad of gamepads) {
      if (gamepad) {
        gamepadIndex = gamepad.index
        gamepadId.value = gamepad.id
        isConnected.value = true
        startPolling()
        break // Only use first gamepad
      }
    }
  })

  onUnmounted(() => {
    window.removeEventListener('gamepadconnected', onGamepadConnected)
    window.removeEventListener('gamepaddisconnected', onGamepadDisconnected)
    stopPolling()
  })

  watch(leftStickY, (y) => {
    const length = 256 + Math.floor((y + 1) * 3968)
    grainLength.value = length
    runtime.value?.setGrainLength?.(length)
  })

  watch([leftTrigger, rightTrigger], ([lt, rt]) => {
    const leftPressed = lt > 0.5
    const rightPressed = rt > 0.5
    
    let newState: 'off' | 'on' | 'freeze'
    if (leftPressed && rightPressed) {
      newState = 'freeze'
    } else if (leftPressed || rightPressed) {
      newState = 'on'
    } else {
      newState = 'off'
    }
    
    if (newState !== triggerState.value) {
      console.log('[TRIGGER]', newState.toUpperCase())
      triggerState.value = newState
      
      if (newState === 'off') {
        runtime.value?.setGrainDensity?.(0.0)
        runtime.value?.setFreeze?.(false)
      } else if (newState === 'on') {
        runtime.value?.setGrainDensity?.(1.0)
        runtime.value?.setFreeze?.(false)
      } else {
        runtime.value?.setGrainDensity?.(1.0)
        runtime.value?.setFreeze?.(true)
      }
    }
  })

  return {
    isConnected,
    leftStickX,
    leftStickY,
    rightStickX,
    rightStickY,
    gamepadId,
    grainLength,
    triggerState,
  }
}

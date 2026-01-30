import { ref, onMounted, onUnmounted, watch } from 'vue'
import type { Ref } from 'vue'
import { useRuntime } from './useRuntime'

// Module-level reactive state (singleton pattern)
const isConnected: Ref<boolean> = ref(false)
const leftStickX: Ref<number> = ref(0)
const leftStickY: Ref<number> = ref(0)
const rightStickX: Ref<number> = ref(0)
const rightStickY: Ref<number> = ref(0)
const gamepadId: Ref<string | null> = ref(null)
const grainLength: Ref<number> = ref(4224)

// Non-reactive state for RAF management
let animationFrameId: number | null = null
let gamepadIndex: number | null = null

function pollGamepad(): void {
  const gamepads = navigator.getGamepads()

  if (gamepadIndex !== null) {
    const gamepad = gamepads[gamepadIndex]
    if (gamepad) {
      // Standard Mapping: axes[0,1] = left stick, axes[2,3] = right stick
      // Invert Y: gamepad up is -1, but we want up to be +1
      leftStickX.value = gamepad.axes[0] ?? 0
      leftStickY.value = -(gamepad.axes[1] ?? 0)
      rightStickX.value = gamepad.axes[2] ?? 0
      rightStickY.value = -(gamepad.axes[3] ?? 0)
    }
  }

  animationFrameId = requestAnimationFrame(pollGamepad)
}

function startPolling(): void {
  if (animationFrameId === null) {
    animationFrameId = requestAnimationFrame(pollGamepad)
  }
}

function stopPolling(): void {
  if (animationFrameId !== null) {
    cancelAnimationFrame(animationFrameId)
    animationFrameId = null
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

  // Map left stick Y to grain length: -1 (down) to +1 (up) -> 256 to 8192 samples
  watch(leftStickY, (y) => {
    const length = 256 + Math.floor((y + 1) * 3968)
    grainLength.value = length
    runtime.value?.setGrainLength?.(length)
  })

  return {
    isConnected,
    leftStickX,
    leftStickY,
    rightStickX,
    rightStickY,
    gamepadId,
    grainLength,
  }
}

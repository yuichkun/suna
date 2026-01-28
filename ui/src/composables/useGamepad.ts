import { ref, onMounted, onUnmounted } from 'vue'
import type { Ref } from 'vue'

// Module-level reactive state (singleton pattern)
const isConnected: Ref<boolean> = ref(false)
const rightStickX: Ref<number> = ref(0)
const rightStickY: Ref<number> = ref(0)
const gamepadId: Ref<string | null> = ref(null)

// Non-reactive state for RAF management
let animationFrameId: number | null = null
let gamepadIndex: number | null = null

function pollGamepad(): void {
  const gamepads = navigator.getGamepads()

  if (gamepadIndex !== null) {
    const gamepad = gamepads[gamepadIndex]
    if (gamepad) {
      // Standard Mapping: axes[2] = right stick X, axes[3] = right stick Y
      rightStickX.value = gamepad.axes[2] ?? 0
      rightStickY.value = gamepad.axes[3] ?? 0
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
    rightStickX.value = 0
    rightStickY.value = 0
    stopPolling()
  }
}

export function useGamepad() {
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

  return {
    isConnected,
    rightStickX,
    rightStickY,
    gamepadId,
  }
}

// 8-direction blend control for gamepad stick input
// Maps X/Y stick position to 8-slot gain values using cosine similarity

// Constants
///|
const PI : Float = 3.14159265358979323846

///|
const TWO_PI : Float = 6.28318530717958647692

// Slot angles calculated dynamically based on number of slots
// Formula: angle = PI/2 - slot * (2π / N)
// This ensures even distribution around the circle with slot 0 at top (PI/2)

// Global blend state (X/Y stick position, range -1.0 to 1.0)
///|
let blend_x : Ref[Float] = { val: 0.0 }

///|
let blend_y : Ref[Float] = { val: 0.0 }

// Per-slot gain values (dynamic array, expanded as needed)
///|
let gains : Array[Ref[Float]] = []

// WASM intrinsic for sqrt
///|
extern "wasm" fn sqrt_f32(x : Float) -> Float =
  #|(func (param f32) (result f32) (f32.sqrt (local.get 0)))

// Math helper: absolute value
///|
fn abs_f32(x : Float) -> Float {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

// Math helper: clamp value to range
///|
fn clamp_f32(x : Float, min_val : Float, max_val : Float) -> Float {
  if x < min_val {
    min_val
  } else if x > max_val {
    max_val
  } else {
    x
  }
}

// Math helper: max of two floats
///|
fn max_f32(a : Float, b : Float) -> Float {
  if a > b {
    a
  } else {
    b
  }
}

// Math helper: normalize angle to -PI..PI range
///|
fn normalize_angle(angle : Float) -> Float {
  let mut a = angle
  while a > PI {
    a = a - TWO_PI
  }
  while a < -PI {
    a = a + TWO_PI
  }
  a
}

// Math helper: atan2 approximation
// Fast approximation using polynomial, returns range -PI to PI
///|
fn atan2_approx(y : Float, x : Float) -> Float {
  // Handle special cases
  if x == 0.0 && y == 0.0 {
    return 0.0
  }
  if x == 0.0 {
    if y > 0.0 {
      return PI / 2.0
    } else {
      return -PI / 2.0
    }
  }
  // Fast atan approximation for |z| <= 1
  // atan(z) ≈ z * (0.97239411 - 0.19194795 * z^2)
  let abs_x = abs_f32(x)
  let abs_y = abs_f32(y)
  let mut angle : Float = 0.0
  if abs_x >= abs_y {
    let z = y / x
    let z2 = z * z
    angle = z * (0.97239411 - 0.19194795 * z2)
    if x < 0.0 {
      if y >= 0.0 {
        angle = angle + PI
      } else {
        angle = angle - PI
      }
    }
  } else {
    let z = x / y
    let z2 = z * z
    angle = z * (0.97239411 - 0.19194795 * z2)
    if y > 0.0 {
      angle = PI / 2.0 - angle
    } else {
      angle = -PI / 2.0 - angle
    }
  }
  angle
}

// Math helper: cosine approximation using Bhaskara I formula
// Input should be normalized to -PI..PI
///|
fn cos_approx(x : Float) -> Float {
  // Normalize to 0..2PI first
  let mut a = x
  while a < 0.0 {
    a = a + TWO_PI
  }
  while a >= TWO_PI {
    a = a - TWO_PI
  }
  // Bhaskara I approximation: cos(x) ≈ (PI^2 - 4x^2) / (PI^2 + x^2) for x in [0, PI]
  // For x in [PI, 2PI], use cos(x) = cos(2PI - x)
  if a > PI {
    a = TWO_PI - a
  }
  // Now a is in [0, PI]
  // Shift to center at PI/2 for better accuracy
  // cos(a) = -cos(PI - a) when a > PI/2
  let half_pi = PI / 2.0
  if a > half_pi {
    let b = PI - a
    let b2 = b * b
    let pi2 = PI * PI
    -(pi2 - 4.0 * b2) / (pi2 + b2)
  } else {
    let a2 = a * a
    let pi2 = PI * PI
    (pi2 - 4.0 * a2) / (pi2 + a2)
  }
}

// Calculate slot angle dynamically based on slot index and total slots
// Formula: angle = PI/2 - slot * (2π / N)
// Slot 0 starts at top (PI/2), clockwise placement
///|
fn get_slot_angle(slot : Int, total_slots : Int) -> Float {
  if total_slots <= 0 {
    return 0.0
  }
  let angle_step = TWO_PI / Float::from_int(total_slots)
  PI / 2.0 - Float::from_int(slot) * angle_step
}

// Ensure gain slot exists for dynamic slot expansion
// Expands gains array if slot >= current length
///|
pub fn ensure_gain_slot(slot : Int) -> Unit {
  while gains.length() <= slot {
    gains.push({ val: 0.0 })
  }
}

// Recalculate all gains based on current blend_x/blend_y
///|
fn recalculate_gains() -> Unit {
  let x = blend_x.val
  let y = blend_y.val
  // Calculate stick radius (clamped to 0..1)
  let r_raw = sqrt_f32(x * x + y * y)
  let r = clamp_f32(r_raw, 0.0, 1.0)
  
  // If at center or no slots, silence (all gains zero)
  if r < 0.001 || gains.length() == 0 {
    for i = 0; i < gains.length(); i = i + 1 {
      gains[i].val = 0.0
    }
    return
  }
  
  // Calculate stick angle
  let theta = atan2_approx(y, x)
  let n = gains.length()
  
  // Calculate weights for each slot
  let mut total : Float = 0.0
  for slot = 0; slot < n; slot = slot + 1 {
    let slot_angle = get_slot_angle(slot, n)
    let angle_diff = abs_f32(normalize_angle(theta - slot_angle))
    let raw = max_f32(0.0, cos_approx(angle_diff / 2.0))
    gains[slot].val = raw
    total = total + raw
  }
  
  // Normalize and apply radius
  if total > 0.0 {
    for slot = 0; slot < n; slot = slot + 1 {
      gains[slot].val = r * gains[slot].val / total
    }
  }
}

// Public API: Set blend X position (-1.0 to 1.0)
///|
pub fn set_blend_x(x : Float) -> Unit {
  blend_x.val = clamp_f32(x, -1.0, 1.0)
  recalculate_gains()
}

// Public API: Set blend Y position (-1.0 to 1.0)
///|
pub fn set_blend_y(y : Float) -> Unit {
  blend_y.val = clamp_f32(y, -1.0, 1.0)
  recalculate_gains()
}

// Public API: Get gain for a specific slot
///|
pub fn get_slot_gain(slot : Int) -> Float {
  if slot < 0 || slot >= gains.length() {
    return 0.0
  }
  gains[slot].val
}

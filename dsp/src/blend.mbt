// 8-direction blend control for gamepad stick input
// Maps X/Y stick position to 8-slot gain values using cosine similarity

// Constants
///|
const PI : Float = 3.14159265358979323846

///|
const TWO_PI : Float = 6.28318530717958647692

// Slot angles in radians (clockwise from top/north)
// Slot 0: 90° (up/north) = PI/2
// Slot 1: 45° (northeast) = PI/4
// Slot 2: 0° (right/east) = 0
// Slot 3: 315° (southeast) = -PI/4
// Slot 4: 270° (down/south) = -PI/2
// Slot 5: 225° (southwest) = -3*PI/4
// Slot 6: 180° (left/west) = PI
// Slot 7: 135° (northwest) = 3*PI/4
///|
const SLOT_ANGLE_0 : Float = 1.5707963267948966 // PI/2

///|
const SLOT_ANGLE_1 : Float = 0.7853981633974483 // PI/4

///|
const SLOT_ANGLE_2 : Float = 0.0 // 0

///|
const SLOT_ANGLE_3 : Float = -0.7853981633974483 // -PI/4

///|
const SLOT_ANGLE_4 : Float = -1.5707963267948966 // -PI/2

///|
const SLOT_ANGLE_5 : Float = -2.356194490192345 // -3*PI/4

///|
const SLOT_ANGLE_6 : Float = 3.14159265358979323846 // PI

///|
const SLOT_ANGLE_7 : Float = 2.356194490192345 // 3*PI/4

// Global blend state (X/Y stick position, range -1.0 to 1.0)
///|
let blend_x : Ref[Float] = { val: 0.0 }

///|
let blend_y : Ref[Float] = { val: 0.0 }

// Per-slot gain values (initialized to equal distribution 1/8)
///|
let gain_0 : Ref[Float] = { val: 0.125 }

///|
let gain_1 : Ref[Float] = { val: 0.125 }

///|
let gain_2 : Ref[Float] = { val: 0.125 }

///|
let gain_3 : Ref[Float] = { val: 0.125 }

///|
let gain_4 : Ref[Float] = { val: 0.125 }

///|
let gain_5 : Ref[Float] = { val: 0.125 }

///|
let gain_6 : Ref[Float] = { val: 0.125 }

///|
let gain_7 : Ref[Float] = { val: 0.125 }

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

// Get slot angle by index
///|
fn get_slot_angle(slot : Int) -> Float {
  match slot {
    0 => SLOT_ANGLE_0
    1 => SLOT_ANGLE_1
    2 => SLOT_ANGLE_2
    3 => SLOT_ANGLE_3
    4 => SLOT_ANGLE_4
    5 => SLOT_ANGLE_5
    6 => SLOT_ANGLE_6
    _ => SLOT_ANGLE_7
  }
}

// Set gain by slot index
///|
fn set_gain(slot : Int, value : Float) -> Unit {
  match slot {
    0 => gain_0.val = value
    1 => gain_1.val = value
    2 => gain_2.val = value
    3 => gain_3.val = value
    4 => gain_4.val = value
    5 => gain_5.val = value
    6 => gain_6.val = value
    _ => gain_7.val = value
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
  // If at center, silence (all gains zero)
  if r < 0.001 {
    gain_0.val = 0.0
    gain_1.val = 0.0
    gain_2.val = 0.0
    gain_3.val = 0.0
    gain_4.val = 0.0
    gain_5.val = 0.0
    gain_6.val = 0.0
    gain_7.val = 0.0
    return
  }
  // Calculate stick angle
  let theta = atan2_approx(y, x)
  // Calculate raw weights for each slot
  let mut raw_0 : Float = 0.0
  let mut raw_1 : Float = 0.0
  let mut raw_2 : Float = 0.0
  let mut raw_3 : Float = 0.0
  let mut raw_4 : Float = 0.0
  let mut raw_5 : Float = 0.0
  let mut raw_6 : Float = 0.0
  let mut raw_7 : Float = 0.0
  // Slot 0
  let angle_diff_0 = abs_f32(normalize_angle(theta - SLOT_ANGLE_0))
  raw_0 = max_f32(0.0, cos_approx(angle_diff_0 / 2.0))
  // Slot 1
  let angle_diff_1 = abs_f32(normalize_angle(theta - SLOT_ANGLE_1))
  raw_1 = max_f32(0.0, cos_approx(angle_diff_1 / 2.0))
  // Slot 2
  let angle_diff_2 = abs_f32(normalize_angle(theta - SLOT_ANGLE_2))
  raw_2 = max_f32(0.0, cos_approx(angle_diff_2 / 2.0))
  // Slot 3
  let angle_diff_3 = abs_f32(normalize_angle(theta - SLOT_ANGLE_3))
  raw_3 = max_f32(0.0, cos_approx(angle_diff_3 / 2.0))
  // Slot 4
  let angle_diff_4 = abs_f32(normalize_angle(theta - SLOT_ANGLE_4))
  raw_4 = max_f32(0.0, cos_approx(angle_diff_4 / 2.0))
  // Slot 5
  let angle_diff_5 = abs_f32(normalize_angle(theta - SLOT_ANGLE_5))
  raw_5 = max_f32(0.0, cos_approx(angle_diff_5 / 2.0))
  // Slot 6
  let angle_diff_6 = abs_f32(normalize_angle(theta - SLOT_ANGLE_6))
  raw_6 = max_f32(0.0, cos_approx(angle_diff_6 / 2.0))
  // Slot 7
  let angle_diff_7 = abs_f32(normalize_angle(theta - SLOT_ANGLE_7))
  raw_7 = max_f32(0.0, cos_approx(angle_diff_7 / 2.0))
  // Normalize weights
  let total = raw_0 + raw_1 + raw_2 + raw_3 + raw_4 + raw_5 + raw_6 + raw_7
  if total > 0.0 {
    let norm_0 = raw_0 / total
    let norm_1 = raw_1 / total
    let norm_2 = raw_2 / total
    let norm_3 = raw_3 / total
    let norm_4 = raw_4 / total
    let norm_5 = raw_5 / total
    let norm_6 = raw_6 / total
    let norm_7 = raw_7 / total
    // Simple: gain = radius * directional_weight (center = silent)
    gain_0.val = r * norm_0
    gain_1.val = r * norm_1
    gain_2.val = r * norm_2
    gain_3.val = r * norm_3
    gain_4.val = r * norm_4
    gain_5.val = r * norm_5
    gain_6.val = r * norm_6
    gain_7.val = r * norm_7
  } else {
    // Fallback to silence
    gain_0.val = 0.0
    gain_1.val = 0.0
    gain_2.val = 0.0
    gain_3.val = 0.0
    gain_4.val = 0.0
    gain_5.val = 0.0
    gain_6.val = 0.0
    gain_7.val = 0.0
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
  match slot {
    0 => gain_0.val
    1 => gain_1.val
    2 => gain_2.val
    3 => gain_3.val
    4 => gain_4.val
    5 => gain_5.val
    6 => gain_6.val
    _ => gain_7.val
  }
}

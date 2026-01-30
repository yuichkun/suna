///|
let blend_x : Ref[Float] = { val: 0.0 }

///|
let blend_y : Ref[Float] = { val: 0.0 }

///|
/// Current gains (smoothed)
let gains : Array[Float] = []

///|
/// Target gains (set by update_gains, gains interpolate toward this)
let target_gains : Array[Float] = []

///|
/// Track previous slot count to detect when slots change
let prev_slot_count : Ref[Int] = { val: -1 }

///|
pub fn set_blend_x(x : Float) -> Unit {
  blend_x.val = x
  update_gains()
}

///|
pub fn set_blend_y(y : Float) -> Unit {
  blend_y.val = y
  update_gains()
}

///|
pub fn get_blend_x() -> Float {
  blend_x.val
}

///|
pub fn get_blend_y() -> Float {
  blend_y.val
}

///|
pub fn get_slot_gain(slot : Int) -> Float {
  if slot < 0 || slot >= gains.length() {
    return 0.0
  }
  gains[slot]
}

///|
pub fn update_gains() -> Unit {
  let slot_count = get_slot_count()
  // Resize gains and target_gains arrays to match slot count
  while gains.length() < slot_count {
    gains.push(0.0)
  }
  while gains.length() > slot_count {
    let _ = gains.pop()
  }
  while target_gains.length() < slot_count {
    target_gains.push(0.0)
  }
  while target_gains.length() > slot_count {
    let _ = target_gains.pop()
  }
  if slot_count == 0 {
    return
  }

  let x : Double = blend_x.val.to_double()
  let y : Double = blend_y.val.to_double()
  println("blend: x=\{x}, y=\{y}")

  // Calculate weights based on distance to each slot position on unit circle
  let weights : Array[Double] = []
  let two_pi = 2.0 * @math.PI
  
  for i = 0; i < slot_count; i = i + 1 {
    // Slot position on unit circle
    let angle = two_pi * i.to_double() / slot_count.to_double()
    let slot_x = @math.cos(angle)
    let slot_y = @math.sin(angle)
    
    // Distance from blend position to slot position
    let dx = x - slot_x
    let dy = y - slot_y
    let dist = Double::sqrt(dx * dx + dy * dy)
    
    // Weight: closer = higher weight
    // Using (2 - dist)^4 for sharp falloff
    // Max distance on unit circle is 2 (diameter)
    let w = 2.0 - dist
    let weight = if w > 0.0 { w * w * w * w } else { 0.0 }
    weights.push(weight)
  }

  // Normalize weights to sum to 1.0
  let mut total_weight : Double = 0.0
  for i = 0; i < slot_count; i = i + 1 {
    total_weight = total_weight + weights[i]
  }

  if total_weight > 0.0 {
    let sqrt_n = Double::sqrt(slot_count.to_double())
    for i = 0; i < slot_count; i = i + 1 {
      // Write to target_gains, not gains directly
      target_gains[i] = Float::from_double(weights[i] * sqrt_n / total_weight)
    }
  } else {
    // Fallback: equal distribution with sqrt normalization
    let equal_gain : Float = 1.0 / Float::from_int(slot_count).sqrt()
    for i = 0; i < slot_count; i = i + 1 {
      target_gains[i] = equal_gain
    }
  }

  // When slot count changes, initialize gains immediately (no smoothing delay)
  if slot_count != prev_slot_count.val {
    for i = 0; i < slot_count; i = i + 1 {
      gains[i] = target_gains[i]
    }
    prev_slot_count.val = slot_count
  }

  println("gains: \{target_gains}")
}

///|
/// Smooth gains toward target_gains (call once per sample)
pub fn smooth_gains() -> Unit {
  let one_minus_coeff : Float = 1.0 - gain_smooth_coeff
  for i = 0; i < gains.length(); i = i + 1 {
    // Exponential smoothing: gain = gain * (1 - coeff) + target * coeff
    gains[i] = gains[i] * one_minus_coeff + target_gains[i] * gain_smooth_coeff
  }
}

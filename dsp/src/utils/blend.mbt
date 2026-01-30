///|
let blend_x : Ref[Float] = { val: 0.0 }

///|
let blend_y : Ref[Float] = { val: 0.0 }

///|
let gains : Array[Float] = []

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
  // Resize gains array to match slot count
  while gains.length() < slot_count {
    gains.push(0.0)
  }
  while gains.length() > slot_count {
    let _ = gains.pop()
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
    for i = 0; i < slot_count; i = i + 1 {
      gains[i] = Float::from_double(weights[i] / total_weight)
    }
  } else {
    // Fallback: equal distribution
    let equal_gain : Float = 1.0 / Float::from_int(slot_count)
    for i = 0; i < slot_count; i = i + 1 {
      gains[i] = equal_gain
    }
  }

  println("gains: \{gains}")
}

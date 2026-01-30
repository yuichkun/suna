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
  // Center position (x=0, y=0): equal gain for all slots
  // Total gain = 1.0 to prevent clipping
  let equal_gain : Float = 1.0 / Float::from_int(slot_count)
  for i = 0; i < slot_count; i = i + 1 {
    gains[i] = equal_gain
  }
  println("gains: \{gains}")
}

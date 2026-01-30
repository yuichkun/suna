///|
priv struct SlotMeta {
  mut data_ptr : Int
  mut length : Int
  mut play_pos : Float
  mut playing : Int
}

///|
let slots : Array[SlotMeta] = []

///|
let sample_rate : Ref[Float] = { val: default_sample_rate }

///|
let playback_speed : Ref[Float] = { val: 1.0 }

///|
let freeze : Ref[Bool] = { val: false }

///|
pub fn get_sample_rate() -> Float {
  sample_rate.val
}

///|
pub fn set_sample_rate(sr : Float) -> Unit {
  sample_rate.val = sr
}

///|
pub fn get_playback_speed() -> Float {
  playback_speed.val
}

///|
pub fn set_playback_speed(speed : Float) -> Unit {
  playback_speed.val = speed
  println("playback_speed: \{speed}")
}

///|
pub fn get_freeze() -> Bool {
  freeze.val
}

///|
pub fn set_freeze(value : Bool) -> Unit {
  freeze.val = value
  println("freeze: \{value}")
}

///|
pub fn get_slot_count() -> Int {
  slots.length()
}

///|
pub fn init_slots() -> Unit {
  slots.clear()
}

///|
pub fn load_sample_to_slot(slot : Int, data_ptr : Int, length : Int) -> Int {
  if slot < 0 {
    return -1
  }
  if length <= 0 {
    return -2
  }
  while slots.length() <= slot {
    slots.push({ data_ptr: 0, length: 0, play_pos: 0, playing: 0 })
  }
  slots[slot].data_ptr = data_ptr
  slots[slot].length = length
  slots[slot].play_pos = 0
  slots[slot].playing = 0
  update_gains()
  0
}

///|
pub fn clear_slot_data(slot : Int) -> Int {
  if slot < 0 || slot >= slots.length() {
    return 0
  }
  slots[slot].data_ptr = 0
  slots[slot].length = 0
  slots[slot].play_pos = 0
  slots[slot].playing = 0
  0
}

///|
pub fn start_all_slots() -> Unit {
  for i = 0; i < slots.length(); i = i + 1 {
    if slots[i].length > 0 {
      slots[i].play_pos = 0
      slots[i].playing = 1
    }
  }
}

///|
pub fn stop_all_slots() -> Unit {
  for i = 0; i < slots.length(); i = i + 1 {
    slots[i].playing = 0
  }
}

///|
pub fn get_slot_sample_length(slot : Int) -> Int {
  if slot < 0 || slot >= slots.length() {
    return 0
  }
  slots[slot].length
}

///|
pub fn get_slot_playing_state(slot : Int) -> Int {
  if slot < 0 || slot >= slots.length() {
    return 0
  }
  slots[slot].playing
}

///|
pub fn get_slot_data_ptr(slot : Int) -> Int {
  if slot < 0 || slot >= slots.length() {
    return 0
  }
  slots[slot].data_ptr
}

///|
pub fn get_slot_play_pos(slot : Int) -> Float {
  if slot < 0 || slot >= slots.length() {
    return 0
  }
  slots[slot].play_pos
}

///|
pub fn set_slot_play_pos(slot : Int, pos : Float) -> Unit {
  if slot >= 0 && slot < slots.length() {
    slots[slot].play_pos = pos
  }
}

///|
pub fn set_slot_playing(slot : Int, playing : Int) -> Unit {
  if slot >= 0 && slot < slots.length() {
    slots[slot].playing = playing
  }
}

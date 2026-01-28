// 8-slot mono sampler implementation
// Uses global state with FixedArray for GC-minimized design

// SlotMeta struct - metadata for each sample slot
// Stores pointer to linear memory, length, playback position, and playing state
///|
struct SlotMeta {
  mut data_ptr : Int    // Linear Memory pointer (byte offset)
  mut length : Int      // Sample length in frames
  mut play_pos : Int    // Current playback position
  mut playing : Int     // Playing flag (0 = stopped, 1 = playing)
}

// Dynamic slots array - stores SlotMeta for each loaded sample
///|
let slots : Array[SlotMeta] = []

// Sampler sample rate
///|
let sampler_sample_rate : Ref[Float] = { val: 48000.0 }

///|
/// Load a 32-bit float from linear memory at given byte offset
extern "wasm" fn sampler_load_f32(ptr : Int) -> Float =
  #|(func (param i32) (result f32) (f32.load (local.get 0)))

///|
/// Initialize sampler with given sample rate
/// Clears all slots and resets state
/// Returns 0 on success
pub fn init_sampler(sr : Float) -> Int {
  sampler_sample_rate.val = sr
  slots.clear()
  0 // success
}

///|
/// Load sample data from linear memory into a slot
/// data_ptr: byte offset in linear memory where sample data starts
/// length: number of samples to load
/// Returns 0 on success, -1 on invalid slot, -2 on invalid length
pub fn load_sample(slot : Int, data_ptr : Int, length : Int) -> Int {
  // Validate slot
  if slot < 0 {
    return -1
  }
  // Validate length
  if length <= 0 {
    return -2
  }
  // Expand slots array as needed
  while slots.length() <= slot {
    slots.push({ data_ptr: 0, length: 0, play_pos: 0, playing: 0 })
  }
  // Sync blend gains array
  ensure_gain_slot(slot)
  // Record pointer and length only - NO DATA COPY
  slots[slot].data_ptr = data_ptr
  slots[slot].length = length
  slots[slot].play_pos = 0
  slots[slot].playing = 0
  0 // success
}

///|
/// Clear a slot's metadata and stop playback
/// Returns 0 on success (even if slot out of bounds)
pub fn clear_slot(slot : Int) -> Int {
  // Range-safe: return 0 even if out of bounds
  if slot < 0 || slot >= slots.length() {
    return 0
  }
  // Reset slot metadata
  slots[slot].data_ptr = 0
  slots[slot].length = 0
  slots[slot].play_pos = 0
  slots[slot].playing = 0
  0 // success
}

///|
/// Start playback for all loaded slots (length > 0)
/// Resets play position to beginning
pub fn play_all() -> Unit {
  for slot = 0; slot < slots.length(); slot = slot + 1 {
    if slots[slot].length > 0 {
      slots[slot].play_pos = 0
      slots[slot].playing = 1
    }
  }
}

///|
/// Stop all playback
pub fn stop_all() -> Unit {
  for slot = 0; slot < slots.length(); slot = slot + 1 {
    slots[slot].playing = 0
  }
}

///|
/// Get sample length for a slot (0 if empty or out of bounds)
pub fn get_slot_length(slot : Int) -> Int {
  if slot < 0 || slot >= slots.length() {
    return 0
  }
  slots[slot].length
}

///|
/// Get playing state for a slot (0 = stopped, 1 = playing, 0 if out of bounds)
pub fn get_slot_playing(slot : Int) -> Int {
  if slot < 0 || slot >= slots.length() {
    return 0
  }
  slots[slot].playing
}

///|
/// Test helper: Set slot metadata for testing without Linear Memory
/// Expands slots array dynamically as needed
pub fn test_set_slot_data(slot : Int, length : Int) -> Unit {
  // Expand array if needed
  while slots.length() <= slot {
    slots.push({ data_ptr: 0, length: 0, play_pos: 0, playing: 0 })
  }
  // Sync blend gains
  ensure_gain_slot(slot)
  
  // Set test data (dummy data_ptr for tests)
  slots[slot].data_ptr = 0
  slots[slot].length = length
  slots[slot].play_pos = 0
  slots[slot].playing = 0
}

///|
/// Process sampler and mix all playing samples
/// Returns stereo output (mono sample duplicated to both channels)
pub fn process_sampler_stereo(left_in : Float, right_in : Float) -> (Float, Float) {
  let mut mix_out : Float = 0.0
  // Process each slot
  for slot = 0; slot < slots.length(); slot = slot + 1 {
    let meta = slots[slot]
    // Only process playing slots
    if meta.playing == 1 && meta.length > 0 {
      // Get current sample from linear memory
      if meta.play_pos < meta.length {
        let sample = sampler_load_f32(meta.data_ptr + meta.play_pos * 4)
        mix_out = mix_out + sample * get_slot_gain(slot)
        // Advance position
        slots[slot].play_pos = meta.play_pos + 1
      } else {
        // Reached end of sample, stop playback
        slots[slot].playing = 0
      }
    }
  }
  // Mix with input and output to both channels
  let left_out = left_in + mix_out
  let right_out = right_in + mix_out
  (left_out, right_out)
}

// 8-slot mono sampler implementation
// Uses global state with FixedArray for GC-minimized design

// Constants
///|
const MAX_SAMPLES : Int = 8

///|
const MAX_SAMPLE_LENGTH : Int = 1440000 // 30 seconds @ 48kHz

// Global state - 8 mono sample buffers
///|
let sample_buffer_0 : FixedArray[Float] = FixedArray::make(1440000, 0.0)

///|
let sample_buffer_1 : FixedArray[Float] = FixedArray::make(1440000, 0.0)

///|
let sample_buffer_2 : FixedArray[Float] = FixedArray::make(1440000, 0.0)

///|
let sample_buffer_3 : FixedArray[Float] = FixedArray::make(1440000, 0.0)

///|
let sample_buffer_4 : FixedArray[Float] = FixedArray::make(1440000, 0.0)

///|
let sample_buffer_5 : FixedArray[Float] = FixedArray::make(1440000, 0.0)

///|
let sample_buffer_6 : FixedArray[Float] = FixedArray::make(1440000, 0.0)

///|
let sample_buffer_7 : FixedArray[Float] = FixedArray::make(1440000, 0.0)

// Sample lengths for each slot (0 = empty)
///|
let sample_length_0 : Ref[Int] = { val: 0 }

///|
let sample_length_1 : Ref[Int] = { val: 0 }

///|
let sample_length_2 : Ref[Int] = { val: 0 }

///|
let sample_length_3 : Ref[Int] = { val: 0 }

///|
let sample_length_4 : Ref[Int] = { val: 0 }

///|
let sample_length_5 : Ref[Int] = { val: 0 }

///|
let sample_length_6 : Ref[Int] = { val: 0 }

///|
let sample_length_7 : Ref[Int] = { val: 0 }

// Playback positions for each slot
///|
let play_pos_0 : Ref[Int] = { val: 0 }

///|
let play_pos_1 : Ref[Int] = { val: 0 }

///|
let play_pos_2 : Ref[Int] = { val: 0 }

///|
let play_pos_3 : Ref[Int] = { val: 0 }

///|
let play_pos_4 : Ref[Int] = { val: 0 }

///|
let play_pos_5 : Ref[Int] = { val: 0 }

///|
let play_pos_6 : Ref[Int] = { val: 0 }

///|
let play_pos_7 : Ref[Int] = { val: 0 }

// Playing flags for each slot (0 = stopped, 1 = playing)
///|
let playing_0 : Ref[Int] = { val: 0 }

///|
let playing_1 : Ref[Int] = { val: 0 }

///|
let playing_2 : Ref[Int] = { val: 0 }

///|
let playing_3 : Ref[Int] = { val: 0 }

///|
let playing_4 : Ref[Int] = { val: 0 }

///|
let playing_5 : Ref[Int] = { val: 0 }

///|
let playing_6 : Ref[Int] = { val: 0 }

///|
let playing_7 : Ref[Int] = { val: 0 }

// Sampler sample rate
///|
let sampler_sample_rate : Ref[Float] = { val: 48000.0 }

// Helper functions to access buffers by slot index
///|
pub fn get_sample_buffer(slot : Int) -> FixedArray[Float] {
  match slot {
    0 => sample_buffer_0
    1 => sample_buffer_1
    2 => sample_buffer_2
    3 => sample_buffer_3
    4 => sample_buffer_4
    5 => sample_buffer_5
    6 => sample_buffer_6
    _ => sample_buffer_7
  }
}

///|
pub fn get_sample_length(slot : Int) -> Ref[Int] {
  match slot {
    0 => sample_length_0
    1 => sample_length_1
    2 => sample_length_2
    3 => sample_length_3
    4 => sample_length_4
    5 => sample_length_5
    6 => sample_length_6
    _ => sample_length_7
  }
}

///|
fn get_play_pos(slot : Int) -> Ref[Int] {
  match slot {
    0 => play_pos_0
    1 => play_pos_1
    2 => play_pos_2
    3 => play_pos_3
    4 => play_pos_4
    5 => play_pos_5
    6 => play_pos_6
    _ => play_pos_7
  }
}

///|
fn get_playing(slot : Int) -> Ref[Int] {
  match slot {
    0 => playing_0
    1 => playing_1
    2 => playing_2
    3 => playing_3
    4 => playing_4
    5 => playing_5
    6 => playing_6
    _ => playing_7
  }
}

///|
/// Load a 32-bit float from linear memory at given byte offset
extern "wasm" fn sampler_load_f32(ptr : Int) -> Float =
  #|(func (param i32) (result f32) (f32.load (local.get 0)))

///|
/// Initialize sampler with given sample rate
/// Clears all buffers and resets state
/// Returns 0 on success
pub fn init_sampler(sr : Float) -> Int {
  sampler_sample_rate.val = sr
  // Clear all slots
  for slot = 0; slot < MAX_SAMPLES; slot = slot + 1 {
    let buffer = get_sample_buffer(slot)
    let length_ref = get_sample_length(slot)
    let pos_ref = get_play_pos(slot)
    let playing_ref = get_playing(slot)
    // Clear buffer
    for i = 0; i < MAX_SAMPLE_LENGTH; i = i + 1 {
      buffer[i] = 0.0
    }
    length_ref.val = 0
    pos_ref.val = 0
    playing_ref.val = 0
  }
  0 // success
}

///|
/// Load sample data from linear memory into a slot
/// data_ptr: byte offset in linear memory where sample data starts
/// length: number of samples to load
/// Returns 0 on success, -1 on invalid slot, -2 on length exceeds max
pub fn load_sample(slot : Int, data_ptr : Int, length : Int) -> Int {
  // Validate slot
  if slot < 0 || slot >= MAX_SAMPLES {
    return -1
  }
  // Validate length
  if length <= 0 || length > MAX_SAMPLE_LENGTH {
    return -2
  }
  let buffer = get_sample_buffer(slot)
  let length_ref = get_sample_length(slot)
  let pos_ref = get_play_pos(slot)
  let playing_ref = get_playing(slot)
  // Stop playback while loading
  playing_ref.val = 0
  pos_ref.val = 0
  // Copy sample data from linear memory (4 bytes per Float32)
  for i = 0; i < length; i = i + 1 {
    let byte_offset = i * 4
    buffer[i] = sampler_load_f32(data_ptr + byte_offset)
  }
  // Clear remaining buffer
  for i = length; i < MAX_SAMPLE_LENGTH; i = i + 1 {
    buffer[i] = 0.0
  }
  length_ref.val = length
  0 // success
}

///|
/// Clear a slot's buffer and stop playback
/// Returns 0 on success, -1 on invalid slot
pub fn clear_slot(slot : Int) -> Int {
  // Validate slot
  if slot < 0 || slot >= MAX_SAMPLES {
    return -1
  }
  let buffer = get_sample_buffer(slot)
  let length_ref = get_sample_length(slot)
  let pos_ref = get_play_pos(slot)
  let playing_ref = get_playing(slot)
  // Stop playback
  playing_ref.val = 0
  pos_ref.val = 0
  length_ref.val = 0
  // Clear buffer
  for i = 0; i < MAX_SAMPLE_LENGTH; i = i + 1 {
    buffer[i] = 0.0
  }
  0 // success
}

///|
/// Start playback for all loaded slots (length > 0)
/// Resets play position to beginning
pub fn play_all() -> Unit {
  for slot = 0; slot < MAX_SAMPLES; slot = slot + 1 {
    let length_ref = get_sample_length(slot)
    let pos_ref = get_play_pos(slot)
    let playing_ref = get_playing(slot)
    // Only play slots that have samples loaded
    if length_ref.val > 0 {
      pos_ref.val = 0
      playing_ref.val = 1
    }
  }
}

///|
/// Stop all playback
pub fn stop_all() -> Unit {
  for slot = 0; slot < MAX_SAMPLES; slot = slot + 1 {
    let playing_ref = get_playing(slot)
    playing_ref.val = 0
  }
}

///|
/// Get sample length for a slot (0 if empty)
/// Returns -1 on invalid slot
pub fn get_slot_length(slot : Int) -> Int {
  if slot < 0 || slot >= MAX_SAMPLES {
    return -1
  }
  get_sample_length(slot).val
}

///|
/// Get playing state for a slot (0 = stopped, 1 = playing)
/// Returns -1 on invalid slot
pub fn get_slot_playing(slot : Int) -> Int {
  if slot < 0 || slot >= MAX_SAMPLES {
    return -1
  }
  get_playing(slot).val
}

///|
/// Process sampler and mix all playing samples
/// Returns stereo output (mono sample duplicated to both channels)
pub fn process_sampler_stereo(left_in : Float, right_in : Float) -> (Float, Float) {
  let mut mix_out : Float = 0.0
  // Process each slot
  for slot = 0; slot < MAX_SAMPLES; slot = slot + 1 {
    let buffer = get_sample_buffer(slot)
    let length_ref = get_sample_length(slot)
    let pos_ref = get_play_pos(slot)
    let playing_ref = get_playing(slot)
    // Only process playing slots
    if playing_ref.val == 1 && length_ref.val > 0 {
      // Get current sample
      let pos = pos_ref.val
      if pos < length_ref.val {
        mix_out = mix_out + buffer[pos] * get_slot_gain(slot)
        // Advance position
        pos_ref.val = pos + 1
      } else {
        // Reached end of sample, stop playback
        playing_ref.val = 0
      }
    }
  }
  // Mix with input and output to both channels
  let left_out = left_in + mix_out
  let right_out = right_in + mix_out
  (left_out, right_out)
}

// Stereo buffer processing for WASM linear memory access
// Enables efficient block processing from C++ (JUCE) and JavaScript (AudioWorklet)

/// Load a 32-bit float from linear memory at given byte offset
extern "wasm" fn load_f32(ptr : Int) -> Float =
  #|(func (param i32) (result f32) (f32.load (local.get 0)))

/// Store a 32-bit float to linear memory at given byte offset
extern "wasm" fn store_f32(ptr : Int, value : Float) =
  #|(func (param i32 f32) (f32.store (local.get 0) (local.get 1)))

/// Process stereo audio block through delay
/// Reads from WASM linear memory at input pointers, processes through delay,
/// and writes to output pointers. Supports in-place processing (in_ptr == out_ptr).
/// 
/// Parameters:
/// - state_ptr: Reserved for future state management (currently unused)
/// - left_in_ptr: Pointer to left input buffer in linear memory (byte offset)
/// - right_in_ptr: Pointer to right input buffer in linear memory (byte offset)
/// - left_out_ptr: Pointer to left output buffer in linear memory (byte offset)
/// - right_out_ptr: Pointer to right output buffer in linear memory (byte offset)
/// - num_samples: Number of samples to process
/// 
/// Returns: 0 on success, non-zero on error
pub fn process_block(
  state_ptr : Int,
  left_in_ptr : Int,
  right_in_ptr : Int,
  left_out_ptr : Int,
  right_out_ptr : Int,
  num_samples : Int
) -> Int {
  // state_ptr reserved for future use (e.g., multiple delay instances)
  let _ = state_ptr
  
  // Validate num_samples
  if num_samples < 0 {
    return -1 // error: invalid sample count
  }
  
  // Process each sample (4 bytes per Float32)
  for i = 0; i < num_samples; i = i + 1 {
    let byte_offset = i * 4
    
    // Read input samples from linear memory
    let left_in = load_f32(left_in_ptr + byte_offset)
    let right_in = load_f32(right_in_ptr + byte_offset)
    
    // Process through delay (mono-sum stereo, Kodama pattern)
    // This advances write_pos ONCE per stereo pair (not twice!)
    let (left_out, right_out) = process_stereo(left_in, right_in)
    
    // Write output samples to linear memory
    store_f32(left_out_ptr + byte_offset, left_out)
    store_f32(right_out_ptr + byte_offset, right_out)
  }
  
  0 // success
}

// Tests for stereo buffer processing
// Note: Full linear memory access testing requires WASM runtime
// Integration tests will be in C++ (JUCE) and JavaScript (AudioWorklet)

///|
test "process_block returns success for valid input" {
  // Initialize sampler with reasonable parameters
  let _ = init_sampler(44100.0)

  // Test with zero samples (edge case)
  // Note: Actual memory access requires WASM runtime
  // Here we just verify the function signature and return value
  let result = process_block(0, 0, 0, 0, 0, 0)
  assert_eq(result, 0)
}

///|
test "process_block returns error for negative sample count" {
  let result = process_block(0, 0, 0, 0, 0, -1)
  assert_eq(result, -1)
}

///|
test "process_block handles state_ptr parameter" {
  // state_ptr is reserved for future use
  // Verify it doesn't affect processing
  let _ = init_sampler(44100.0)

  // Different state_ptr values should all succeed with 0 samples
  let result1 = process_block(0, 0, 0, 0, 0, 0)
  let result2 = process_block(12345, 0, 0, 0, 0, 0)
  assert_eq(result1, 0)
  assert_eq(result2, 0)
}

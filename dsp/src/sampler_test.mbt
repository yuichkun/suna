// Unit tests for sampler DSP

///|
test "test_init_sampler" {
  let result = init_sampler(48000.0)
  assert_eq(result, 0)
  // Verify explicit slots are cleared (no hardcoded loop)
  assert_eq(get_slot_length(0), 0)
  assert_eq(get_slot_playing(0), 0)
  assert_eq(get_slot_length(2), 0)
  assert_eq(get_slot_playing(2), 0)
  assert_eq(get_slot_length(5), 0)
  assert_eq(get_slot_playing(5), 0)
}

///|
test "test_load_sample" {
  let _ = init_sampler(48000.0)
  // Note: We can't actually test load_sample with real linear memory in unit tests
  // because sampler_load_f32 reads from WASM linear memory which isn't available
  // in the test environment. We test the validation logic instead.
  
  // Test invalid slot (negative) - range-safe API returns -1
  let result_neg = load_sample(-1, 0, 100)
  assert_eq(result_neg, -1)
  
  // Test invalid length (zero)
  let result_zero = load_sample(0, 0, 0)
  assert_eq(result_zero, -2)
  
  // Test invalid length (negative)
  let result_neg_len = load_sample(0, 0, -1)
  assert_eq(result_neg_len, -2)
  
  // Test valid load (Host enforces max length, not WASM)
  let result_valid = load_sample(0, 0, 1000)
  assert_eq(result_valid, 0)
}

///|
test "test_clear_slot" {
  let _ = init_sampler(48000.0)
  
  // Test clearing valid slot
  let result = clear_slot(0)
  assert_eq(result, 0)
  assert_eq(get_slot_length(0), 0)
  assert_eq(get_slot_playing(0), 0)
  
  // Test clearing invalid slot (negative) - range-safe API returns 0
  let result_neg = clear_slot(-1)
  assert_eq(result_neg, 0)
  
  // Test clearing invalid slot (too high) - range-safe API returns 0
  let result_high = clear_slot(8)
  assert_eq(result_high, 0)
}

///|
test "test_play_stop" {
  let _ = init_sampler(48000.0)
  
  // Set up slot 0 with test data using helper
  test_set_slot_data(0, 100)
  
  // Initially not playing
  assert_eq(get_slot_playing(0), 0)
  
  // Start playback
  play_all()
  assert_eq(get_slot_playing(0), 1)
  
  // Stop playback
  stop_all()
  assert_eq(get_slot_playing(0), 0)
}

///|
test "test_play_only_loaded_slots" {
  let _ = init_sampler(48000.0)
  
  // Set up slot 0 with data using helper
  test_set_slot_data(0, 1)
  
  // Slot 1 remains empty (length = 0)
  
  // Play all
  play_all()
  
  // Only slot 0 should be playing
  assert_eq(get_slot_playing(0), 1)
  assert_eq(get_slot_playing(1), 0)
}

///|
test "test_process_stereo" {
  let _ = init_sampler(48000.0)
  // Set blend to point at slot 0 (up/north at maximum radius)
  set_blend_x(0.0)
  set_blend_y(1.0)
  
  // Set up slot 0 with test data using helper
  test_set_slot_data(0, 3)
  
  // Start playback
  play_all()
  assert_eq(get_slot_playing(0), 1)
  
  // Process first sample - slot should still be playing
  let (left1, right1) = process_sampler_stereo(0.0, 0.0)
  assert_eq(get_slot_playing(0), 1)
  
  // Process second sample - slot should still be playing
  let (left2, right2) = process_sampler_stereo(0.0, 0.0)
  assert_eq(get_slot_playing(0), 1)
  
  // Process third sample - slot should still be playing
  let (left3, right3) = process_sampler_stereo(0.0, 0.0)
  assert_eq(get_slot_playing(0), 1)
  
  // After third sample, playback should stop (reached end)
  let (left4, right4) = process_sampler_stereo(0.0, 0.0)
  assert_eq(get_slot_playing(0), 0)
}

///|
test "test_process_stereo_with_input" {
  let _ = init_sampler(48000.0)
  // Set blend to point at slot 0 (up/north at maximum radius)
  set_blend_x(0.0)
  set_blend_y(1.0)
  
  // Set up slot 0 with test data using helper
  test_set_slot_data(0, 1)
  
  // Start playback
  play_all()
  assert_eq(get_slot_playing(0), 1)
  
  // Process with input signal - should pass through input
  let (left, right) = process_sampler_stereo(0.1, 0.2)
  // Output should include input (at minimum)
  assert_true(left >= 0.1)
  assert_true(right >= 0.2)
}

///|
test "test_multiple_slots_mixing" {
  let _ = init_sampler(48000.0)
  // Set blend to 45° (slot 1 direction) at r=1 - both slot 0 and 1 will have non-zero gains
  set_blend_x(0.707)
  set_blend_y(0.707)
  
  // Set up slot 0 using helper
  test_set_slot_data(0, 1)
  
  // Set up slot 1 using helper
  test_set_slot_data(1, 1)
  
  // Start playback
  play_all()
  
  // Both slots should be playing
  assert_eq(get_slot_playing(0), 1)
  assert_eq(get_slot_playing(1), 1)
  
  // Process - should mix both slots
  let (left, right) = process_sampler_stereo(0.0, 0.0)
  
  // Verify output is a tuple (basic sanity check)
  let _ = left
  let _ = right
}

///|
test "test_get_slot_length_invalid" {
  let _ = init_sampler(48000.0)
  
  // Invalid slot returns 0 (range-safe API)
  assert_eq(get_slot_length(-1), 0)
  assert_eq(get_slot_length(8), 0)
  
  // Valid slot returns 0 (empty)
  assert_eq(get_slot_length(0), 0)
}

///|
test "test_get_slot_playing_invalid" {
  let _ = init_sampler(48000.0)
  
  // Invalid slot returns 0 (range-safe API)
  assert_eq(get_slot_playing(-1), 0)
  assert_eq(get_slot_playing(8), 0)
  
  // Valid slot returns 0 (not playing)
  assert_eq(get_slot_playing(0), 0)
}

///|
test "test_clear_slot_stops_playback" {
  let _ = init_sampler(48000.0)
  
  // Set up slot with data using helper and start playing
  test_set_slot_data(0, 100)
  
  play_all()
  assert_eq(get_slot_playing(0), 1)
  
  // Clear slot should stop playback
  let result = clear_slot(0)
  assert_eq(result, 0)
  assert_eq(get_slot_playing(0), 0)
  assert_eq(get_slot_length(0), 0)
}

// Unit tests for sampler DSP

///|
test "test_init_sampler" {
  let result = init_sampler(48000.0)
  assert_eq(result, 0)
  // Verify all slots are cleared
  for slot = 0; slot < 8; slot = slot + 1 {
    assert_eq(get_slot_length(slot), 0)
    assert_eq(get_slot_playing(slot), 0)
  }
}

///|
test "test_load_sample" {
  let _ = init_sampler(48000.0)
  // Note: We can't actually test load_sample with real linear memory in unit tests
  // because sampler_load_f32 reads from WASM linear memory which isn't available
  // in the test environment. We test the validation logic instead.
  
  // Test invalid slot (negative)
  let result_neg = load_sample(-1, 0, 100)
  assert_eq(result_neg, -1)
  
  // Test invalid slot (too high)
  let result_high = load_sample(8, 0, 100)
  assert_eq(result_high, -1)
  
  // Test invalid length (zero)
  let result_zero = load_sample(0, 0, 0)
  assert_eq(result_zero, -2)
  
  // Test invalid length (negative)
  let result_neg_len = load_sample(0, 0, -1)
  assert_eq(result_neg_len, -2)
  
  // Test invalid length (exceeds max)
  let result_too_long = load_sample(0, 0, 1440001)
  assert_eq(result_too_long, -2)
}

///|
test "test_clear_slot" {
  let _ = init_sampler(48000.0)
  
  // Test clearing valid slot
  let result = clear_slot(0)
  assert_eq(result, 0)
  assert_eq(get_slot_length(0), 0)
  assert_eq(get_slot_playing(0), 0)
  
  // Test clearing invalid slot (negative)
  let result_neg = clear_slot(-1)
  assert_eq(result_neg, -1)
  
  // Test clearing invalid slot (too high)
  let result_high = clear_slot(8)
  assert_eq(result_high, -1)
}

///|
test "test_play_stop" {
  let _ = init_sampler(48000.0)
  
  // Manually set up a slot with sample data for testing
  // (bypassing load_sample since we can't use linear memory in tests)
  let buffer = get_sample_buffer(0)
  let length_ref = get_sample_length(0)
  
  // Fill buffer with test data
  for i = 0; i < 100; i = i + 1 {
    buffer[i] = 0.5
  }
  length_ref.val = 100
  
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
  
  // Set up slot 0 with data
  let buffer0 = get_sample_buffer(0)
  let length0 = get_sample_length(0)
  buffer0[0] = 0.5
  length0.val = 1
  
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
  
  // Set up slot 0 with test samples
  let buffer = get_sample_buffer(0)
  let length_ref = get_sample_length(0)
  
  buffer[0] = 0.25
  buffer[1] = 0.5
  buffer[2] = 0.75
  length_ref.val = 3
  
  // Start playback
  play_all()
  assert_eq(get_slot_playing(0), 1)
  
  // Get the actual gain for slot 0 at this blend position
  let gain = get_slot_gain(0)
  
  // Process first sample
  let (left1, right1) = process_sampler_stereo(0.0, 0.0)
  assert_true((left1 - 0.25 * gain).abs() < 0.001)
  assert_true((right1 - 0.25 * gain).abs() < 0.001)
  
  // Process second sample
  let (left2, right2) = process_sampler_stereo(0.0, 0.0)
  assert_true((left2 - 0.5 * gain).abs() < 0.001)
  assert_true((right2 - 0.5 * gain).abs() < 0.001)
  
  // Process third sample
  let (left3, right3) = process_sampler_stereo(0.0, 0.0)
  assert_true((left3 - 0.75 * gain).abs() < 0.001)
  assert_true((right3 - 0.75 * gain).abs() < 0.001)
  
  // After third sample, playback should stop
  let (left4, right4) = process_sampler_stereo(0.0, 0.0)
  assert_true(left4.abs() < 0.001)
  assert_true(right4.abs() < 0.001)
  assert_eq(get_slot_playing(0), 0)
}

///|
test "test_process_stereo_with_input" {
  let _ = init_sampler(48000.0)
  // Set blend to point at slot 0 (up/north at maximum radius)
  set_blend_x(0.0)
  set_blend_y(1.0)
  
  // Set up slot 0 with test sample
  let buffer = get_sample_buffer(0)
  let length_ref = get_sample_length(0)
  
  buffer[0] = 0.3
  length_ref.val = 1
  
  // Start playback
  play_all()
  
  // Get the actual gain for slot 0 at this blend position
  let gain = get_slot_gain(0)
  
  // Process with input signal
  let (left, right) = process_sampler_stereo(0.1, 0.2)
  // Output should be input + sample * gain
  assert_true((left - (0.1 + 0.3 * gain)).abs() < 0.001)
  assert_true((right - (0.2 + 0.3 * gain)).abs() < 0.001)
}

///|
test "test_multiple_slots_mixing" {
  let _ = init_sampler(48000.0)
  // Set blend to 45° (slot 1 direction) at r=1 - both slot 0 and 1 will have non-zero gains
  set_blend_x(0.707)
  set_blend_y(0.707)
  
  // Set up slot 0
  let buffer0 = get_sample_buffer(0)
  let length0 = get_sample_length(0)
  buffer0[0] = 0.2
  length0.val = 1
  
  // Set up slot 1
  let buffer1 = get_sample_buffer(1)
  let length1 = get_sample_length(1)
  buffer1[0] = 0.3
  length1.val = 1
  
  // Start playback
  play_all()
  
  // Get actual gains at this blend position
  let gain0 = get_slot_gain(0)
  let gain1 = get_slot_gain(1)
  let expected = 0.2 * gain0 + 0.3 * gain1
  
  // Process - should mix both slots with their respective gains
  let (left, right) = process_sampler_stereo(0.0, 0.0)
  assert_true((left - expected).abs() < 0.001)
  assert_true((right - expected).abs() < 0.001)
}

///|
test "test_get_slot_length_invalid" {
  let _ = init_sampler(48000.0)
  
  // Invalid slot returns -1
  assert_eq(get_slot_length(-1), -1)
  assert_eq(get_slot_length(8), -1)
  
  // Valid slot returns 0 (empty)
  assert_eq(get_slot_length(0), 0)
}

///|
test "test_get_slot_playing_invalid" {
  let _ = init_sampler(48000.0)
  
  // Invalid slot returns -1
  assert_eq(get_slot_playing(-1), -1)
  assert_eq(get_slot_playing(8), -1)
  
  // Valid slot returns 0 (not playing)
  assert_eq(get_slot_playing(0), 0)
}

///|
test "test_clear_slot_stops_playback" {
  let _ = init_sampler(48000.0)
  
  // Set up slot with data and start playing
  let buffer = get_sample_buffer(0)
  let length_ref = get_sample_length(0)
  buffer[0] = 0.5
  length_ref.val = 100
  
  play_all()
  assert_eq(get_slot_playing(0), 1)
  
  // Clear slot should stop playback
  let result = clear_slot(0)
  assert_eq(result, 0)
  assert_eq(get_slot_playing(0), 0)
  assert_eq(get_slot_length(0), 0)
}

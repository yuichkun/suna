test "speed_ramp_target_setting" {
  // Setup
  set_sample_rate(48000.0)
  
  // Initial state: target and current should be 0
  assert_eq(get_target_speed(), 0.0)
  assert_eq(get_current_speed(), 0.0)
  
  // Set target to 1.0
  set_speed_target(1.0)
  assert_eq(get_target_speed(), 1.0)
  // current should still be 0 (not instantly changed)
  assert_eq(get_current_speed(), 0.0)
}

test "speed_ramp_reaches_target" {
  // Setup
  set_sample_rate(48000.0)
  
  // Set target to 1.0
  set_speed_target(1.0)
  
  // Simulate enough samples to complete the ramp
  // At 48kHz, 200ms = 9600 samples
  for i = 0; i < 10000; i = i + 1 {
    ramp_playback_speed()
  }
  
  // Current should now equal target
  assert_eq(get_current_speed(), 1.0)
  assert_eq(get_playback_speed(), 1.0)
}

test "speed_ramp_down" {
  // Setup
  set_sample_rate(48000.0)
  
  // Start at 1.0
  set_speed_target(1.0)
  for i = 0; i < 10000; i = i + 1 {
    ramp_playback_speed()
  }
  assert_eq(get_current_speed(), 1.0)
  
  // Ramp down to 0.0
  set_speed_target(0.0)
  for i = 0; i < 10000; i = i + 1 {
    ramp_playback_speed()
  }
  
  assert_eq(get_current_speed(), 0.0)
  assert_eq(get_playback_speed(), 0.0)
}

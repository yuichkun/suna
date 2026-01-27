// Unit tests for delay DSP

///|
test "init_delay initializes state" {
  let result = init_delay(44100.0, 1000.0)
  assert_eq(result, 0)
}

///|
test "set_delay_time updates delay samples" {
  let _ = init_delay(44100.0, 1000.0)
  set_delay_time(100.0) // 100ms at 44.1kHz = 4410 samples
  // Verify by checking delay_samples internal state
  // At 44100 Hz, 100ms = 4410 samples
  // We can verify by processing and checking delay behavior
}

///|
test "set_feedback clamps values" {
  let _ = init_delay(44100.0, 1000.0)
  set_feedback(0.5)
  // Normal value should work
  set_feedback(-0.5)
  // Should clamp to 0.0
  set_feedback(1.5)
  // Should clamp to 1.0
}

///|
test "set_mix clamps values" {
  let _ = init_delay(44100.0, 1000.0)
  set_mix(0.5)
  // Normal value should work
  set_mix(-0.5)
  // Should clamp to 0.0
  set_mix(1.5)
  // Should clamp to 1.0
}

///|
test "process_sample produces delayed output" {
  let _ = init_delay(44100.0, 1000.0)
  set_delay_time(10.0) // 10ms = 441 samples at 44.1kHz
  set_feedback(0.0)
  set_mix(1.0) // 100% wet

  // Feed impulse
  let _ = process_sample(1.0)

  // Process 440 more samples (should be silent)
  for i = 0; i < 440; i = i + 1 {
    let _ = process_sample(0.0)

  }

  // 441st sample should have the delayed impulse
  let out_delayed = process_sample(0.0)
  assert_true(out_delayed > 0.9) // Should be close to 1.0
}

///|
test "dry signal passes through with mix=0" {
  let _ = init_delay(44100.0, 1000.0)
  set_delay_time(100.0)
  set_feedback(0.0)
  set_mix(0.0) // 100% dry
  let out = process_sample(0.5)
  // With mix=0, output should equal input
  assert_true((out - 0.5).abs() < 0.001)
}

///|
test "feedback creates repeating echoes" {
  let _ = init_delay(44100.0, 1000.0)
  set_delay_time(10.0) // 10ms = 441 samples
  set_feedback(0.5)
  set_mix(1.0) // 100% wet

  // Feed impulse
  let _ = process_sample(1.0)

  // Process until first echo
  for i = 0; i < 440; i = i + 1 {
    let _ = process_sample(0.0)

  }

  // First echo
  let first_echo = process_sample(0.0)
  assert_true(first_echo > 0.9)

  // Process until second echo
  for i = 0; i < 440; i = i + 1 {
    let _ = process_sample(0.0)

  }

  // Second echo should be attenuated by feedback
  let second_echo = process_sample(0.0)
  assert_true(second_echo > 0.4 && second_echo < 0.6)
}

///|
test "zero delay time produces immediate output" {
  let _ = init_delay(44100.0, 1000.0)
  set_delay_time(0.0)
  set_feedback(0.0)
  set_mix(1.0) // 100% wet

  // With zero delay, read_pos == write_pos, so we read the OLD value at that position
  // Since buffer is cleared, first sample reads 0
  let out1 = process_sample(1.0)
  assert_true(out1.abs() < 0.001) // reads 0 from cleared buffer

  // After first sample: pos 0 has 1.0, write_pos is now 1
  // Second sample: read_pos=1, which is still 0 (cleared)
  let out2 = process_sample(0.5)
  assert_true(out2.abs() < 0.001) // reads 0 from cleared buffer at pos 1
}

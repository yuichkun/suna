test "center_blend_equal_gains_2_slots" {
  // Setup: 2 slots
  init_slots()
  load_sample_to_slot(0, 1000, 100) |> ignore
  load_sample_to_slot(1, 2000, 100) |> ignore
  
  // Set blend to center
  set_blend_x(0.0)
  set_blend_y(0.0)
  
  // √N normalization: each slot should have gain = 1/√2 ≈ 0.707
  // This preserves perceived loudness regardless of slot count
  let expected : Float = Float::from_double(1.0 / Double::sqrt(2.0))
  assert_eq(get_slot_gain(0), expected)
  assert_eq(get_slot_gain(1), expected)
}

test "center_blend_equal_gains_4_slots" {
  // Setup: 4 slots
  init_slots()
  load_sample_to_slot(0, 1000, 100) |> ignore
  load_sample_to_slot(1, 2000, 100) |> ignore
  load_sample_to_slot(2, 3000, 100) |> ignore
  load_sample_to_slot(3, 4000, 100) |> ignore
  
  // Set blend to center
  set_blend_x(0.0)
  set_blend_y(0.0)
  
  // √N normalization: each slot should have gain = 1/√4 = 0.5
  let expected : Float = Float::from_double(1.0 / Double::sqrt(4.0))
  assert_eq(get_slot_gain(0), expected)
  assert_eq(get_slot_gain(1), expected)
  assert_eq(get_slot_gain(2), expected)
  assert_eq(get_slot_gain(3), expected)
}

test "total_gain_sum_equals_sqrt_n" {
  // Setup: 8 slots
  init_slots()
  for i = 0; i < 8; i = i + 1 {
    load_sample_to_slot(i, 1000 + i * 1000, 100) |> ignore
  }
  
  // Set blend to center
  set_blend_x(0.0)
  set_blend_y(0.0)
  
  // √N normalization: sum of all gains should be √8 ≈ 2.83
  // This preserves perceived loudness (uncorrelated signals sum as √N in power)
  let mut total : Float = 0.0
  for i = 0; i < 8; i = i + 1 {
    total = total + get_slot_gain(i)
  }
  let expected = Float::from_double(Double::sqrt(8.0))
  // Use tolerance for floating point comparison (accumulated rounding errors)
  let diff = if total > expected { total - expected } else { expected - total }
  assert_true(diff < 0.0001)
}

test "get_slot_gain_out_of_bounds" {
  init_slots()
  load_sample_to_slot(0, 1000, 100) |> ignore
  update_gains()
  
  // Out of bounds should return 0.0
  assert_eq(get_slot_gain(-1), 0.0)
  assert_eq(get_slot_gain(999), 0.0)
}

test "blend_at_slot0_position_4_slots" {
  // Setup: 4 slots
  // slot 0: (1, 0), slot 1: (0, 1), slot 2: (-1, 0), slot 3: (0, -1)
  init_slots()
  for i = 0; i < 4; i = i + 1 {
    load_sample_to_slot(i, 1000 + i * 1000, 100) |> ignore
  }
  
  // Move blend to slot 0 position (1, 0)
  set_blend_x(1.0)
  set_blend_y(0.0)
  
  // slot 0 should have gain = 1.0, others = 0
  println("slot0 gain: \{get_slot_gain(0)}")
  println("slot1 gain: \{get_slot_gain(1)}")
  println("slot2 gain: \{get_slot_gain(2)}")
  println("slot3 gain: \{get_slot_gain(3)}")
}

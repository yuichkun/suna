test "center_blend_equal_gains_2_slots" {
  // Setup: 2 slots
  init_slots()
  load_sample_to_slot(0, 1000, 100) |> ignore
  load_sample_to_slot(1, 2000, 100) |> ignore
  
  // Set blend to center
  set_blend_x(0.0)
  set_blend_y(0.0)
  
  // Each slot should have gain = 0.5
  assert_eq(get_slot_gain(0), 0.5)
  assert_eq(get_slot_gain(1), 0.5)
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
  
  // Each slot should have gain = 0.25
  assert_eq(get_slot_gain(0), 0.25)
  assert_eq(get_slot_gain(1), 0.25)
  assert_eq(get_slot_gain(2), 0.25)
  assert_eq(get_slot_gain(3), 0.25)
}

test "total_gain_never_exceeds_one" {
  // Setup: 8 slots
  init_slots()
  for i = 0; i < 8; i = i + 1 {
    load_sample_to_slot(i, 1000 + i * 1000, 100) |> ignore
  }
  
  // Set blend to center
  set_blend_x(0.0)
  set_blend_y(0.0)
  
  // Sum of all gains should be exactly 1.0
  let mut total : Float = 0.0
  for i = 0; i < 8; i = i + 1 {
    total = total + get_slot_gain(i)
  }
  assert_eq(total, 1.0)
}

test "get_slot_gain_out_of_bounds" {
  init_slots()
  load_sample_to_slot(0, 1000, 100) |> ignore
  update_gains()
  
  // Out of bounds should return 0.0
  assert_eq(get_slot_gain(-1), 0.0)
  assert_eq(get_slot_gain(999), 0.0)
}

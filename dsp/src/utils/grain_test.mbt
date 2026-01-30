///| Test suite for grain pool distribution and respawn logic

test "init_grain_pool creates 100 grains" {
  init_grain_pool()
  assert_eq(get_grain_count(), 100)
}

test "init_grain_pool sets all grains inactive" {
  init_grain_pool()
  let mut inactive_count = 0
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.active == 0 {
      inactive_count = inactive_count + 1
    }
  }
  assert_eq(inactive_count, 100)
}

test "distribute 100 grains across 4 slots equally" {
  init_grain_pool()
  distribute_grains(4)
  
  // Count grains per slot
  let mut slot0_count = 0
  let mut slot1_count = 0
  let mut slot2_count = 0
  let mut slot3_count = 0
  
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.slot == 0 { slot0_count = slot0_count + 1 }
    if grain.slot == 1 { slot1_count = slot1_count + 1 }
    if grain.slot == 2 { slot2_count = slot2_count + 1 }
    if grain.slot == 3 { slot3_count = slot3_count + 1 }
  }
  
  assert_eq(slot0_count, 25)
  assert_eq(slot1_count, 25)
  assert_eq(slot2_count, 25)
  assert_eq(slot3_count, 25)
}

test "distribute 100 grains across 3 slots with remainder" {
  init_grain_pool()
  distribute_grains(3)
  
  // Count grains per slot
  let mut slot0_count = 0
  let mut slot1_count = 0
  let mut slot2_count = 0
  
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.slot == 0 { slot0_count = slot0_count + 1 }
    if grain.slot == 1 { slot1_count = slot1_count + 1 }
    if grain.slot == 2 { slot2_count = slot2_count + 1 }
  }
  
  // First slot gets remainder (100 % 3 = 1 extra)
  assert_eq(slot0_count, 34)
  assert_eq(slot1_count, 33)
  assert_eq(slot2_count, 33)
}

test "distribute 100 grains across 1 slot gives all grains" {
  init_grain_pool()
  distribute_grains(1)
  
  let mut slot0_count = 0
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.slot == 0 { slot0_count = slot0_count + 1 }
  }
  
  assert_eq(slot0_count, 100)
}

test "distribute to 0 slots deactivates all grains" {
  init_grain_pool()
  distribute_grains(4)  // First activate some
  distribute_grains(0)  // Then deactivate all
  
  let mut active_count = 0
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.active == 1 { active_count = active_count + 1 }
  }
  
  assert_eq(active_count, 0)
}

test "distribute 100 grains across 2 slots equally" {
  init_grain_pool()
  distribute_grains(2)
  
  let mut slot0_count = 0
  let mut slot1_count = 0
  
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.slot == 0 { slot0_count = slot0_count + 1 }
    if grain.slot == 1 { slot1_count = slot1_count + 1 }
  }
  
  assert_eq(slot0_count, 50)
  assert_eq(slot1_count, 50)
}

test "distribute 100 grains across 8 slots equally" {
  init_grain_pool()
  distribute_grains(8)
  
  let counts : Array[Int] = []
  for i = 0; i < 8; i = i + 1 {
    counts.push(0)
  }
  
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.slot >= 0 && grain.slot < 8 {
      counts[grain.slot] = counts[grain.slot] + 1
    }
  }
  
  // 100 / 8 = 12 per slot, remainder 4
  // First 4 slots get 13, last 4 get 12
  assert_eq(counts[0], 13)
  assert_eq(counts[1], 13)
  assert_eq(counts[2], 13)
  assert_eq(counts[3], 13)
  assert_eq(counts[4], 12)
  assert_eq(counts[5], 12)
  assert_eq(counts[6], 12)
  assert_eq(counts[7], 12)
}

test "distributed grains are marked active" {
  init_grain_pool()
  distribute_grains(4)
  
  let mut active_count = 0
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.active == 1 { active_count = active_count + 1 }
  }
  
  assert_eq(active_count, 100)
}

test "get_grain out of bounds returns inactive grain" {
  init_grain_pool()
  
  let grain_neg = get_grain(-1)
  assert_eq(grain_neg.active, 0)
  assert_eq(grain_neg.slot, 0)
  
  let grain_high = get_grain(999)
  assert_eq(grain_high.active, 0)
  assert_eq(grain_high.slot, 0)
}

test "respawn_grain sets valid start position" {
  init_grain_pool()
  load_sample_to_slot(0, 1000, 10000) |> ignore
  set_grain_length(1000)
  distribute_grains(1)
  
  let grain = get_grain(0)
  // start_pos should be between 0 and (10000 - 1000) = 9000
  assert_eq(grain.start_pos >= 0, true)
  assert_eq(grain.start_pos <= 9000, true)
}

test "respawn_grain resets current_pos to 0" {
  init_grain_pool()
  load_sample_to_slot(0, 1000, 10000) |> ignore
  set_grain_length(1000)
  distribute_grains(1)
  
  let grain = get_grain(0)
  assert_eq(grain.current_pos, 0.0)
}

test "respawn_grain sets length correctly" {
  init_grain_pool()
  load_sample_to_slot(0, 1000, 10000) |> ignore
  set_grain_length(2000)
  distribute_grains(1)
  
  let grain = get_grain(0)
  assert_eq(grain.length, 2000)
}

test "respawn_grain clamps length to slot length" {
  init_grain_pool()
  load_sample_to_slot(0, 1000, 1000) |> ignore
  set_grain_length(5000)  // Request 5000, but slot only has 1000
  distribute_grains(1)
  
  let grain = get_grain(0)
  // Length should be clamped to slot length
  assert_eq(grain.length, 1000)
}

test "respawn_grain handles zero-length slot" {
  init_grain_pool()
  // Don't load any sample, slot has 0 length
  set_grain_length(1000)
  distribute_grains(1)
  
  let grain = get_grain(0)
  // Should handle gracefully
  assert_eq(grain.start_pos, 0)
  assert_eq(grain.current_pos, 0.0)
}

test "random_range produces values within bounds" {
  // Test multiple times to ensure consistency
  for test_run = 0; test_run < 10; test_run = test_run + 1 {
    for i = 0; i < 100; i = i + 1 {
      let val = random_range(0, 10)
      assert_eq(val >= 0, true)
      assert_eq(val < 10, true)
    }
  }
}

test "random_range with different bounds" {
  for i = 0; i < 100; i = i + 1 {
    let val = random_range(50, 100)
    assert_eq(val >= 50, true)
    assert_eq(val < 100, true)
  }
}

test "random_range with negative bounds" {
  for i = 0; i < 100; i = i + 1 {
    let val = random_range(-50, 50)
    assert_eq(val >= -50, true)
    assert_eq(val < 50, true)
  }
}

test "random_range with equal bounds returns min" {
  let val = random_range(10, 10)
  assert_eq(val, 10)
}

test "random_range with inverted bounds returns min" {
  let val = random_range(100, 50)
  assert_eq(val, 100)
}

test "update_grain_position increments current_pos" {
  init_grain_pool()
  load_sample_to_slot(0, 1000, 10000) |> ignore
  set_grain_length(1000)
  distribute_grains(1)
  
  let grain_before = get_grain(0)
  let pos_before = grain_before.current_pos
  
  update_grain_position(0, 100.5)
  
  let grain_after = get_grain(0)
  assert_eq(grain_after.current_pos, pos_before + 100.5)
}

test "update_grain_position deactivates when finished" {
  init_grain_pool()
  load_sample_to_slot(0, 1000, 10000) |> ignore
  set_grain_length(100)
  distribute_grains(1)
  
  // Update position beyond grain length
  update_grain_position(0, 150.0)
  
  let grain = get_grain(0)
  assert_eq(grain.active, 0)
}

test "set_grain_active activates grain" {
  init_grain_pool()
  distribute_grains(0)  // All inactive
  
  set_grain_active(0, 1)
  let grain = get_grain(0)
  assert_eq(grain.active, 1)
}

test "set_grain_active deactivates grain" {
  init_grain_pool()
  distribute_grains(4)  // All active
  
  set_grain_active(0, 0)
  let grain = get_grain(0)
  assert_eq(grain.active, 0)
}

test "get_grain_active returns correct state" {
  init_grain_pool()
  distribute_grains(4)
  
  let active = get_grain_active(0)
  assert_eq(active, 1)
  
  set_grain_active(0, 0)
  let inactive = get_grain_active(0)
  assert_eq(inactive, 0)
}

test "get_grain_active out of bounds returns 0" {
  init_grain_pool()
  
  let active_neg = get_grain_active(-1)
  assert_eq(active_neg, 0)
  
  let active_high = get_grain_active(999)
  assert_eq(active_high, 0)
}

test "grain_length getter returns set value" {
  set_grain_length(2048)
  let length = get_grain_length()
  assert_eq(length, 2048)
}

test "grain_length setter rejects non-positive values" {
  set_grain_length(1000)
  set_grain_length(0)  // Should be rejected
  let length = get_grain_length()
  assert_eq(length, 1000)  // Should remain unchanged
}

test "grain_length setter rejects negative values" {
  set_grain_length(1000)
  set_grain_length(-100)  // Should be rejected
  let length = get_grain_length()
  assert_eq(length, 1000)  // Should remain unchanged
}

test "distribute_grains with 5 slots" {
  init_grain_pool()
  distribute_grains(5)
  
  let counts : Array[Int] = []
  for i = 0; i < 5; i = i + 1 {
    counts.push(0)
  }
  
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.slot >= 0 && grain.slot < 5 {
      counts[grain.slot] = counts[grain.slot] + 1
    }
  }
  
  // 100 / 5 = 20 per slot, no remainder
  assert_eq(counts[0], 20)
  assert_eq(counts[1], 20)
  assert_eq(counts[2], 20)
  assert_eq(counts[3], 20)
  assert_eq(counts[4], 20)
}

test "distribute_grains with 7 slots" {
  init_grain_pool()
  distribute_grains(7)
  
  let counts : Array[Int] = []
  for i = 0; i < 7; i = i + 1 {
    counts.push(0)
  }
  
  for i = 0; i < 100; i = i + 1 {
    let grain = get_grain(i)
    if grain.slot >= 0 && grain.slot < 7 {
      counts[grain.slot] = counts[grain.slot] + 1
    }
  }
  
  // 100 / 7 = 14 per slot, remainder 2
  // First 2 slots get 15, rest get 14
  assert_eq(counts[0], 15)
  assert_eq(counts[1], 15)
  assert_eq(counts[2], 14)
  assert_eq(counts[3], 14)
  assert_eq(counts[4], 14)
  assert_eq(counts[5], 14)
  assert_eq(counts[6], 14)
}

test "total grain count always 100" {
  init_grain_pool()
  
  for slot_count = 0; slot_count <= 8; slot_count = slot_count + 1 {
    distribute_grains(slot_count)
    
    let mut total = 0
    for i = 0; i < 100; i = i + 1 {
      let grain = get_grain(i)
      if grain.active == 1 { total = total + 1 }
    }
    
    if slot_count > 0 {
      assert_eq(total, 100)
    } else {
      assert_eq(total, 0)
    }
  }
}

test "respawn_grain with small slot" {
  init_grain_pool()
  load_sample_to_slot(0, 1000, 100) |> ignore
  set_grain_length(50)
  distribute_grains(1)
  
  let grain = get_grain(0)
  // start_pos should be between 0 and (100 - 50) = 50
  assert_eq(grain.start_pos >= 0, true)
  assert_eq(grain.start_pos <= 50, true)
  assert_eq(grain.length, 50)
}

test "respawn_grain with grain_length equal to slot_length" {
  init_grain_pool()
  load_sample_to_slot(0, 1000, 1000) |> ignore
  set_grain_length(1000)
  distribute_grains(1)
  
  let grain = get_grain(0)
  assert_eq(grain.start_pos, 0)  // Only valid position
  assert_eq(grain.length, 1000)
}

test "multiple distributions reset grain state" {
  init_grain_pool()
  
  // First distribution
  distribute_grains(2)
  let grain1_first = get_grain(0)
  let slot1_first = grain1_first.slot
  
  // Second distribution
  distribute_grains(4)
  let grain1_second = get_grain(0)
  let slot1_second = grain1_second.slot
  
  // Slot assignment should change
  assert_eq(slot1_first, 0)
  assert_eq(slot1_second, 0)
  // But the grain should be re-initialized
  assert_eq(grain1_second.current_pos, 0.0)
}

// ============================================
// Envelope Tests
// ============================================

test "envelope returns 0 for zero length" {
  let env = calculate_envelope(0.0, 0)
  assert_eq(env, 0.0)
}

test "envelope returns 0 for negative length" {
  let env = calculate_envelope(0.0, -100)
  assert_eq(env, 0.0)
}

test "envelope at start is 0" {
  // At position 0, should be at start of attack ramp
  let env = calculate_envelope(0.0, 1000)
  assert_eq(env, 0.0)
}

test "envelope at end approaches 0" {
  // At position 999 (just before 1000), should be near 0
  let env = calculate_envelope(999.0, 1000)
  // With 10% release, release_start = 900
  // release_samples = 100
  // env = (1000 - 999) / 100 = 0.01
  assert_eq(env < 0.02, true)
  assert_eq(env >= 0.0, true)
}

test "envelope at middle is 1.0" {
  // At position 500, should be in sustain phase
  // attack ends at 100 (10%), release starts at 900 (90%)
  let env = calculate_envelope(500.0, 1000)
  assert_eq(env, 1.0)
}

test "envelope attack phase ramps up linearly" {
  // With 10% attack on 1000 samples, attack is 0-100 samples
  // At position 50, should be 0.5
  let env = calculate_envelope(50.0, 1000)
  assert_eq(env, 0.5)
}

test "envelope release phase ramps down linearly" {
  // With 10% release on 1000 samples, release starts at 900
  // At position 950, should be 0.5
  // release_samples = 100
  // env = (1000 - 950) / 100 = 0.5
  let env = calculate_envelope(950.0, 1000)
  assert_eq(env, 0.5)
}

test "envelope at attack boundary is 1.0" {
  // Attack ends at 100 (10% of 1000)
  let env = calculate_envelope(100.0, 1000)
  assert_eq(env, 1.0)
}

test "envelope at release boundary is 1.0" {
  // Release starts at 900 (90% of 1000)
  let env = calculate_envelope(899.0, 1000)
  assert_eq(env, 1.0)
}

test "envelope with short grain length" {
  // 100 samples: attack=10, release starts at 90
  let env_start = calculate_envelope(0.0, 100)
  let env_mid = calculate_envelope(50.0, 100)
  let env_end = calculate_envelope(99.0, 100)
  
  assert_eq(env_start, 0.0)
  assert_eq(env_mid, 1.0)
  assert_eq(env_end < 0.15, true) // Should be close to 0
}

test "envelope never exceeds 1.0" {
  // Test various positions
  for i = 0; i < 100; i = i + 1 {
    let pos = Float::from_int(i * 10)
    let env = calculate_envelope(pos, 1000)
    assert_eq(env <= 1.0, true)
  }
}

test "envelope never goes negative" {
  // Test various positions including beyond length
  for i = 0; i < 120; i = i + 1 {
    let pos = Float::from_int(i * 10)
    let env = calculate_envelope(pos, 1000)
    assert_eq(env >= 0.0, true)
  }
}

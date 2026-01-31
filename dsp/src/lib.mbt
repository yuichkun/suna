///|
let previous_slot_count : Ref[Int] = { val: 0 }

///|
let grain_pool_initialized : Ref[Bool] = { val: false }

///|
fn init {
  println("initialized")
}

///|
pub fn process_block(
  state_ptr : Int,
  left_in_ptr : Int,
  right_in_ptr : Int,
  left_out_ptr : Int,
  right_out_ptr : Int,
  num_samples : Int,
) -> Int {
  let _ = (state_ptr, left_in_ptr, right_in_ptr)

  // Initialize grain pool on first call
  if grain_pool_initialized.val == false {
    @utils.init_grain_pool()
    grain_pool_initialized.val = true
  }

  // Redistribute grains when slot count changes
  let slot_count = @utils.get_slot_count()
  if slot_count != previous_slot_count.val {
    @utils.distribute_grains(slot_count)
    previous_slot_count.val = slot_count
  }
  let speed = @utils.get_playback_speed()
  let abs_speed = if speed < 0.0 { -speed } else { speed }
  let reverse = speed < 0.0
  let active_grain_count = @utils.get_active_grain_count()
  for i = 0; i < num_samples; i = i + 1 {
    // Smooth gains toward target (prevents clicks on blend changes)
    @utils.smooth_gains()
    let offset = i * @utils.float32_size
    let mut out : Float = 0.0
    let mut active_count = 0
    for grain_idx = 0; grain_idx < active_grain_count; grain_idx = grain_idx + 1 {
      let grain = @utils.get_grain(grain_idx)

      // Skip inactive grains
      if grain.active == 0 {
        continue
      }
      let slot = grain.slot
      let slot_len = @utils.get_slot_sample_length(slot)

      // Skip grains in empty slots
      if slot_len <= 0 {
        continue
      }

      // Calculate position within grain (reverse if speed < 0)
      let pos_in_grain = if reverse {
        // Reverse: read from end to start
        grain.length - 1 - grain.current_pos.to_int()
      } else {
        // Forward: read from start to end
        grain.current_pos.to_int()
      }

      // Read sample at grain position (start_pos + pos_in_grain)
      let ptr = @utils.get_slot_data_ptr(slot)
      let pos_int = (grain.start_pos + pos_in_grain) % slot_len
      let sample = @utils.load_f32(ptr + pos_int * @utils.float32_size)

      // Apply grain envelope (smooths start/end to prevent clicks)
      let envelope = @utils.calculate_envelope(grain.current_pos, grain.length)

      // Apply slot gain (from blend XY)
      let gain = @utils.get_slot_gain(slot)
      out = out + sample * envelope * gain
      active_count = active_count + 1

      // Advance grain position by absolute speed (always positive)
      @utils.update_grain_position(grain_idx, abs_speed)

      // Respawn grain if it finished (was deactivated by update_grain_position)
      if grain.active == 0 && slot_len > 0 {
        @utils.respawn_grain(grain_idx)
      }
    }

    // Normalize by sqrt of active grain count (preserve perceived loudness)
    if active_count > 0 {
      out = out / Float::from_int(active_count).sqrt()
    }
    @utils.store_f32(left_out_ptr + offset, out)
    @utils.store_f32(right_out_ptr + offset, out)
  }
  0
}

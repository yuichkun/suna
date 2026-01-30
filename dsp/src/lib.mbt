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
  let slot_count = @utils.get_slot_count()
  let speed = @utils.get_playback_speed()
  for i = 0; i < num_samples; i = i + 1 {
    let offset = i * @utils.float32_size
    let mut out : Float = 0.0
    for slot = 0; slot < slot_count; slot = slot + 1 {
      let pos = @utils.get_slot_play_pos(slot)
      let len = @utils.get_slot_sample_length(slot)
      let pos_int = pos.to_int()
      if pos_int >= 0 && pos_int < len {
        let ptr = @utils.get_slot_data_ptr(slot)
        let sample = @utils.load_f32(ptr + pos_int * @utils.float32_size)
        let gain = @utils.get_slot_gain(slot)
        out = out + sample * gain
      }
      @utils.set_slot_play_pos(slot, pos + speed)
    }
    @utils.store_f32(left_out_ptr + offset, out)
    @utils.store_f32(right_out_ptr + offset, out)
  }
  0
}

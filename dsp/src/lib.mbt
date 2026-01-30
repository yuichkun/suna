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
  num_samples : Int
) -> Int {
  let _ = (state_ptr, left_in_ptr, right_in_ptr)
  
  for i = 0; i < num_samples; i = i + 1 {
    let offset = i * 4
    let mut out : Float = 0.0
    
    if @utils.get_slot_playing_state(0) == 1 {
      let pos = @utils.get_slot_play_pos(0)
      let len = @utils.get_slot_sample_length(0)
      
      if pos < len {
        let ptr = @utils.get_slot_data_ptr(0)
        out = @utils.load_f32(ptr + pos * 4)
        @utils.set_slot_play_pos(0, pos + 1)
      } else {
        @utils.set_slot_playing(0, 0)
      }
    }
    
    @utils.store_f32(left_out_ptr + offset, out)
    @utils.store_f32(right_out_ptr + offset, out)
  }
  0
}

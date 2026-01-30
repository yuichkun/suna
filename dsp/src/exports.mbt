///|
pub fn init_sampler(sr : Float) -> Int {
  @utils.set_sample_rate(sr)
  @utils.init_slots()
  0
}

///|
pub fn load_sample(slot : Int, data_ptr : Int, length : Int) -> Int {
  @utils.load_sample_to_slot(slot, data_ptr, length)
}

///|
pub fn clear_slot(slot : Int) -> Int {
  @utils.clear_slot_data(slot)
}

///|
pub fn play_all() -> Int {
  @utils.start_all_slots()
  0
}

///|
pub fn stop_all() -> Int {
  @utils.stop_all_slots()
  0
}

///|
pub fn get_slot_length(slot : Int) -> Int {
  @utils.get_slot_sample_length(slot)
}

///|
pub fn set_blend_x(value : Float) -> Int {
  @utils.set_blend_x(value)
  0
}

///|
pub fn set_blend_y(value : Float) -> Int {
  @utils.set_blend_y(value)
  0
}

///|
pub fn set_playback_speed(speed : Float) -> Int {
  @utils.set_playback_speed(speed)
  0
}

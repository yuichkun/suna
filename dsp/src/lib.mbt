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
  let _ = state_ptr
  for i = 0; i < num_samples; i = i + 1 {
    let offset = i * 4
    let left_in = @utils.load_f32(left_in_ptr + offset)
    let right_in = @utils.load_f32(right_in_ptr + offset)
    let left_out = left_in
    let right_out = right_in
    @utils.store_f32(left_out_ptr + offset, left_out)
    @utils.store_f32(right_out_ptr + offset, right_out)
  }
  0
}

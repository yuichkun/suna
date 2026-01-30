///|
pub extern "wasm" fn load_f32(ptr : Int) -> Float =
  #|(func (param i32) (result f32) (f32.load (local.get 0)))

///|
pub extern "wasm" fn store_f32(ptr : Int, value : Float) =
  #|(func (param i32 f32) (f32.store (local.get 0) (local.get 1)))

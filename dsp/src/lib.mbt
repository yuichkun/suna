///|
pub fn multiply(a : Float, b : Float) -> Float {
  a * b
}

///|
pub fn add(a : Float, b : Float) -> Float {
  a + b
}

// グローバル状態 (linear memory内) - using Ref for mutable state

///|
let counter : Ref[Int] = { val: 0 }

///|
pub fn increment() -> Int {
  counter.val = counter.val + 1
  counter.val
}

///|
pub fn get_counter() -> Int {
  counter.val
}

///|
fn main {
  // Minimal main function for WASM module
}

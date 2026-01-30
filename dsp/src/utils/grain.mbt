///| Grain struct for granular synthesis
pub struct Grain {
  mut slot : Int
  mut start_pos : Int
  mut current_pos : Float
  mut length : Int
  mut active : Int
}

///| Global grain pool (100 grains)
let grains : Array[Grain] = []

///| Global grain length in samples (controlled by UI)
let grain_length : Ref[Int] = { val: 4224 }

///| LCG random seed
let random_seed : Ref[Int] = { val: 12345 }

///| Get current grain length
pub fn get_grain_length() -> Int {
  grain_length.val
}

///| Set grain length (in samples)
pub fn set_grain_length(length : Int) -> Unit {
  if length > 0 {
    grain_length.val = length
  }
}

///| LCG random number generator
///| Returns next pseudo-random integer
fn random_next() -> Int {
  let a = 1103515245
  let c = 12345
  let m = 2147483647  // 2^31 - 1 (max Int32)
  random_seed.val = ((a * random_seed.val + c) % m)
  random_seed.val
}

///| Generate random integer in range [min, max)
pub fn random_range(min : Int, max : Int) -> Int {
  if max <= min {
    return min
  }
  let range = max - min
  let rand_val = random_next()
  // Handle negative values from LCG by taking absolute value
  let abs_rand = if rand_val < 0 { -rand_val } else { rand_val }
  min + (abs_rand % range)
}

///| Initialize grain pool with 100 inactive grains
pub fn init_grain_pool() -> Unit {
  grains.clear()
  for i = 0; i < 100; i = i + 1 {
    grains.push({
      slot: 0,
      start_pos: 0,
      current_pos: 0.0,
      length: 0,
      active: 0,
    })
  }
}

///| Respawn a grain with random position within its slot
pub fn respawn_grain(index : Int) -> Unit {
  if index < 0 || index >= grains.length() {
    return
  }
  
  let grain = grains[index]
  let slot_length = get_slot_sample_length(grain.slot)
  let g_length = get_grain_length()
  
  // Clamp grain length to slot length
  let clamped_length = if g_length > slot_length {
    slot_length
  } else {
    g_length
  }
  
  // Calculate valid range for start position
  let max_start = if slot_length > clamped_length {
    slot_length - clamped_length
  } else {
    0
  }
  
  // Set random start position
  let start = if max_start > 0 {
    random_range(0, max_start + 1)
  } else {
    0
  }
  
  grain.start_pos = start
  grain.current_pos = 0.0
  grain.length = clamped_length
  grain.active = 1
}

///| Distribute 100 grains equally across active slots
///| Remainder grains go to first slots
pub fn distribute_grains(active_slot_count : Int) -> Unit {
  if active_slot_count <= 0 {
    // Deactivate all grains
    for i = 0; i < grains.length(); i = i + 1 {
      grains[i].active = 0
    }
    return
  }
  
  let grains_per_slot = 100 / active_slot_count
  let remainder = 100 % active_slot_count
  
  let mut grain_idx = 0
  for slot = 0; slot < active_slot_count; slot = slot + 1 {
    let count = if slot < remainder {
      grains_per_slot + 1
    } else {
      grains_per_slot
    }
    
    for i = 0; i < count; i = i + 1 {
      if grain_idx < grains.length() {
        grains[grain_idx].slot = slot
        respawn_grain(grain_idx)
        grain_idx = grain_idx + 1
      }
    }
  }
  
  // Deactivate remaining grains (if any)
  while grain_idx < grains.length() {
    grains[grain_idx].active = 0
    grain_idx = grain_idx + 1
  }
}

///| Get grain by index
pub fn get_grain(index : Int) -> Grain {
  if index < 0 || index >= grains.length() {
    return { slot: 0, start_pos: 0, current_pos: 0.0, length: 0, active: 0 }
  }
  grains[index]
}

///| Get total grain count
pub fn get_grain_count() -> Int {
  100
}

///| Update grain current position (called during processing)
pub fn update_grain_position(index : Int, delta : Float) -> Unit {
  if index < 0 || index >= grains.length() {
    return
  }
  let grain = grains[index]
  grain.current_pos = grain.current_pos + delta
  
  // Deactivate if grain has finished
  if grain.current_pos >= Float::from_int(grain.length) {
    grain.active = 0
  }
}

///| Set grain active state
pub fn set_grain_active(index : Int, active : Int) -> Unit {
  if index >= 0 && index < grains.length() {
    grains[index].active = active
  }
}

///| Get grain active state
pub fn get_grain_active(index : Int) -> Int {
  if index < 0 || index >= grains.length() {
    return 0
  }
  grains[index].active
}

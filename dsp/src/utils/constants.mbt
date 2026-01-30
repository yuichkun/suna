///| Size of Float32 in bytes
pub let float32_size : Int = 4

///| Default sample rate (Hz)
pub let default_sample_rate : Float = 48000.0

// ============================================
// Grain Constants
// ============================================

///| Total number of grains in the pool
pub let total_grain_count : Int = 100

///| Envelope attack ratio (0.1 = 10% of grain length)
pub let envelope_attack_ratio : Float = 0.1

///| Envelope release ratio (0.1 = 10% of grain length)
pub let envelope_release_ratio : Float = 0.1

// ============================================
// Blend Constants
// ============================================

///| Gain smoothing coefficient (0.01 = ~2.3ms at 44.1kHz)
pub let gain_smooth_coeff : Float = 0.01

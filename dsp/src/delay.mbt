// Single-tap delay effect implementation
// Uses global state with FixedArray for GC-minimized design

// グローバル状態 (モジュールレベル、linear memory内)
// Max 2 seconds @ 48kHz = 96000 samples
///|
let delay_buffer : FixedArray[Float] = FixedArray::make(96000 * 2, 0.0)

///|
let write_pos : Ref[Int] = { val: 0 }

///|
let sample_rate : Ref[Float] = { val: 44100.0 }

///|
let delay_samples : Ref[Int] = { val: 0 }

///|
let feedback : Ref[Float] = { val: 0.3 }

///|
let mix : Ref[Float] = { val: 0.5 }

// Debug sine wave state (220Hz for DSP verification)

///|
let sine_phase : Ref[Float] = { val: 0.0 }

// Constants for sine generation

///|
let pi : Float = 3.14159265358979

///|
let two_pi : Float = 6.28318530717958

///|
/// Taylor series sine approximation (5-term, no native sin in WASM)
/// Input should be normalized to [-π, π] for best accuracy
fn sine_approx(x : Float) -> Float {
  let x2 = x * x
  let x3 = x2 * x
  let x5 = x3 * x2
  let x7 = x5 * x2
  x - x3 / 6.0 + x5 / 120.0 - x7 / 5040.0
}

///|
/// Generate sine wave sample and advance phase
/// Returns sine value with amplitude 0.3 at 220Hz
fn generate_sine() -> Float {
  // Normalize phase to [-π, π] for Taylor series accuracy
  let normalized = sine_phase.val - pi
  let sine_val = sine_approx(normalized) * 0.3

  // Advance phase: 2π * 220 / sample_rate
  let phase_inc = two_pi * 220.0 / sample_rate.val
  sine_phase.val = sine_phase.val + phase_inc

  // Wrap phase to prevent overflow
  if sine_phase.val >= two_pi {
    sine_phase.val = sine_phase.val - two_pi
  }
  sine_val
}

///|
/// Initialize delay processor
/// Returns 0 on success
pub fn init_delay(sr : Float, max_delay_ms : Float) -> Int {
  sample_rate.val = sr
  write_pos.val = 0
  // Clear buffer
  let buffer_size = delay_buffer.length()
  for i = 0; i < buffer_size; i = i + 1 {
    delay_buffer[i] = 0.0
  }
  // Set default delay time based on max_delay_ms (use 1/4 of max as default)
  let default_ms = max_delay_ms / 4.0
  set_delay_time(default_ms)
  0 // success
}

///|
/// Set delay time in milliseconds
pub fn set_delay_time(ms : Float) -> Unit {
  let samples = (ms * sample_rate.val / 1000.0).to_int()
  let max_samples = delay_buffer.length()
  delay_samples.val = if samples < 0 {
    0
  } else if samples > max_samples {
    max_samples
  } else {
    samples
  }
}

///|
/// Set feedback amount (0.0-1.0)
pub fn set_feedback(value : Float) -> Unit {
  feedback.val = if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
/// Set dry/wet mix (0.0-1.0)
pub fn set_mix(value : Float) -> Unit {
  mix.val = if value < 0.0 { 0.0 } else if value > 1.0 { 1.0 } else { value }
}

///|
/// Process single sample through delay (internal use)
/// Returns the WET signal only (delayed sample)
fn process_sample_wet(input : Float) -> Float {
  let buffer_size = delay_buffer.length()

  // Calculate read position (circular buffer)
  let read_pos = if write_pos.val >= delay_samples.val {
    write_pos.val - delay_samples.val
  } else {
    buffer_size - (delay_samples.val - write_pos.val)
  }

  // Read delayed sample
  let delayed = delay_buffer[read_pos]

  // Write input + feedback to buffer
  let output = input + delayed * feedback.val
  delay_buffer[write_pos.val] = output

  // Advance write position
  write_pos.val = (write_pos.val + 1) % buffer_size

  // Return wet signal only
  delayed
}

///|
/// Process stereo sample pair through delay (Kodama mono-sum pattern)
/// Mixes stereo to mono, processes once, returns mixed output for both channels
pub fn process_stereo(left_in : Float, right_in : Float) -> (Float, Float) {
  // Mix stereo to mono (like Kodama)
  let mono_in = (left_in + right_in) * 0.5

  // Process through delay ONCE (single buffer advance per stereo pair)
  let wet = process_sample_wet(mono_in)

  // DEBUG: Add 220Hz sine wave to wet signal for DSP verification
  let wet_with_sine = wet + generate_sine()

  // Apply dry/wet mix to both channels (sine only affects wet signal)
  let left_out = left_in * (1.0 - mix.val) + wet_with_sine * mix.val
  let right_out = right_in * (1.0 - mix.val) + wet_with_sine * mix.val
  (left_out, right_out)
}

///|
/// Process single sample through delay (legacy, for backwards compatibility)
pub fn process_sample(input : Float) -> Float {
  let wet = process_sample_wet(input)
  // Mix dry/wet
  input * (1.0 - mix.val) + wet * mix.val
}

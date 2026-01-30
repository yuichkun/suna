class SunaProcessor extends AudioWorkletProcessor {
  constructor() {
    super();

    this.wasm = null;
    this.leftInPtr = null;
    this.rightInPtr = null;
    this.leftOutPtr = null;
    this.rightOutPtr = null;
    this.initialized = false;

    // DEBUG: Peak level monitoring
    this.peakLevel = 0;
    this.sampleCount = 0;

    this.port.onmessage = (event) => {
      const { type } = event.data;
      if (type === 'init') {
        this.initWasm(event.data.wasmBytes);
      } else if (type === 'loadSample') {
        this.handleLoadSample(event.data.slot, event.data.pcmData, event.data.sampleRate);
      } else if (type === 'clearSlot') {
        this.handleClearSlot(event.data.slot);
      } else if (type === 'playAll') {
        this.handlePlayAll();
      } else if (type === 'stopAll') {
        this.handleStopAll();
      } else if (type === 'setBlendX') {
        this.handleSetBlendX(event.data.value);
      } else if (type === 'setBlendY') {
        this.handleSetBlendY(event.data.value);
      } else if (type === 'setPlaybackSpeed') {
        this.handleSetPlaybackSpeed(event.data.value);
      } else if (type === 'setGrainLength') {
        this.handleSetGrainLength(event.data.length);
      } else if (type === 'setGrainDensity') {
        this.handleSetGrainDensity(event.data.density);
      } else if (type === 'setFreeze') {
        this.handleSetFreeze(event.data.freeze);
      }
    };
  }

  async initWasm(wasmBytes) {
    try {
      // Buffer for println output (flushes on newline)
      let printBuffer = [];
      const importObject = {
        spectest: {
          print_char: (charCode) => {
            if (charCode === 10) {
              console.log('[WASM]', printBuffer.map(c => String.fromCharCode(c)).join(''));
              printBuffer = [];
            } else {
              printBuffer.push(charCode);
            }
          }
        }
      };

      const wasmModule = await WebAssembly.compile(wasmBytes);
      const instance = await WebAssembly.instantiate(wasmModule, importObject);
      this.wasm = instance.exports;

      this.wasm.init_sampler(sampleRate);

      const BLOCK_SIZE = 128;
      const BYTES_PER_FLOAT = 4;
      const bufferSize = BLOCK_SIZE * BYTES_PER_FLOAT;
      const BUFFER_START = 900000;

      this.leftInPtr = BUFFER_START;
      this.rightInPtr = BUFFER_START + bufferSize;
      this.leftOutPtr = BUFFER_START + bufferSize * 2;
      this.rightOutPtr = BUFFER_START + bufferSize * 3;

      this.initialized = true;
      this.port.postMessage({ type: 'ready' });
    } catch (error) {
      this.port.postMessage({ type: 'error', message: error.message });
    }
  }

  handleLoadSample(slot, pcmData, sampleRate) {
    if (!this.wasm) return;

    const SAMPLE_DATA_START = 1000000;
    const MAX_SAMPLES_PER_SLOT = 1440000;
    const BYTES_PER_FLOAT = 4;
    
    const slotOffset = SAMPLE_DATA_START + (slot * MAX_SAMPLES_PER_SLOT * BYTES_PER_FLOAT);
    const numSamples = Math.min(pcmData.length, MAX_SAMPLES_PER_SLOT);
    
    const memory = this.wasm.memory;
    const sampleView = new Float32Array(memory.buffer, slotOffset, numSamples);
    sampleView.set(pcmData.subarray(0, numSamples));
    
    this.wasm.load_sample(slot, slotOffset, numSamples);
  }

  handleClearSlot(slot) {
    if (!this.wasm) return;
    this.wasm.clear_slot(slot);
  }

  handlePlayAll() {
    if (!this.wasm) return;
    this.wasm.play_all();
  }

  handleStopAll() {
    if (!this.wasm) return;
    this.wasm.stop_all();
  }

  handleSetBlendX(value) {
    if (!this.wasm) return;
    this.wasm.set_blend_x(value);
  }

  handleSetBlendY(value) {
    if (!this.wasm) return;
    this.wasm.set_blend_y(value);
  }

  handleSetPlaybackSpeed(value) {
    if (!this.wasm) return;
    this.wasm.set_playback_speed(value);
  }

  handleSetGrainLength(length) {
    if (!this.wasm) return;
    this.wasm.set_grain_length(length);
  }

  handleSetGrainDensity(density) {
    if (!this.wasm) return;
    this.wasm.set_grain_density(density);
  }

  handleSetFreeze(freeze) {
    if (!this.wasm) return;
    this.wasm.set_freeze(freeze ? 1 : 0);
  }

  process(inputs, outputs) {
    if (!this.initialized || !this.wasm) return true;

    const output = outputs[0];
    if (!output || output.length === 0) return true;

    const input = inputs[0];
    const leftIn = input?.[0] || new Float32Array(output[0].length);
    const rightIn = input?.[1] || input?.[0] || new Float32Array(output[0].length);
    const leftOut = output[0];
    const rightOut = output[1] || output[0];
    const numSamples = leftOut.length;

    const memory = this.wasm.memory;
    const leftInView = new Float32Array(memory.buffer, this.leftInPtr, numSamples);
    const rightInView = new Float32Array(memory.buffer, this.rightInPtr, numSamples);
    const leftOutView = new Float32Array(memory.buffer, this.leftOutPtr, numSamples);
    const rightOutView = new Float32Array(memory.buffer, this.rightOutPtr, numSamples);

    leftInView.set(leftIn);
    rightInView.set(rightIn);

    this.wasm.process_block(
      0,
      this.leftInPtr,
      this.rightInPtr,
      this.leftOutPtr,
      this.rightOutPtr,
      numSamples
    );

    leftOut.set(leftOutView);
    rightOut.set(rightOutView);

    // DEBUG: Peak level monitoring
    let peak = 0;
    for (let i = 0; i < leftOut.length; i++) {
      peak = Math.max(peak, Math.abs(leftOut[i]));
    }
    this.peakLevel = Math.max(this.peakLevel, peak);
    this.sampleCount += leftOut.length;

    if (this.sampleCount >= 44100) {
      console.log('[LEVEL] peak:', this.peakLevel.toFixed(4));
      this.peakLevel = 0;
      this.sampleCount = 0;
    }

    return true;
  }
}

registerProcessor('suna-processor', SunaProcessor);

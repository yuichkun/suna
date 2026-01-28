class SunaProcessor extends AudioWorkletProcessor {
  constructor() {
    super();

    this.wasm = null;
    this.leftInPtr = null;
    this.rightInPtr = null;
    this.leftOutPtr = null;
    this.rightOutPtr = null;
    this.initialized = false;

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
      }
    };
  }

  async initWasm(wasmBytes) {
    try {
      const wasmModule = await WebAssembly.compile(wasmBytes);
      const instance = await WebAssembly.instantiate(wasmModule, {});
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
    const MAX_SAMPLES_PER_SLOT = 480000;
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

  process(inputs, outputs) {
    if (!this.initialized || !this.wasm) return true;

    const input = inputs[0];
    const output = outputs[0];
    if (!input || input.length === 0 || !input[0]) return true;

    const leftIn = input[0];
    const rightIn = input[1] || input[0];
    const leftOut = output[0];
    const rightOut = output[1] || output[0];
    const numSamples = leftIn.length;

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

    return true;
  }
}

registerProcessor('suna-processor', SunaProcessor);

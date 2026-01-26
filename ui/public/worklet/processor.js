class SunaProcessor extends AudioWorkletProcessor {
  constructor() {
    super();

    this.wasmInstance = null;
    this.memory = null;
    this.leftInPtr = 0;
    this.rightInPtr = 0;
    this.leftOutPtr = 0;
    this.rightOutPtr = 0;
    this.initialized = false;

    this.port.onmessage = (event) => {
      if (event.data.type === 'init') {
        this.initWasm(event.data.wasmModule);
      } else if (event.data.type === 'param') {
        this.updateParam(event.data.name, event.data.value);
      }
    };
  }

  async initWasm(wasmModule) {
    const importObject = {
      env: {
        memory: new WebAssembly.Memory({ initial: 32 }),
      },
    };

    const instance = await WebAssembly.instantiate(wasmModule, importObject);
    this.wasmInstance = instance;
    this.memory = instance.exports.memory;

    const SAMPLES_PER_BLOCK = 128;
    const BYTES_PER_FLOAT = 4;
    const bufferSize = SAMPLES_PER_BLOCK * BYTES_PER_FLOAT;
    const BUFFER_START = 900000; // Must match C++ WasmDSP::BUFFER_START

    this.leftInPtr = BUFFER_START;
    this.rightInPtr = BUFFER_START + bufferSize;
    this.leftOutPtr = BUFFER_START + bufferSize * 2;
    this.rightOutPtr = BUFFER_START + bufferSize * 3;

    instance.exports.init_delay(sampleRate, 2000.0);

    this.initialized = true;
    this.port.postMessage({ type: 'ready' });
  }

  updateParam(name, value) {
    if (!this.wasmInstance) return;

    switch (name) {
      case 'delayTime':
        this.wasmInstance.exports.set_delay_time(value);
        break;
      case 'feedback':
        this.wasmInstance.exports.set_feedback(value / 100.0);
        break;
      case 'mix':
        this.wasmInstance.exports.set_mix(value / 100.0);
        break;
    }
  }

  process(inputs, outputs, parameters) {
    if (!this.initialized || !inputs[0] || !outputs[0]) {
      return true;
    }

    const input = inputs[0];
    const output = outputs[0];
    const leftIn = input[0] || new Float32Array(128);
    const rightIn = input[1] || input[0] || new Float32Array(128);
    const leftOut = output[0];
    const rightOut = output[1] || output[0];

    const numSamples = leftIn.length;
    const BYTES_PER_FLOAT = 4;

    const memoryView = new Float32Array(this.memory.buffer);
    const leftInOffset = this.leftInPtr / BYTES_PER_FLOAT;
    const rightInOffset = this.rightInPtr / BYTES_PER_FLOAT;
    const leftOutOffset = this.leftOutPtr / BYTES_PER_FLOAT;
    const rightOutOffset = this.rightOutPtr / BYTES_PER_FLOAT;

    memoryView.set(leftIn, leftInOffset);
    memoryView.set(rightIn, rightInOffset);

    this.wasmInstance.exports.process_block(
      0,
      this.leftInPtr,
      this.rightInPtr,
      this.leftOutPtr,
      this.rightOutPtr,
      numSamples
    );

    leftOut.set(memoryView.subarray(leftOutOffset, leftOutOffset + numSamples));
    rightOut.set(memoryView.subarray(rightOutOffset, rightOutOffset + numSamples));

    return true;
  }
}

registerProcessor('suna-processor', SunaProcessor);

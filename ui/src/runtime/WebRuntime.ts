import type { Runtime } from './types';

export class WebRuntime implements Runtime {
  private audioContext: AudioContext | null = null;
  private workletNode: AudioWorkletNode | null = null;
  private sourceNode: MediaStreamAudioSourceNode | null = null;

  async initialize(): Promise<void> {
    this.audioContext = new AudioContext();

    await this.audioContext.audioWorklet.addModule('/worklet/processor.js');

    this.workletNode = new AudioWorkletNode(this.audioContext, 'suna-processor');

    const wasmResponse = await fetch('/wasm/suna_dsp.wasm');
    const wasmBuffer = await wasmResponse.arrayBuffer();
    const wasmModule = await WebAssembly.compile(wasmBuffer);

    this.workletNode.port.postMessage({ type: 'init', wasmModule });

    await new Promise<void>((resolve) => {
      this.workletNode!.port.onmessage = (event) => {
        if (event.data.type === 'ready') {
          resolve();
        }
      };
    });

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    this.sourceNode = this.audioContext.createMediaStreamSource(stream);

    this.sourceNode.connect(this.workletNode);
    this.workletNode.connect(this.audioContext.destination);
  }

  setDelayTime(ms: number): void {
    this.workletNode?.port.postMessage({ type: 'param', name: 'delayTime', value: ms });
  }

  setFeedback(percent: number): void {
    this.workletNode?.port.postMessage({ type: 'param', name: 'feedback', value: percent });
  }

  setMix(percent: number): void {
    this.workletNode?.port.postMessage({ type: 'param', name: 'mix', value: percent });
  }

  destroy(): void {
    this.workletNode?.disconnect();
    this.sourceNode?.disconnect();
    this.audioContext?.close();
  }
}

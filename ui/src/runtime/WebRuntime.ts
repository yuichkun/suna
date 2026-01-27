import type { Runtime } from './types';

export class WebRuntime implements Runtime {
  private audioContext: AudioContext | null = null;
  private workletNode: AudioWorkletNode | null = null;
  private sourceNode: AudioBufferSourceNode | null = null;
  private audioBuffer: AudioBuffer | null = null;
  private isPlaying = false;

  async initialize(): Promise<void> {
    this.audioContext = new AudioContext();

    await this.audioContext.audioWorklet.addModule('/worklet/processor.js');

    this.workletNode = new AudioWorkletNode(this.audioContext, 'suna-processor');

    const wasmResponse = await fetch('/wasm/suna_dsp.wasm');
    const wasmBytes = await wasmResponse.arrayBuffer();

    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('WASM init timeout')), 5000);

      this.workletNode!.port.onmessage = (event) => {
        if (event.data.type === 'ready') {
          clearTimeout(timeout);
          resolve();
        } else if (event.data.type === 'error') {
          clearTimeout(timeout);
          reject(new Error(event.data.message));
        }
      };

      this.workletNode!.port.postMessage({ type: 'init', wasmBytes });
    });

    this.workletNode.connect(this.audioContext.destination);
  }

  async loadAudioFile(file: File): Promise<void> {
    if (!this.audioContext) throw new Error('Runtime not initialized');
    const arrayBuffer = await file.arrayBuffer();
    this.audioBuffer = await this.audioContext.decodeAudioData(arrayBuffer);
  }

  play(): void {
    if (!this.audioContext || !this.audioBuffer || !this.workletNode) return;
    this.stop();

    this.sourceNode = this.audioContext.createBufferSource();
    this.sourceNode.buffer = this.audioBuffer;
    this.sourceNode.loop = true;
    this.sourceNode.connect(this.workletNode);
    this.sourceNode.start();
    this.isPlaying = true;
  }

  stop(): void {
    if (this.sourceNode) {
      try {
        this.sourceNode.stop();
      } catch {
      }
      this.sourceNode.disconnect();
      this.sourceNode = null;
    }
    this.isPlaying = false;
  }

  getIsPlaying(): boolean {
    return this.isPlaying;
  }

  hasAudioLoaded(): boolean {
    return this.audioBuffer !== null;
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
    this.stop();
    this.workletNode?.disconnect();
    this.audioContext?.close();
  }
}

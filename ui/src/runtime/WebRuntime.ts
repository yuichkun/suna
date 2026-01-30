import type { AudioRuntime, ParameterState, ParameterProperties } from './types';

export class WebRuntime implements AudioRuntime {
  readonly type = 'web' as const
  private audioContext: AudioContext | null = null;
  private workletNode: AudioWorkletNode | null = null;
  private parameterValues: Record<string, number> = {};
  private parameterCallbacks: Record<string, Set<(value: number) => void>> = {};
  private parameterConfigs: Record<string, ParameterProperties> = {};

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

  async loadSample(slot: number, pcmData: Float32Array, sampleRate: number): Promise<void> {
    if (!this.workletNode) throw new Error('Runtime not initialized');
    this.workletNode.port.postMessage(
      { type: 'loadSample', slot, pcmData, sampleRate },
      [pcmData.buffer]
    );
  }

  clearSlot(slot: number): void {
    this.workletNode?.port.postMessage({ type: 'clearSlot', slot });
  }

  playAll(): void {
    this.audioContext?.resume();
    this.workletNode?.port.postMessage({ type: 'playAll' });
  }

  stopAll(): void {
    this.workletNode?.port.postMessage({ type: 'stopAll' });
  }

  setBlendX(value: number): void {
    this.workletNode?.port.postMessage({ type: 'setBlendX', value });
  }

  setBlendY(value: number): void {
    this.workletNode?.port.postMessage({ type: 'setBlendY', value });
  }

  setPlaybackSpeed(speed: number): void {
    this.workletNode?.port.postMessage({ type: 'setPlaybackSpeed', value: speed });
  }

  getParameter(id: string): ParameterState | null {
    const config = this.parameterConfigs[id];
    if (!config) return null;

    return {
      getNormalisedValue: () => {
        const value = this.parameterValues[id] ?? 0;
        return (value - config.start) / (config.end - config.start);
      },
      setNormalisedValue: (normalised: number) => {
        const scaled = config.start + normalised * (config.end - config.start);
        this.setParameter(id, scaled);
      },
      getScaledValue: () => this.parameterValues[id] ?? 0,
      setScaledValue: (value: number) => this.setParameter(id, value),
      properties: config,
      onValueChanged: (callback: (value: number) => void) => {
        if (!this.parameterCallbacks[id]) {
          this.parameterCallbacks[id] = new Set();
        }
        this.parameterCallbacks[id].add(callback);
        return () => {
          this.parameterCallbacks[id]?.delete(callback);
        };
      },
    };
  }

  setParameter(id: string, value: number): void {
    this.parameterValues[id] = value;
    this.workletNode?.port.postMessage({ type: 'param', name: id, value });
    
    const config = this.parameterConfigs[id];
    if (config) {
      const normalised = (value - config.start) / (config.end - config.start);
      this.parameterCallbacks[id]?.forEach(cb => cb(normalised));
    }
  }

  destroy(): void {
    this.workletNode?.disconnect();
    this.audioContext?.close();
  }
}

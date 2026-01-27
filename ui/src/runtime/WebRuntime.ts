import type { Runtime, AudioRuntime, ParameterState, ParameterProperties } from './types';

const PARAMETER_CONFIGS: Record<string, ParameterProperties> = {
  delayTime: { start: 0, end: 2000, name: 'delayTime', label: 'ms', interval: 1 },
  feedback: { start: 0, end: 100, name: 'feedback', label: '%', interval: 1 },
  mix: { start: 0, end: 100, name: 'mix', label: '%', interval: 1 },
}

export class WebRuntime implements Runtime, AudioRuntime {
  readonly type = 'web' as const
  private audioContext: AudioContext | null = null;
  private workletNode: AudioWorkletNode | null = null;
  private sourceNode: AudioBufferSourceNode | null = null;
  private audioBuffer: AudioBuffer | null = null;
  private isPlaying = false;
  private parameterValues: Record<string, number> = { delayTime: 0, feedback: 0, mix: 0 };
  private parameterCallbacks: Record<string, Set<(value: number) => void>> = {
    delayTime: new Set(),
    feedback: new Set(),
    mix: new Set(),
  };

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
    this.parameterValues.delayTime = ms;
    this.workletNode?.port.postMessage({ type: 'param', name: 'delayTime', value: ms });
    this.notifyCallbacks('delayTime', ms);
  }

  setFeedback(percent: number): void {
    this.parameterValues.feedback = percent;
    this.workletNode?.port.postMessage({ type: 'param', name: 'feedback', value: percent });
    this.notifyCallbacks('feedback', percent);
  }

  setMix(percent: number): void {
    this.parameterValues.mix = percent;
    this.workletNode?.port.postMessage({ type: 'param', name: 'mix', value: percent });
    this.notifyCallbacks('mix', percent);
  }

  private notifyCallbacks(id: string, value: number): void {
    const config = PARAMETER_CONFIGS[id];
    if (!config) return;
    const normalised = (value - config.start) / (config.end - config.start);
    this.parameterCallbacks[id]?.forEach(cb => cb(normalised));
  }

  getParameter(id: string): ParameterState | null {
    const config = PARAMETER_CONFIGS[id];
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
        this.parameterCallbacks[id]?.add(callback);
        return () => {
          this.parameterCallbacks[id]?.delete(callback);
        };
      },
    };
  }

  setParameter(id: string, value: number): void {
    switch (id) {
      case 'delayTime':
        this.setDelayTime(value);
        break;
      case 'feedback':
        this.setFeedback(value);
        break;
      case 'mix':
        this.setMix(value);
        break;
    }
  }

  destroy(): void {
    this.stop();
    this.workletNode?.disconnect();
    this.audioContext?.close();
  }
}

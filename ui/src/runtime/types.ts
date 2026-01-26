export interface Runtime {
  initialize(): Promise<void>;
  setDelayTime(ms: number): void;
  setFeedback(percent: number): void;
  setMix(percent: number): void;
  destroy(): void;
}

export interface RuntimeParams {
  delayTime: number;
  feedback: number;
  mix: number;
}

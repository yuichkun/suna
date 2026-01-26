export interface Runtime {
  initialize(): Promise<void>;
  setDelayTime(ms: number): void;
  setFeedback(percent: number): void;
  setMix(percent: number): void;
  destroy(): void;

  // Optional methods for web mode file playback
  loadAudioFile?(file: File): Promise<void>;
  play?(): void;
  stop?(): void;
  getIsPlaying?(): boolean;
  hasAudioLoaded?(): boolean;
}

export interface RuntimeParams {
  delayTime: number;
  feedback: number;
  mix: number;
}

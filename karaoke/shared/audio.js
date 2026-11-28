// A synthetic track, ported from BeatsWall/Audio/SimulatedAudioSource.swift.
// YouTube audio can't be analyzed from a web page, so wallpapers run on this beat.
import { clamp } from './kit.js';

export const BINS = 32;
const BEAT_DECAY = 4.5;

/** Audio features at `time` (seconds) for a steady tempo. Same fields the Swift wallpapers read. */
export function readAudio(time, bpm = 120) {
  const beatLength = 60 / bpm;
  const beats = time / beatLength;
  const since = (beats - Math.floor(beats)) * beatLength;
  const swell = 0.5 + 0.5 * Math.sin(time * 0.21);
  const pulse = Math.exp(-since * BEAT_DECAY);
  const bass = clamp(0.25 + 0.65 * pulse * (0.6 + 0.4 * swell));
  const mid = clamp((0.45 + 0.2 * Math.sin(time * 1.7) + 0.15 * Math.sin(time * 0.53)) * (0.7 + 0.3 * swell));
  const treble = clamp(0.35 + 0.15 * Math.sin(time * 4.3 + 1) + 0.1 * Math.sin(time * 9.1));
  const spectrum = new Array(BINS);
  for (let bin = 0; bin < BINS; bin++) {
    const x = bin / (BINS - 1);
    const low = bass * Math.exp(-x * 6);
    const middle = mid * Math.exp(-Math.pow((x - 0.45) * 4, 2)) * 0.8;
    const high = treble * Math.exp(-Math.pow((x - 0.8) * 5, 2)) * 0.7;
    const wobble = 0.12 * Math.sin(time * (2 + bin * 0.37) + bin) * (0.5 + 0.5 * swell);
    spectrum[bin] = clamp(low + middle + high + wobble);
  }
  return {
    level: (bass + mid + treble) / 3, bass, mid, treble, spectrum,
    beatPulse: pulse, beatCount: Math.floor(beats), secondsSinceBeat: since, bpm,
  };
}

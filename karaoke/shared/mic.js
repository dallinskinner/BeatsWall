// Listens to the room through the microphone so wallpapers can follow the real song, and measures applause.
// Audio is analysed in this page only. Nothing is recorded or sent anywhere.
import { clamp } from './kit.js';
import { BINS, readAudio } from './audio.js';

const BEAT_DECAY = 4.5, MIN_BEAT_GAP = 0.25, QUIET_AFTER = 3;
// Loudness range of the applause meter, in decibels below full scale.
const QUIET_DB = -50, LOUD_DB = -10;

/** Asks for the microphone. Returns { read(time), loudness(), stop() }; throws if it isn't allowed. */
export async function startMic() {
  const stream = await navigator.mediaDevices.getUserMedia({
    // The browser's clean-up would remove the music and flatten the cheering, so it's all off.
    audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false },
  });
  const ac = new AudioContext();
  await ac.resume();
  const analyser = ac.createAnalyser();
  analyser.fftSize = 2048; analyser.smoothingTimeConstant = 0.5;
  ac.createMediaStreamSource(stream).connect(analyser);
  const freq = new Float32Array(analyser.frequencyBinCount), wave = new Float32Array(analyser.fftSize);
  const hzPerBin = ac.sampleRate / analyser.fftSize;

  /** Average power between two frequencies, as an amplitude. */
  const band = (lo, hi) => {
    const from = Math.max(1, Math.floor(lo / hzPerBin)), to = Math.min(freq.length - 1, Math.max(from, Math.ceil(hi / hzPerBin)));
    let sum = 0;
    for (let i = from; i <= to; i++) sum += Math.pow(10, Math.max(freq[i], -100) / 10);
    return Math.sqrt(sum / (to - from + 1));
  };
  // Each band is scaled against its own recent peak, so quiet and loud rooms both look lively.
  const peaks = {};
  const scaled = (key, value, dt) => {
    peaks[key] = Math.max(value, (peaks[key] || 0) * Math.exp(-dt * 0.15), 0.001);
    return clamp(value / peaks[key]);
  };
  const rmsDb = () => {
    analyser.getFloatTimeDomainData(wave);
    let sum = 0;
    for (const v of wave) sum += v * v;
    return 10 * Math.log10(sum / wave.length + 1e-12);
  };

  let beatCount = 0, lastBeat = null, bassAverage = 0, lastTime = null, lastSound = null, cache = null;

  return {
    /** Same fields as readAudio(). Falls back to the made-up beat while the room is silent. */
    read(time) {
      if (cache && cache.time === time) return cache.value;
      const dt = lastTime === null ? 0.016 : Math.min(0.1, Math.max(0, time - lastTime));
      lastTime = time;
      lastBeat ??= time - 1; // wallpapers expect a finite time since the last beat
      if (lastSound === null || rmsDb() > QUIET_DB) lastSound = time;
      if (time - lastSound > QUIET_AFTER) return readAudio(time);

      analyser.getFloatFrequencyData(freq);
      const rawBass = band(20, 150);
      const bass = scaled('bass', rawBass, dt), mid = scaled('mid', band(150, 2000), dt), treble = scaled('treble', band(2000, 12000), dt);
      // A beat is a sudden jump in the low end.
      if (rawBass > bassAverage * 1.35 && bass > 0.45 && time - lastBeat > MIN_BEAT_GAP) { beatCount++; lastBeat = time; }
      bassAverage += (rawBass - bassAverage) * Math.min(1, dt * 4);
      const since = time - lastBeat;

      const spectrum = new Array(BINS);
      const edge = i => 40 * Math.pow(400, i / BINS); // log-spaced, 40 Hz to 16 kHz
      for (let i = 0; i < BINS; i++) spectrum[i] = scaled('s' + i, band(edge(i), edge(i + 1)), dt);
      const value = {
        level: (bass + mid + treble) / 3, bass, mid, treble, spectrum,
        beatPulse: Math.exp(-since * BEAT_DECAY), beatCount, secondsSinceBeat: since, bpm: 120,
      };
      cache = { time, value };
      return value;
    },
    /** How loud the room is right now, 0 to 100. */
    loudness() { return Math.round(100 * clamp((rmsDb() - QUIET_DB) / (LOUD_DB - QUIET_DB))); },
    stop() { stream.getTracks().forEach(t => t.stop()); ac.close(); },
  };
}

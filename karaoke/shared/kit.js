// Helpers ported from BeatsWall/Wallpapers/WallpaperKit.swift and BrandTheme.swift.

export const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
export const lerp = (a, b, t) => a + (b - a) * t;

export function smoothstep(e0, e1, x) {
  const t = clamp((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

/** Deterministic pseudo-random value in 0..<1 for a pair of integers. */
export function hash01(a, b = 0) {
  let x = (Math.imul(a | 0, 73856093) ^ Math.imul(b | 0, 19349663)) >>> 0;
  x ^= x >>> 13;
  x = Math.imul(x, 0x5bd1e995) >>> 0;
  x = (x ^ (x >>> 15)) >>> 0; // stay unsigned, or the result can be negative
  return (x % 10000) / 10000;
}

/** Integrates a phase at a variable speed so changing speed never makes motion jump. */
export class PhaseClock {
  constructor() { this.phase = 0; this.deltaTime = 0; this.last = null; }
  advance(time, speed = 1) {
    this.deltaTime = this.last === null ? 0 : clamp(time - this.last, 0, 0.1);
    this.last = time;
    this.phase += this.deltaTime * speed;
    return this.phase;
  }
}

/** Reports true exactly once for each new beat. */
export class BeatEdge {
  constructor() { this.last = null; }
  isNewBeat(audio) {
    const n = audio.beatCount;
    if (this.last === null) { this.last = n; return false; }
    const isNew = n !== this.last;
    this.last = n;
    return isNew;
  }
}

// Brand colors as [r, g, b].
export const C = {
  magenta: [255, 46, 151], orange: [255, 140, 66], yellow: [255, 210, 63], violet: [123, 47, 247],
  glow: [255, 240, 247], plum: [42, 10, 74], navy: [14, 18, 48], ink: [7, 8, 22],
};
export const rgba = (c, a = 1) => `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${a})`;
export const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];

/** The icon's gradient at t (0 magenta, 0.5 orange, 1 yellow). */
export function brandGradient(t) {
  t = clamp(t);
  return t < 0.5 ? mix(C.magenta, C.orange, t * 2) : mix(C.orange, C.yellow, (t - 0.5) * 2);
}

/** Draws a pixel-art sprite given as rows of strings ('#' = filled). */
export function pixelSprite(ctx, rows, x, y, px) {
  for (let r = 0; r < rows.length; r++) {
    for (let c = 0; c < rows[r].length; c++) {
      if (rows[r][c] === '#') ctx.fillRect(x + c * px, y + r * px, px + 0.5, px + 0.5);
    }
  }
}

// ---- extras used by the ported collections ----
export const hex = n => [(n >> 16) & 255, (n >> 8) & 255, n & 255];
export const beatLength = a => (a.bpm > 40 ? 60 / a.bpm : 0.5);

/** A continuously increasing beat clock: whole numbers land on beats (AudioFeatures.beatProgress). */
export function beatProgress(a, time) {
  const bl = beatLength(a);
  if (!isFinite(a.secondsSinceBeat)) return time / bl;
  const f = a.secondsSinceBeat / bl, hold = 0.5;
  if (f <= 1) return a.beatCount + f;
  if (f <= 1 + hold) return a.beatCount + 1;
  return a.beatCount + f - hold;
}

/** Two-bone IK: where a knee or elbow sits so both segments reach from start toward end. */
export function twoBoneJoint(sx, sy, ex, ey, upper, lower, bend) {
  const dx = ex - sx, dy = ey - sy, full = Math.max(Math.hypot(dx, dy), 0.001);
  const dist = Math.min(full, upper + lower - 0.001), ux = dx / full, uy = dy / full;
  const along = (upper * upper - lower * lower + dist * dist) / (2 * dist);
  const height = Math.sqrt(Math.max(upper * upper - along * along, 0));
  return [sx + ux * along + -uy * height * bend, sy + uy * along + ux * height * bend];
}

// Value noise and fbm, ported from SharedShaders.metal.
const fract = x => x - Math.floor(x);
function hash21(px, py) {
  px = fract(px * 123.34); py = fract(py * 456.21);
  const d = px * (px + 45.32) + py * (py + 45.32);
  px += d; py += d;
  return fract(px * py);
}
function valueNoise(px, py) {
  const ix = Math.floor(px), iy = Math.floor(py), fx = px - ix, fy = py - iy;
  const ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy);
  const a = hash21(ix, iy), b = hash21(ix + 1, iy), c = hash21(ix, iy + 1), d = hash21(ix + 1, iy + 1);
  return lerp(lerp(a, b, ux), lerp(c, d, ux), uy);
}
export function fbm(px, py) {
  let v = 0, amp = 0.5;
  for (let o = 0; o < 5; o++) { v += amp * valueNoise(px, py); px = px * 2.03 + 17.1; py = py * 2.03 + 17.1; amp *= 0.5; }
  return v;
}

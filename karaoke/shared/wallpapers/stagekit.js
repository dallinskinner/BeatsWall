// Shared stage lighting for Concert and Light Show, ported from ConcertTheme.swift and HypeMeter.
// The Mac app's lighting desk, album-art colors and stage images are not on the web: the rig is the default one.
import { hex, rgba, mix, clamp, lerp, smoothstep, hash01, BeatEdge, beatLength } from '../kit.js';
import { lin, rad, dot, circle } from './draw.js';

export const T = {
  magenta: hex(0xFF2E88), violet: hex(0x8A4BFF), ice: hex(0x6FD3FF), laserGreen: hex(0x39FF6A), amber: hex(0xFFB23F), pyro: hex(0xFF6A1F),
  night: hex(0x07050D), stage: hex(0x0D0A14), crowd: hex(0x030206), white: [255, 255, 255],
};
export const RIG = [T.magenta, T.ice, T.violet, T.amber, T.laserGreen];
export const CONFETTI = [T.magenta, T.ice, T.amber, T.white, T.violet];
const calm = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
export const LIGHT = { strobe: calm ? 0.35 : 1, intensity: 1, fog: 0.5, speed: 1 };

export const rigColor = (bar, offset = 0, palette = RIG) => palette[(((bar + offset) % palette.length) + palette.length) % palette.length];

/** How far fixture `index` of `count` is turned right now (the default "sweep" movement). */
export const motion = (index, count, beat) => Math.sin(beat * LIGHT.speed * Math.PI / 2 + (index % 2 === 0 ? 0 : Math.PI)) * 0.45;

export function glow(ctx, x, y, radius, color, opacity) {
  if (!(opacity > 0.005 && radius > 0)) return;
  dot(ctx, x, y, radius, rad(ctx, x, y, 0, radius, [rgba(color, opacity), rgba(color, opacity * 0.35), rgba(color, 0)]));
}

export function haze(ctx, x, y, w, h, color, opacity) {
  const o = opacity * LIGHT.fog * 2;
  if (o <= 0.002) return;
  ctx.fillStyle = lin(ctx, 0, y, 0, y + h, [rgba(color, 0), rgba(color, o), rgba(color, o * 0.6), rgba(color, 0)]);
  ctx.fillRect(x, y, w, h);
}

/** A spotlight cone. angle 0 points down, positive swings right, PI points up. Draw with 'lighter'. */
export function beam(ctx, ox, oy, angle, length, spread, color, intensity) {
  const i = Math.min(intensity * LIGHT.intensity, 1.6);
  if (i <= 0.01) return;
  const edge = (o, s) => [ox + Math.sin(angle + o) * length * s, oy + Math.cos(angle + o) * length * s];
  const end = edge(0, 1);
  const tri = (o, s, colors) => {
    ctx.fillStyle = lin(ctx, ox, oy, end[0], end[1], colors);
    ctx.beginPath(); ctx.moveTo(ox, oy); ctx.lineTo(...edge(-o, s)); ctx.lineTo(...edge(o, s)); ctx.closePath(); ctx.fill();
  };
  tri(spread, 1, [rgba(color, 0.5 * i), rgba(color, 0.12 * i), rgba(color, 0)]);
  tri(spread * 0.3, 0.9, [rgba(mix(color, T.white, 0.5), 0.5 * i), rgba(color, 0)]);
  glow(ctx, ox, oy, length * 0.05, mix(color, T.white, 0.6), i);
}

export function laser(ctx, ox, oy, angle, length, color, intensity, width) {
  const i = Math.min(intensity * LIGHT.intensity, 1.6);
  if (i <= 0.01) return;
  ctx.beginPath(); ctx.moveTo(ox, oy); ctx.lineTo(ox + Math.sin(angle) * length, oy + Math.cos(angle) * length);
  ctx.lineCap = 'round';
  [[7, 0.12, color], [2.5, 0.4, color], [1, 1, mix(color, T.white, 0.45)]].forEach(([k, a, c]) => { ctx.strokeStyle = rgba(c, a * i); ctx.lineWidth = width * k; ctx.stroke(); });
}

export function strobe(ctx, w, h, amount) {
  const a = amount * LIGHT.strobe;
  if (a <= 0.01) return;
  ctx.save(); ctx.globalCompositeOperation = 'source-over';
  ctx.fillStyle = `rgba(255,255,255,${Math.min(a, 1) * 0.4})`; ctx.fillRect(0, 0, w, h); ctx.restore();
}

/** The automatic laser show: a new look every bar and a spinning tunnel after drops. */
export function laserShow(ctx, w, h, ox, oy, beat, rotation, bl, hype, pulse, primary, secondary, reduced) {
  const unit = Math.min(w, h), length = Math.hypot(w, h), width = Math.max(1, unit * 0.0022), energy = hype.energy;
  const intensity = 0.35 + 0.5 * energy + 0.3 * pulse, bar = Math.floor(beat / 4), beams = 9 + Math.floor(8 * energy);
  const pattern = hype.secondsSinceDrop < bl * 16 ? 'tunnel' : ['fan', 'crossfire', 'sheet'][((bar % 3) + 3) % 3];
  if (pattern === 'tunnel') {
    const n = reduced ? 24 : 48;
    for (let i = 0; i < n; i++) laser(ctx, ox, oy, i / n * Math.PI * 2 + rotation, length, i % 2 === 0 ? primary : secondary, intensity, width);
    ctx.save(); ctx.globalAlpha *= 0.5; ctx.lineWidth = width * 2;
    for (let r = 0; r < 4; r++) { const p = (r + (beat % 1)) / 4; ctx.strokeStyle = rgba(secondary, 1 - p); circle(ctx, ox, oy, length * 0.5 * p * p); ctx.stroke(); }
    ctx.restore();
  } else if (pattern === 'fan') {
    const center = Math.PI + motion(0, 1, beat) * 1.3, spread = 1.4 * (1 - 0.6 * hype.build);
    for (let i = 0; i < beams; i++) laser(ctx, ox, oy, center + (i / (beams - 1) - 0.5) * spread, length, primary, intensity, width);
  } else if (pattern === 'crossfire') {
    [-1, 1].forEach((side, i) => {
      const center = -side * (0.7 + 0.8 * motion(i, 2, beat)), half = Math.floor(beams / 2);
      for (let b = 0; b <= half; b++) laser(ctx, w / 2 + side * w * 0.45, h * 0.08, center + (b / half - 0.5) * 0.6, length, side > 0 ? primary : secondary, intensity, width);
    });
  } else {
    const tilt = Math.PI * 0.5 + 0.22 + motion(0, 1, beat) * 0.45;
    for (let i = 0; i < beams; i++) {
      const t = i / (beams - 1) - 0.5;
      laser(ctx, ox, oy, tilt + t * 0.05, length, primary, intensity * 0.7, width);
      laser(ctx, ox, oy, -tilt - t * 0.05, length, secondary, intensity * 0.7, width);
    }
  }
}

/** One row of the crowd in silhouette. Returns where the raised hands are, as [x, y]. */
export function crowd(ctx, w, unit, baseline, scale, count, seed, color, audio, beat, handsUp, jump) {
  const hands = [], arms = [], spacing = (w + unit * 0.2) / count, pulse = audio.beatPulse;
  const body = new Path2D();
  const disc = (x, y, r) => { body.moveTo(x + r, y); body.arc(x, y, r, 0, Math.PI * 2); };
  for (let i = 0; i < count; i++) {
    const s = unit * scale * (0.85 + 0.3 * hash01(i, seed)), x = -unit * 0.1 + spacing * (i + 0.5 + (hash01(i, seed + 1) - 0.5) * 0.7);
    const bob = -s * 0.09 * pulse * (hash01(i, audio.beatCount + seed) < jump ? 1 : 0.25), headY = baseline - s * 0.62 + bob;
    disc(x, headY, s * 0.11);
    const rx = x - s * 0.24, ry = baseline - s * 0.47 + bob, rw = s * 0.48, rh = s * 0.7, r = s * 0.16;
    body.moveTo(rx + r, ry); body.arcTo(rx + rw, ry, rx + rw, ry + rh, r); body.arcTo(rx + rw, ry + rh, rx, ry + rh, r); body.arcTo(rx, ry + rh, rx, ry, r); body.arcTo(rx, ry, rx + rw, ry, r); body.closePath();
    if (!(hash01(i, seed + 2) < handsUp)) continue;
    const sides = hash01(i, seed + 3) < 0.35 ? [-1, 1] : [hash01(i, seed + 4) < 0.5 ? -1 : 1], wave = Math.sin(beat * Math.PI + i * 0.9);
    for (const side of sides) {
      const sx = x + s * 0.17 * side, sy = baseline - s * 0.4 + bob, hx = sx + s * (0.1 * side + 0.07 * wave), hy = sy - s * (0.5 + 0.06 * pulse);
      arms.push([sx, sy, sx + s * 0.1 * side, sy - s * 0.25, hx, hy]);
      disc(hx, hy, s * 0.05); hands.push([hx, hy]);
    }
  }
  ctx.strokeStyle = color; ctx.lineWidth = unit * scale * 0.08; ctx.lineCap = 'round'; ctx.beginPath();
  for (const [a, b, c, d, e, f] of arms) { ctx.moveTo(a, b); ctx.quadraticCurveTo(c, d, e, f); }
  ctx.stroke(); ctx.fillStyle = color; ctx.fill(body);
  return hands;
}

export function confetti(ctx, ox, oy, angle, age, unit, count, seed) {
  if (!(age >= 0 && age < 7)) return;
  const fade = 1 - smoothstep(5, 7, age), reach = (1 - Math.exp(-3 * age)) / 3;
  for (let i = 0; i < count; i++) {
    const dir = angle + (hash01(i, seed) - 0.5) * 0.9, speed = unit * (1.6 + 1.4 * hash01(i, seed + 1)), flutter = Math.sin(age * (3 + 2 * hash01(i, seed + 2)) + i);
    const x = ox + Math.sin(dir) * speed * reach + unit * 0.03 * flutter * Math.min(age, 1), y = oy - Math.cos(dir) * speed * reach + unit * (0.07 + 0.04 * hash01(i, seed + 3)) * age;
    const side = unit * 0.009, flip = Math.abs(Math.cos(age * 7 + i));
    ctx.save(); ctx.translate(x, y); ctx.rotate(age * 4 + i); ctx.fillStyle = rgba(CONFETTI[i % CONFETTI.length], 0.95 * fade);
    ctx.fillRect(-side / 2, -side * 0.3, side, side * 0.6 * Math.max(flip, 0.15)); ctx.restore();
  }
}

export function sparkRain(ctx, x0, x1, top, floor, age, unit, count, intensity) {
  if (intensity <= 0.01) return;
  ctx.beginPath();
  for (let i = 0; i < count; i++) {
    const cycle = age * (0.9 + 0.6 * hash01(i, 31)) + hash01(i, 32), p = cycle - Math.floor(cycle);
    const x = x0 + (x1 - x0) * hash01(i, 33), y = top + (floor - top) * p * p, drift = unit * 0.02 * p * (hash01(i, 34) - 0.5);
    ctx.moveTo(x + drift, y); ctx.lineTo(x + drift * 0.8, y - unit * (0.015 + 0.04 * p));
  }
  ctx.strokeStyle = rgba(mix(T.amber, T.white, 0.4), 0.9 * intensity); ctx.lineWidth = Math.max(1, unit * 0.0025); ctx.lineCap = 'round'; ctx.stroke();
}

export function firework(ctx, cx, cy, age, radius, color, seed, count) {
  if (!(age >= 0 && age < 2.2)) return;
  const fade = 1 - smoothstep(0.6, 2.2, age), spread = radius * (1 - Math.exp(-4 * age)), droop = radius * 0.25 * age * age, tips = [];
  ctx.beginPath();
  for (let i = 0; i < count; i++) {
    const a = i / count * Math.PI * 2 + hash01(seed, i) * 0.2, r = spread * (0.8 + 0.2 * hash01(i, seed));
    const tx = cx + Math.cos(a) * r, ty = cy + Math.sin(a) * r + droop;
    ctx.moveTo(cx + Math.cos(a) * r * 0.7, cy + Math.sin(a) * r * 0.7 + droop * 0.6); ctx.lineTo(tx, ty); tips.push([tx, ty]);
  }
  ctx.strokeStyle = rgba(color, 0.55 * fade); ctx.lineWidth = radius * 0.012; ctx.lineCap = 'round'; ctx.stroke();
  for (const [x, y] of tips) dot(ctx, x, y, radius * 0.018, rgba(mix(color, T.white, 0.5), fade));
  glow(ctx, cx, cy, radius * 1.2, color, 0.35 * fade * (1 - smoothstep(0, 0.8, age)));
}

/** Follows the shape of the song: loudness, build-ups and drops. */
export class HypeMeter {
  constructor() { Object.assign(this, { energy: 0, build: 0, dropPulse: 0, secondsSinceDrop: Infinity, dropCount: 0, fast: 0, slow: 0, valley: 0, last: null, loud: 0, beats: new BeatEdge() }); }
  update(time, audio) {
    const d = this.last === null ? 0 : clamp(time - this.last, 0, 0.1); this.last = time;
    const level = 0.5 * audio.level + 0.5 * audio.bass;
    this.fast += (level - this.fast) * (1 - Math.exp(-d * 5));
    this.slow += (level - this.slow) * (1 - Math.exp(-d * 0.35));
    this.valley = Math.min(this.fast, this.valley + d * 0.04);
    this.energy = smoothstep(0.08, 0.75, this.fast);
    this.secondsSinceDrop += d;
    this.dropPulse = isFinite(this.secondsSinceDrop) ? Math.exp(-this.secondsSinceDrop * 1.2) : 0;
    const climbing = smoothstep(0.03, 0.25, this.fast - this.valley);
    this.build += ((this.secondsSinceDrop < 6 ? 0 : climbing) - this.build) * (1 - Math.exp(-d * 0.8));
    if (!this.beats.isNewBeat(audio)) return;
    this.loud = this.energy > 0.55 ? this.loud + 1 : 0;
    const bar = beatLength(audio) * 4;
    const isDrop = this.fast > this.slow + 0.12 && this.fast - this.valley > 0.22 && audio.bass > 0.5;
    const isMoment = this.loud >= 16 && this.secondsSinceDrop > bar * 8;
    if (!(this.secondsSinceDrop < bar * 4) && (isDrop || isMoment)) {
      Object.assign(this, { secondsSinceDrop: 0, dropPulse: 1, build: 0, loud: 0, valley: this.fast }); this.dropCount++;
    }
  }
}

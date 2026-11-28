// Halloween collection, ported from BeatsWall/Collections/Halloween/*.swift. Film grain is omitted.
import { hex, rgba, mix, hash01, PhaseClock, BeatEdge, beatProgress, twoBoneJoint } from '../kit.js';
import { lin, rad, rrect, circle, lines, dot, glow, scratch, withBlur } from './draw.js';

const T = { midnight: hex(0x0A0B14), sil: hex(0x07080D), purple: hex(0x2A1F3D), haze: hex(0x3B3552), fog: hex(0x8A90A6), moon: hex(0xE8E4D0), pumpkin: hex(0xFF7518), candle: hex(0xFFB347), green: hex(0x7CFF6B), bone: hex(0xE6E1D3), white: [255, 255, 255], black: [0, 0, 0] };
const SIL = rgba(T.sil);
const box = (ctx, color, x, y, w, h) => { ctx.fillStyle = color; ctx.fillRect(x, y, w, h); };
const addPoly = (ctx, pts, close = true) => { ctx.moveTo(...pts[0]); for (let i = 1; i < pts.length; i++) ctx.lineTo(...pts[i]); if (close) ctx.closePath(); };
const addOval = (ctx, x, y, rx, ry) => { ctx.moveTo(x + rx, y); ctx.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2); };
const oval = (ctx, x, y, rx, ry, color) => { ctx.beginPath(); addOval(ctx, x, y, rx, ry); ctx.fillStyle = color; ctx.fill(); };
const stroke = (ctx, color, width) => { ctx.strokeStyle = color; ctx.lineWidth = width; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke(); };
const lit = (ctx, fn) => { ctx.save(); ctx.globalCompositeOperation = 'lighter'; fn(); ctx.restore(); };
const wrapX = (raw, span) => raw - Math.floor(raw / span) * span;

const sky = (ctx, w, h, horizon, low = T.haze) => box(ctx, lin(ctx, 0, 0, 0, horizon, [rgba(T.midnight), rgba(T.purple), rgba(low)]), 0, 0, w, h);
function moon(ctx, x, y, r, brightness) {
  glow(ctx, x, y, r * 3.2, T.moon, 0.18 + 0.12 * brightness);
  dot(ctx, x, y, r, rad(ctx, x - r * 0.3, y - r * 0.3, 0, r * 1.4, [rgba(T.moon), rgba(mix(T.moon, hex(0xBDB6A0), 0.6))]));
  for (const [dx, dy, k] of [[-0.35, -0.15, 0.2], [0.25, 0.3, 0.14], [0.3, -0.35, 0.1], [-0.1, 0.45, 0.08]]) dot(ctx, x + dx * r, y + dy * r, r * k, 'rgba(169,162,140,0.45)');
}
/** Drifting fog banks, painted small and blurred for speed. */
function fog(ctx, w, h, top, drift, density, tint = T.fog, banks = 14) {
  const unit = Math.min(w, h), k = 0.3, buf = scratch('halloween.fog', Math.ceil(w * k), Math.ceil(h * k)), g = buf ? buf.ctx : ctx;
  g.save(); if (buf) g.scale(k, k);
  withBlur(g, unit * 0.035 * k, () => {
    for (let i = 0; i < banks; i++) {
      const span = w + unit * 1.2, x = wrapX(hash01(i, 302) * span + drift * (0.5 + hash01(i, 301)) * unit, span) - unit * 0.6;
      const y = top + (h - top) * hash01(i, 303), rx = unit * (0.25 + 0.3 * hash01(i, 304));
      oval(g, x, y, rx, rx * 0.16, rgba(tint, 0.035 + 0.075 * density));
    }
  });
  g.restore(); if (buf) ctx.drawImage(buf.canvas, 0, 0, w, h);
}
function bat(ctx, x, y, s, flap) {
  const tip = -flap * s * 0.45;
  ctx.beginPath();
  for (const k of [-1, 1]) {
    ctx.moveTo(x, y);
    ctx.quadraticCurveTo(x + k * s * 0.5, y + tip - s * 0.25, x + k * s, y + tip);
    ctx.quadraticCurveTo(x + k * s * 0.86, y + tip * 0.5 + s * 0.02, x + k * s * 0.66, y + tip * 0.5 + s * 0.12);
    ctx.quadraticCurveTo(x + k * s * 0.5, y + tip * 0.3 + s * 0.02, x + k * s * 0.33, y + tip * 0.25 + s * 0.12);
    ctx.quadraticCurveTo(x + k * s * 0.15, y + s * 0.05, x, y);
  }
  ctx.fillStyle = SIL; ctx.fill();
  ctx.beginPath(); addOval(ctx, x, y + s * 0.05, s * 0.12, s * 0.18);
  for (const k of [-1, 1]) addPoly(ctx, [[x + k * s * 0.1, y - s * 0.08], [x + k * s * 0.07, y - s * 0.24], [x + k * s * 0.02, y - s * 0.1]]);
  ctx.fill();
}
function barrenTree(ctx, bx, by, height, seed, depth = 5) {
  const branch = (x, y, angle, len, width, level, id) => {
    const bend = (hash01(seed, id * 3 + 1) - 0.5) * 0.5, ex = x + Math.cos(angle) * len, ey = y + Math.sin(angle) * len;
    ctx.beginPath(); ctx.moveTo(x, y); ctx.quadraticCurveTo(x + Math.cos(angle + bend) * len * 0.55, y + Math.sin(angle + bend) * len * 0.55, ex, ey); stroke(ctx, SIL, width);
    if (level <= 0) return;
    for (let c = 0; c < (hash01(seed, id * 7 + 2) > 0.8 ? 3 : 2); c++) {
      const side = c === 0 ? -1 : c === 1 ? 1 : 0.15;
      branch(ex, ey, angle + side * (0.35 + 0.35 * hash01(seed, id * 11 + c)), len * (0.62 + 0.18 * hash01(seed, id * 13 + c)), width * 0.62, level - 1, id * 4 + c + 1);
    }
  };
  branch(bx, by, -Math.PI / 2 + (hash01(seed, 0) - 0.5) * 0.2, height * 0.38, height * 0.05, depth, 1);
}

// ---------------------------------------------------------------- Haunted House
const WINDOWS = [[0.2, 0.55, 0.09, 0.12], [0.42, 0.55, 0.09, 0.12], [0.2, 0.78, 0.09, 0.12], [0.53, 0.78, 0.09, 0.12], [0.73, 0.34, 0.07, 0.1], [0.73, 0.58, 0.07, 0.1], [0.04, 0.75, 0.06, 0.09]];
function house(ctx, x, y, s, unit, time, audio) {
  const P = (px, py) => [x + px * s, y + py * s];
  ctx.save(); ctx.translate(x + s / 2, y + s); ctx.rotate(-0.025); ctx.translate(-(x + s / 2), -(y + s));
  // Each part is filled on its own so overlapping outlines never cancel out.
  const part = pts => { ctx.beginPath(); addPoly(ctx, pts.map(p => P(...p))); ctx.fillStyle = SIL; ctx.fill(); };
  const rect = (px, py, pw, ph) => part([[px, py], [px + pw, py], [px + pw, py + ph], [px, py + ph]]);
  rect(0.1, 0.45, 0.62, 0.56); part([[0.04, 0.47], [0.4, 0.2], [0.76, 0.47]]);
  rect(0.66, 0.24, 0.2, 0.77); part([[0.63, 0.26], [0.77, -0.06], [0.89, 0.26]]);
  rect(-0.02, 0.68, 0.14, 0.33); part([[-0.05, 0.7], [0.06, 0.58], [0.14, 0.7]]);
  part([[0.18, 0.34], [0.2, 0.14], [0.27, 0.15], [0.26, 0.3]]);
  part([[0.3, 0.74], [0.66, 0.74], [0.7, 0.8], [0.26, 0.8]]);
  ctx.beginPath(); addPoly(ctx, [P(0.77, -0.06), P(0.77, -0.13)], false); stroke(ctx, SIL, unit * 0.004);
  WINDOWS.forEach(([wx, wy, ww, wh], i) => {
    const flicker = 0.85 + 0.15 * Math.sin(time * (11 + i) + i * 3), l = Math.min(1, (0.15 + 0.85 * audio.spectrum[(i * 4 + 3) % 32]) * flicker), color = i === 4 ? T.green : T.candle;
    const [fx, fy] = P(wx, wy), fw = ww * s, fh = wh * s;
    box(ctx, rgba(mix(color, T.black, 0.85 - 0.75 * l)), fx, fy, fw, fh);
    lit(ctx, () => glow(ctx, fx + fw / 2, fy + fh / 2, fw * 1.8, color, 0.35 * l));
    ctx.beginPath(); addPoly(ctx, [[fx + fw / 2, fy], [fx + fw / 2, fy + fh]], false); addPoly(ctx, [[fx, fy + fh / 2], [fx + fw, fy + fh / 2]], false); stroke(ctx, SIL, Math.max(1, unit * 0.003));
  });
  const [ax, ay] = P(0.39, 0.37), al = 0.2 + 0.8 * audio.beatPulse * audio.bass;
  dot(ctx, ax, ay, s * 0.035, rgba(mix(T.candle, T.black, 0.85 - 0.7 * al)));
  lit(ctx, () => glow(ctx, ax, ay, s * 0.1, T.candle, 0.3 * al));
  ctx.restore();
}
function makeHaunted() {
  const clock = new PhaseClock(), edge = new BeatEdge();
  let bats = [], bolt = null, lastIdle = 0;
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), s = unit * 0.42, hx = w * 0.36 - s / 2, hy = h * 0.62 - s, ax = hx + 0.39 * s, ay = hy + 0.37 * s, horizon = h * 0.7;
      clock.advance(time);
      const dt = clock.deltaTime;
      const spawn = n => { for (let i = 0; i < n; i++) { const a = -Math.PI * (0.05 + 0.9 * Math.random()), v = unit * (0.12 + 0.18 * Math.random()); bats.push({ x: ax, y: ay, vx: Math.cos(a) * v, vy: Math.sin(a) * v * 0.6, born: time, size: 0.7 + 0.6 * Math.random(), seed: Math.random() }); } };
      if (edge.isNewBeat(audio)) {
        if (audio.bass > 0.55) spawn(3 + Math.floor(4 * audio.level));
        if (audio.bass > 0.8 && hash01(audio.beatCount, 13) > 0.7) bolt = { t: time, x: 0.15 + 0.7 * hash01(audio.beatCount, 14), seed: audio.beatCount };
      }
      if (time - lastIdle > 4) { lastIdle = time; spawn(1); }
      for (const b of bats) { b.x += b.vx * dt; b.y += (b.vy + Math.sin(time * 3 + b.seed * 10) * unit * 0.06) * dt; b.vy -= unit * 0.01 * dt; }
      bats = bats.filter(b => time - b.born <= 8 && b.x > -unit * 0.1 && b.x < w + unit * 0.1 && b.y > -unit * 0.1);

      sky(ctx, w, h, horizon);
      const flash = bolt && time >= bolt.t ? Math.exp(-(time - bolt.t) * 12) : 0;
      if (flash > 0) box(ctx, rgba(hex(0xC9C6E8), 0.45 * flash), 0, 0, w, h);
      ctx.beginPath(); for (let i = 0; i < 50; i++) { const r = unit * 0.0014 * (0.6 + hash01(i, 2)); addOval(ctx, hash01(i, 0) * w, hash01(i, 1) * horizon * 0.6, r, r); } ctx.fillStyle = 'rgba(255,255,255,0.45)'; ctx.fill();
      const mx = w * 0.62, my = h * 0.3;
      moon(ctx, mx, my, unit * 0.15, audio.level);
      for (let i = 0; i < 3; i++) { const span = w + unit; oval(ctx, wrapX(hash01(i, 9) * span + time * unit * 0.012 * (1 + i), span) - unit * 0.5, my + unit * (-0.1 + 0.1 * i), unit * 0.22, unit * 0.025, rgba(T.purple, 0.75)); }
      if (bolt && time - bolt.t >= 0 && time - bolt.t < 0.18) {
        const x0 = w * bolt.x, x1 = x0 + unit * 0.08, y1 = horizon * 0.85, dx = x1 - x0, len = Math.hypot(dx, y1), pts = [];
        for (let i = 0; i <= 12; i++) { const t = i / 12, j = i === 0 || i === 12 ? 0 : (hash01(bolt.seed, i) - 0.5) * len * 0.12; pts.push([x0 + dx * t - y1 / len * j, y1 * t + dx / len * j]); }
        ctx.beginPath(); addPoly(ctx, pts, false); const [fx, fy] = pts[6]; addPoly(ctx, [[fx, fy], [fx + len * 0.12, fy + len * 0.1], [fx + len * 0.18, fy + len * 0.25]], false);
        stroke(ctx, rgba(hex(0xC9C6E8), 0.5), unit * 0.012); stroke(ctx, '#fff', unit * 0.003);
      }
      ctx.beginPath(); ctx.moveTo(0, h); for (let x = 0; x <= w + 6; x += 6) { const t = x / w; ctx.lineTo(x, horizon - unit * 0.09 * Math.exp(-(((t - 0.36) / 0.28) ** 2)) + unit * 0.01 * Math.sin(t * 20)); } ctx.lineTo(w + 6, h); ctx.closePath(); ctx.fillStyle = SIL; ctx.fill();
      barrenTree(ctx, w * 0.1, horizon + unit * 0.02, unit * 0.55, 3);
      barrenTree(ctx, w * 0.86, horizon + unit * 0.03, unit * 0.45, 8);
      barrenTree(ctx, w * 0.6, horizon + unit * 0.01, unit * 0.22, 11, 4);
      house(ctx, hx, hy, s, unit, time, audio);
      for (const b of bats) bat(ctx, b.x, b.y, unit * 0.022 * b.size, Math.sin(beatProgress(audio, time) * 4 * Math.PI + b.seed * 6));
      fog(ctx, w, h, horizon - unit * 0.06, time * 0.02, 0.5 + 0.5 * audio.mid);
    },
  };
}

// ---------------------------------------------------------------- Pumpkin Patch
const PUMPKINS = [[0.52, 0.7, 0.07, 2], [0.2, 0.77, 0.12, 0], [0.66, 0.8, 0.11, 3], [0.4, 0.87, 0.16, 1], [0.84, 0.89, 0.15, 4]];
function pumpkin(ctx, x, y, r, band, seed, time, audio) {
  const l = Math.min(1, (0.8 + 0.2 * Math.sin(time * 13 + seed * 2) * Math.sin(time * 7.3 + seed)) * (0.5 + 0.5 * audio.bass));
  let voice = 0; for (let i = band * 6; i < (band + 1) * 6; i++) voice += audio.spectrum[i] / 6;
  const open = 0.25 + 0.75 * voice;
  lit(ctx, () => { ctx.translate(x, y + r * 0.8); ctx.scale(1, 0.28); glow(ctx, 0, 0, r * 2.4, T.pumpkin, 0.3 * l); });
  const body = () => { ctx.beginPath(); for (const [dx, rx] of [[-0.55, 0.55], [0.55, 0.55], [-0.25, 0.6], [0.25, 0.6], [0, 0.55]]) addOval(ctx, x + dx * r, y, rx * r, r * 0.82); };
  body(); ctx.fillStyle = '#2A1408'; ctx.fill();
  ctx.save(); body(); ctx.clip();
  body(); ctx.fillStyle = rad(ctx, x, y + r * 0.1, 0, r * 1.3, [rgba(T.pumpkin, 0.45 * l), rgba(hex(0x2A1408), 0)]); ctx.fill();
  ctx.beginPath(); for (const dx of [-0.42, 0, 0.42]) addOval(ctx, x + dx * r, y, r * 0.3, r * 0.8); stroke(ctx, 'rgba(0,0,0,0.35)', r * 0.03);
  ctx.restore();
  ctx.beginPath(); ctx.moveTo(x - r * 0.06, y - r * 0.75); ctx.quadraticCurveTo(x - r * 0.05, y - r * 0.95, x + r * 0.12, y - r * 1.05); stroke(ctx, '#14100A', r * 0.12);
  const face = () => {
    ctx.beginPath();
    for (const s of [-1, 1]) addPoly(ctx, [[x + s * r * 0.5, y - r * 0.08], [x + s * r * 0.3, y - r * 0.42], [x + s * r * 0.12, y - r * 0.08]]);
    addPoly(ctx, [[x - r * 0.07, y + r * 0.08], [x, y - r * 0.04], [x + r * 0.07, y + r * 0.08]]);
    const top = y + r * 0.2, depth = r * (0.12 + 0.32 * open), mouth = [];
    const at = i => { const t = i / 6, c = 1 - (2 * t - 1) ** 2; return [x + r * (-0.6 + 1.2 * t), top - r * 0.12 * c, c]; };
    for (let i = 0; i <= 6; i++) { const [px, py] = at(i); mouth.push([px, py + (i % 2 === 1 ? r * 0.08 : 0)]); }
    for (let i = 6; i >= 0; i--) { const [px, py, c] = at(i); mouth.push([px, py + depth * c + r * 0.04]); }
    addPoly(ctx, mouth);
  };
  face(); ctx.fillStyle = rad(ctx, x, y, 0, r * 0.8, [rgba(mix(T.candle, T.white, 0.3 * l)), rgba(T.pumpkin)]); ctx.fill();
  ctx.fillStyle = `rgba(0,0,0,${0.75 * (1 - l)})`; ctx.fill();
  lit(ctx, () => glow(ctx, x, y, r * 1.6, T.pumpkin, 0.25 * l));
}
function makePatch() {
  const clock = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.6, drift = clock.advance(time, 0.02 + 0.03 * audio.mid);
      sky(ctx, w, h, horizon, hex(0x4A3048));
      moon(ctx, w * 0.8, h * 0.2, unit * 0.07, 0.4);
      for (let i = 0; i < 4; i++) { const span = w + unit; oval(ctx, wrapX(hash01(i, 5) * span + drift * unit * 0.6, span) - unit * 0.5, h * (0.14 + 0.08 * i), unit * 0.25, unit * 0.022, rgba(T.purple, 0.7)); }
      ctx.beginPath(); ctx.moveTo(0, h); for (let x = 0; x <= w + 5; x += 5) { const s = x / unit; ctx.lineTo(x, horizon - unit * (0.04 + Math.abs(Math.sin(s * 9)) * 0.03 + Math.abs(Math.sin(s * 23 + 1)) * 0.015)); } ctx.lineTo(w + 5, h); ctx.closePath(); ctx.fillStyle = '#15121F'; ctx.fill();
      ctx.beginPath();
      for (let p = unit * 0.02; p < w; p += unit * 0.07) addPoly(ctx, [[p, horizon + unit * 0.02], [p + (hash01(Math.floor(p), 7) - 0.5) * unit * 0.012, horizon - unit * 0.035]], false);
      addPoly(ctx, [[0, horizon - unit * 0.015], [w, horizon - unit * 0.012]], false); stroke(ctx, SIL, unit * 0.005);
      box(ctx, lin(ctx, 0, horizon, 0, h, ['#120F18', SIL]), 0, horizon + unit * 0.01, w, h);
      ctx.beginPath();
      for (let i = 0; i < PUMPKINS.length - 1; i++) {
        const [ax, ay] = PUMPKINS[i], [bx, by] = PUMPKINS[i + 1]; ctx.moveTo(w * ax, h * ay);
        for (let s = 1; s <= 24; s++) { const t = s / 24; ctx.lineTo(w * (ax + (bx - ax) * t), h * (ay + (by - ay) * t) + unit * 0.02 * Math.sin(t * 14 + i)); }
      }
      stroke(ctx, '#0E1610', unit * 0.004);
      PUMPKINS.forEach(([px, py, size, band], i) => pumpkin(ctx, w * px, h * py, unit * size, band, i, time, audio));
      fog(ctx, w, h, horizon, drift, 0.6, hex(0x9A8FA8), 12);
    },
  };
}

// ---------------------------------------------------------------- Graveyard Rave
function tombstone(ctx, x, y, s, kind, tilt, color) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(tilt); ctx.scale(s, s); ctx.fillStyle = color; ctx.beginPath();
  if (kind === 0) { ctx.moveTo(-0.6, 0); ctx.lineTo(-0.6, -1.2); ctx.quadraticCurveTo(0, -2, 0.6, -1.2); ctx.lineTo(0.6, 0); ctx.closePath(); ctx.fill(); }
  else if (kind === 1) { ctx.fillRect(-0.15, -2, 0.3, 2); ctx.fillRect(-0.6, -1.55, 1.2, 0.28); }
  else { addPoly(ctx, [[-0.35, 0], [-0.25, -2.1], [0, -2.45], [0.25, -2.1], [0.35, 0]]); ctx.fill(); }
  ctx.restore();
}
function skeleton(ctx, fx, fy, u, beat, index, audio) {
  ctx.save(); ctx.translate(fx, fy); ctx.scale(u, u);
  const bone = rgba(T.bone), swing = Math.sin(Math.PI * beat), drop = 0.9 * (1 - Math.abs(swing)) * (0.5 + audio.bass), sway = swing * 0.7;
  const kick = Math.max(0, swing) * (Math.floor(beat) % 2 === 0 ? 1 : -1), px = sway, py = -5 + drop, sx = px + sway * 0.25, sy = py - 3.2, kx = sx + sway * 0.15, ky = sy - 1.35;
  const bones = [], joints = [];
  for (const [hx, foot, bend] of [[px - 0.55, [-1.1, kick > 0 ? -0.9 * kick : 0], 1], [px + 0.55, [1.1, kick < 0 ? 0.9 * kick : 0], -1]]) {
    const knee = twoBoneJoint(hx, py, foot[0], foot[1], 2.6, 2.6, bend); bones.push([[hx, py], knee, foot]); joints.push(knee, foot);
  }
  const loud = audio.level > 0.55, arm = Math.cos(Math.PI * (beat + index * 0.5));
  for (const side of [-1, 1]) {
    const a = loud ? 2.6 + 0.3 * Math.sin(2 * Math.PI * beat + index + (side > 0 ? 1 : 0)) : 1.45 - side * 0.95 * arm;
    const ax = sx + side, ay = sy + 0.25, hx = ax + side * Math.sin(a) * 3, hy = ay + Math.cos(a) * 3, elbow = twoBoneJoint(ax, ay, hx, hy, 1.7, 1.6, -side);
    bones.push([[ax, ay], elbow, [hx, hy]], [[sx, sy], [ax, ay]]); joints.push(elbow, [hx, hy]);
  }
  bones.push([[px, py], [sx, sy]]);
  ctx.save(); ctx.shadowColor = rgba(T.green, 0.25 + 0.35 * audio.beatPulse); ctx.shadowBlur = 0.8 * u;
  ctx.beginPath(); for (const b of bones) addPoly(ctx, b, false);
  for (let r = 0; r < 3; r++) { const y = sy + 0.55 + r * 0.6, x = px + (sx - px) * (1 - (y - sy) / (py - sy)), wd = 0.95 - r * 0.12; ctx.moveTo(x - wd, y + 0.15); ctx.quadraticCurveTo(x, y - 0.35, x + wd, y + 0.15); }
  stroke(ctx, bone, 0.32);
  ctx.beginPath(); for (const [x, y] of joints) addOval(ctx, x, y, 0.22, 0.22); addOval(ctx, px, py + 0.1, 0.85, 0.42); ctx.fillStyle = bone; ctx.fill();
  ctx.restore();
  ctx.translate(kx, ky); ctx.rotate(sway * 0.2);
  oval(ctx, 0, 0, 0.95, 1, bone); rrect(ctx, -0.55, 0.55, 1.1, 0.55, 0.15); ctx.fillStyle = bone; ctx.fill();
  ctx.beginPath(); addOval(ctx, -0.35, -0.05, 0.24, 0.28); addOval(ctx, 0.35, -0.05, 0.24, 0.28); addPoly(ctx, [[-0.08, 0.4], [0, 0.25], [0.08, 0.4]]); ctx.fillStyle = SIL; ctx.fill();
  ctx.beginPath(); for (let t = -2; t <= 2; t++) addPoly(ctx, [[t * 0.2, 0.65], [t * 0.2, 1]], false); stroke(ctx, SIL, 0.06);
  ctx.restore();
}
function makeGraveyard() {
  const clock = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.68, beat = beatProgress(audio, time), pulse = audio.beatPulse, drift = clock.advance(time, 0.03 + 0.04 * audio.level);
      sky(ctx, w, h, horizon, hex(0x1E2E2A));
      moon(ctx, w * 0.16, h * 0.17, unit * 0.05, 0.3);
      lit(ctx, () => {
        for (let i = 0; i < 4; i++) {
          const ox = w * (0.12 + 0.25 * i), oy = horizon + unit * 0.02, a = -Math.PI / 2 + Math.sin(beat * Math.PI / 4 + i * 1.3) * 0.55, len = h * 1.3, dx = Math.cos(a), dy = Math.sin(a), n = unit * 0.11;
          const color = i % 2 === 0 ? T.green : hex(0x9B6BFF);
          ctx.beginPath(); addPoly(ctx, [[ox, oy], [ox + dx * len - dy * n, oy + dy * len + dx * n], [ox + dx * len + dy * n, oy + dy * len - dx * n]]);
          ctx.fillStyle = lin(ctx, ox, oy, ox + dx * len, oy + dy * len, [rgba(color, 0.16 + 0.3 * pulse), rgba(color, 0)]); ctx.fill();
        }
      });
      const far = '#0E0F18';
      ctx.beginPath(); ctx.moveTo(0, h); for (let x = 0; x <= w + 6; x += 6) ctx.lineTo(x, horizon - unit * 0.05 * Math.exp(-((x / w - 0.74) ** 2) / 0.03)); ctx.lineTo(w + 6, h); ctx.closePath(); ctx.fillStyle = far; ctx.fill();
      const cx = w * 0.74, cy = horizon - unit * 0.045;
      box(ctx, far, cx - unit * 0.06, cy - unit * 0.07, unit * 0.12, unit * 0.07); box(ctx, far, cx + unit * 0.035, cy - unit * 0.17, unit * 0.03, unit * 0.12);
      for (const tri of [[[-0.07, -0.07], [0, -0.12], [0.07, -0.07]], [[0.03, -0.17], [0.05, -0.23], [0.07, -0.17]]]) { ctx.beginPath(); addPoly(ctx, tri.map(([x, y]) => [cx + unit * x, cy + unit * y])); ctx.fillStyle = far; ctx.fill(); }
      rrect(ctx, cx - unit * 0.012, cy - unit * 0.06, unit * 0.024, unit * 0.03, unit * 0.012); ctx.fillStyle = rgba(hex(0x9B6BFF), 0.3 + 0.5 * pulse); ctx.fill();
      box(ctx, SIL, 0, horizon, w, h);
      const fy = horizon + unit * 0.01;
      ctx.beginPath();
      for (let x = unit * 0.01; x < w; x += unit * 0.025) { addPoly(ctx, [[x, fy], [x, fy - unit * 0.07]], false); addPoly(ctx, [[x - unit * 0.006, fy - unit * 0.066], [x, fy - unit * 0.08], [x + unit * 0.006, fy - unit * 0.066]], false); }
      for (const k of [0.055, 0.015]) addPoly(ctx, [[0, fy - unit * k], [w, fy - unit * k]], false);
      stroke(ctx, '#111019', Math.max(1, unit * 0.003));
      for (let i = 0; i < 9; i++) tombstone(ctx, w * (0.05 + 0.11 * i), horizon + unit * 0.06, unit * 0.045, i % 3, (hash01(i, 3) - 0.5) * 0.2, '#16151F');
      [0.2, 0.41, 0.6, 0.8].forEach((x, i) => skeleton(ctx, w * x, h * 0.86, unit * 0.017, beat, i, audio));
      for (let i = 0; i < 5; i++) tombstone(ctx, w * (0.1 + 0.22 * i + 0.04 * hash01(i, 8)), h * 0.98, unit * 0.07, (i + 1) % 3, (hash01(i, 9) - 0.5) * 0.25, SIL);
      fog(ctx, w, h, horizon, drift, 0.35 + 0.4 * pulse, mix(T.fog, T.green, 0.1 + 0.3 * pulse));
    },
  };
}

// ---------------------------------------------------------------- Ghost Choir
function forest(ctx, w, unit, ground, layer) {
  const d = layer / 3, color = rgba(mix(hex(0x4A5468), T.sil, 0.35 + 0.65 * d)), count = 16 - layer * 3, branches = new Path2D();
  ctx.beginPath();
  for (let i = 0; i < count; i++) {
    const seed = layer * 100 + i, x = w * ((i + hash01(seed, 1)) / count), tw = unit * (0.006 + 0.012 * d) * (0.7 + 0.6 * hash01(seed, 2)), base = ground - unit * 0.06 * (1 - d), lean = (hash01(seed, 3) - 0.5) * unit * 0.04;
    addPoly(ctx, [[x - tw, base], [x - tw * 0.4 + lean, -unit * 0.05], [x + tw * 0.4 + lean, -unit * 0.05], [x + tw, base]]);
    for (let b = 0; b < 3; b++) {
      const y = base - (base + unit * 0.05) * (0.35 + 0.2 * b + 0.1 * hash01(seed, 10 + b)), side = (b + i) % 2 === 0 ? -1 : 1, sx = x + lean * (base - y) / (base + unit * 0.05), reach = unit * (0.04 + 0.04 * hash01(seed, 20 + b));
      const tx = sx + side * reach, ty = y - reach * 0.9;
      branches.moveTo(sx, y); branches.lineTo(tx, ty); branches.moveTo(sx + (tx - sx) * 0.6, y + (ty - y) * 0.6); branches.lineTo(tx + side * reach * 0.1, ty - reach * 0.55);
    }
  }
  ctx.fillStyle = color; ctx.fill(); ctx.strokeStyle = color; ctx.lineWidth = Math.max(1, unit * (0.002 + 0.003 * d)); ctx.lineCap = 'round'; ctx.stroke(branches);
}
function ghosts(ctx, w, h, unit, audio, phase) {
  const wail = audio.bass > 0.6 ? audio.beatPulse : 0;
  const list = Array.from({ length: 5 }, (_, i) => {
    const gw = unit * (0.1 + 0.02 * hash01(i, 1)), gh = gw * 1.45;
    return { i, gw, gh, x: w * (0.18 + 0.16 * i) + unit * 0.012 * Math.sin(phase * 0.7 + i), y: h * (0.52 + 0.05 * hash01(i, 2)) + unit * 0.025 * Math.sin(phase * 1.1 + i * 1.3) };
  });
  const body = ({ i, gw, gh, x, y }) => {
    const top = y - gh / 2, dy = top + gw / 2, hem = y + gh / 2;
    ctx.beginPath(); ctx.moveTo(x - gw * 0.56, hem); ctx.lineTo(x - gw / 2, dy); ctx.arc(x, dy, gw / 2, Math.PI, Math.PI * 2); ctx.lineTo(x + gw * 0.56, hem);
    for (let s = 24; s >= 0; s--) { const t = s / 24; ctx.lineTo(x - gw * 0.56 + gw * 1.12 * t, hem + gw * 0.08 * Math.sin(t * 8 * Math.PI + phase * 2 + i)); }
    ctx.closePath();
    return [top, hem, dy];
  };
  for (const g of list) { lit(ctx, () => glow(ctx, g.x, g.y, g.gh * 0.75, T.white, 0.14)); }
  for (const g of list) {
    const [top, hem, dy] = body(g);
    ctx.fillStyle = lin(ctx, g.x, top, g.x, hem, ['rgba(255,255,255,0.8)', 'rgba(200,214,232,0.12)']); ctx.fill();
    let voice = 0; for (let k = g.i * 6; k < (g.i + 1) * 6; k++) voice += audio.spectrum[k] / 6;
    const sing = Math.max(0.15 + 0.85 * voice, wail), gw = g.gw;
    ctx.beginPath(); for (const s of [-1, 1]) addOval(ctx, g.x + s * gw * 0.17, dy + gw * 0.02, gw * 0.07, gw * (0.1 - 0.03 * sing));
    addOval(ctx, g.x, dy + gw * 0.33, gw * (0.06 + 0.05 * sing), gw * (0.04 + 0.2 * sing)); ctx.fillStyle = 'rgba(16,19,28,0.85)'; ctx.fill();
  }
}
function makeChoir() {
  const clock = new PhaseClock(), WISP = hex(0x8CFFE0);
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), ground = h * 0.82, phase = clock.advance(time, 0.8 + 1.5 * audio.mid);
      box(ctx, lin(ctx, 0, 0, 0, ground, [rgba(T.midnight), '#1A2333', '#3A4658']), 0, 0, w, h);
      moon(ctx, w * 0.5, h * 0.16, unit * 0.055, 0.2);
      for (let layer = 0; layer < 4; layer++) {
        forest(ctx, w, unit, ground, layer);
        if (layer === 2) ghosts(ctx, w, h, unit, audio, phase);
        if (layer < 3) box(ctx, lin(ctx, 0, h * 0.35, 0, ground, ['rgba(90,100,120,0)', 'rgba(90,100,120,0.22)']), 0, h * 0.35, w, h * 0.65);
      }
      box(ctx, SIL, 0, ground, w, h);
      lit(ctx, () => {
        for (let i = 0; i < 14; i++) {
          const t = time * (0.05 + 0.05 * hash01(i, 41)), x = w * hash01(i, 42) + unit * 0.1 * Math.sin(t * 3 + i), y = h * (0.45 + 0.4 * hash01(i, 43)) + unit * 0.04 * Math.sin(t * 5 + i * 2);
          const b = 0.2 + 0.6 * (0.5 + 0.5 * Math.sin(time * (2 + 3 * hash01(i, 44)) + i)) * (0.5 + audio.treble);
          glow(ctx, x, y, unit * 0.025, WISP, 0.45 * b); dot(ctx, x, y, unit * 0.003, rgba(WISP, b));
        }
      });
      fog(ctx, w, h, ground - unit * 0.1, phase * 0.03, 0.7, hex(0x9AA6B8));
    },
  };
}

export const halloween = {
  id: 'halloween', name: 'Halloween', accent: T.pumpkin,
  wallpapers: [
    { id: 'halloween.haunted-house', name: 'Haunted House', summary: 'Flickering windows, bats on the beat and lightning on the big hits.', make: makeHaunted },
    { id: 'halloween.pumpkin-patch', name: 'Pumpkin Patch', summary: "Jack-o'-lanterns glow with the bass and sing along.", make: makePatch },
    { id: 'halloween.graveyard-rave', name: 'Graveyard Rave', summary: 'Skeletons dance among the tombstones under sweeping ghost lights.', make: makeGraveyard },
    { id: 'halloween.ghost-choir', name: 'Ghost Choir', summary: 'Ghosts in a misty forest that wail together on the beat.', make: makeChoir },
  ],
};

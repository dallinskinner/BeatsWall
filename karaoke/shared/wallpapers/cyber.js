// Cyberpunk collection, ported from BeatsWall/Collections/Cyberpunk/*.swift.
// Metal shaders are approximated: scanlines as stripes, VHS glitch as shifted slices, grain omitted.
import { hex, rgba, mix, hash01, PhaseClock } from '../kit.js';
import { lin, rad, lines, dot, ell, neon, scratch } from './draw.js';
import { drawRain } from './tokyo.js';

const T = { black: hex(0x05050A), magenta: hex(0xFF2BD6), cyan: hex(0x00F0FF), acid: hex(0xF5FF3B), toxic: hex(0x39FF88), red: hex(0xFF3355), white: [255, 255, 255] };
const NEONS = [T.magenta, T.cyan, T.acid, T.toxic, T.red];
const GLYPHS = Array.from({ length: 24 }, (_, seed) => Array.from({ length: 7 }, (_, row) => Array.from({ length: 5 }, (_, col) =>
  (col === 1 + seed % 3 && row > 0 && row < 6) || hash01(seed * 37 + row, col) < 0.38)));

function scanlines(ctx, w, h, time, strength, period) {
  ctx.fillStyle = `rgba(0,0,0,${strength})`;
  for (let y = (time * 12) % (period * 2); y < h; y += period * 2) ctx.fillRect(0, y, w, period);
}

// ---------------------------------------------------------------- Code Rain
function makeCodeRain() {
  const fall = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), phase = fall.advance(time, 0.6 + 1.6 * audio.level);
      ctx.fillStyle = rgba(T.black); ctx.fillRect(0, 0, w, h);
      const px = Math.max(1, Math.floor(unit / (w < 600 ? 260 : 300))), cw = px * 7, ch = px * 9;
      const cols = Math.floor(w / cw) + 1, rows = Math.floor(h / ch) + 1, TRAIL = 16;
      const buckets = Array.from({ length: 5 }, () => []), heads = [], flares = [];
      for (let c = 0; c < cols; c++) {
        const speed = 6 + 10 * hash01(c, 1), len = rows + TRAIL + Math.floor(hash01(c, 2) * rows), head = Math.floor(hash01(c, 3) * len + phase * speed) % len;
        const flaring = hash01(c, audio.beatCount) > 0.82 && audio.beatPulse > 0.2;
        for (let back = 0; back < TRAIL; back++) {
          const r = head - back;
          if (r < 0 || r >= rows) continue;
          const item = [Math.floor(hash01(c * 131 + r, Math.floor(time * 3) + c) * GLYPHS.length), c * cw, r * ch];
          (back === 0 ? heads : flaring && back < 6 ? flares : buckets[Math.min(Math.floor(back * 5 / TRAIL), 4)]).push(item);
        }
      }
      const paint = (list, color) => {
        ctx.fillStyle = color; ctx.beginPath();
        for (const [g, x, y] of list) GLYPHS[g].forEach((row, ry) => {
          for (let i = 0; i < 5; i++) if (row[i]) { let j = i; while (j + 1 < 5 && row[j + 1]) j++; ctx.rect(x + i * px, y + ry * px, (j - i + 1.1) * px, 1.1 * px); i = j; }
        });
        ctx.fill();
      };
      buckets.forEach((b, i) => paint(b, rgba(T.toxic, 0.9 - 0.18 * i)));
      paint(flares, rgba(mix(T.toxic, T.white, 0.6)));
      ctx.save(); ctx.shadowColor = rgba(T.toxic); ctx.shadowBlur = px * 6; paint(heads, '#fff'); ctx.restore();
      ctx.fillStyle = rad(ctx, w / 2, h / 2, unit * 0.3, Math.max(w, h) * 0.75, ['rgba(0,0,0,0)', 'rgba(0,0,0,0.6)']); ctx.fillRect(0, 0, w, h);
      scanlines(ctx, w, h, time, 0.12, 3);
    },
  };
}

// ---------------------------------------------------------------- Hologram
function makeHologram() {
  const spin = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), yaw = spin.advance(time, 0.25 + 0.9 * audio.level), cx = w / 2, cy = h * 0.44, radius = unit * 0.24 * (1 + 0.04 * audio.beatPulse);
      ctx.fillStyle = rad(ctx, cx, cy, 0, Math.max(w, h) * 0.6, ['#0A1424', rgba(T.black)]); ctx.fillRect(0, 0, w, h);
      const horizon = h * 0.72;
      ctx.save(); ctx.beginPath(); ctx.rect(0, horizon, w, h - horizon); ctx.clip(); ctx.beginPath();
      for (let i = 0; i < 14; i++) { const y = horizon + (h - horizon) / (i + 1 - (time * 0.5) % 1); ctx.moveTo(0, y); ctx.lineTo(w, y); }
      for (let c = -12; c <= 12; c++) { ctx.moveTo(w / 2, horizon); ctx.lineTo(w / 2 + c * unit * 0.25, h); }
      ctx.strokeStyle = rgba(T.magenta, 0.25); ctx.lineWidth = Math.max(1, unit * 0.0015); ctx.stroke(); ctx.restore();
      const ey = horizon + unit * 0.02;
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      lines(ctx, [[cx - unit * 0.03, ey], [cx + unit * 0.03, ey], [cx + radius * 1.1, cy + radius * 0.3], [cx - radius * 1.1, cy + radius * 0.3]], true);
      ctx.fillStyle = lin(ctx, cx, ey, cx, cy, [rgba(T.cyan, 0.3), rgba(T.cyan, 0)]); ctx.fill();
      ell(ctx, cx - unit * 0.08, ey - unit * 0.015, unit * 0.16, unit * 0.03); ctx.fillStyle = rgba(T.cyan, 0.6); ctx.fill(); ctx.restore();
      const project = ([px, py, pz], s) => {
        const x = px * Math.cos(yaw) + pz * Math.sin(yaw); let z = -px * Math.sin(yaw) + pz * Math.cos(yaw);
        const y = py * Math.cos(0.35) - z * Math.sin(0.35); z = py * Math.sin(0.35) + z * Math.cos(0.35);
        const p = 2.6 / (2.6 + z); return [cx + x * p * s, cy + y * p * s];
      };
      const poly = (pt, n) => { for (let i = 0; i <= n; i++) { const [x, y] = pt(i); i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y); } };
      neon(ctx, () => {
        ctx.beginPath();
        for (let d = -60; d <= 60; d += 30) { const lat = d * Math.PI / 180; poly(s => { const lon = s / 36 * Math.PI * 2; return project([Math.cos(lat) * Math.cos(lon), Math.sin(lat), Math.cos(lat) * Math.sin(lon)], radius); }, 36); }
        for (let l = 0; l < 12; l++) { const lon = l / 12 * Math.PI; poly(s => { const lat = s / 36 * Math.PI * 2; return project([Math.cos(lat) * Math.cos(lon), Math.sin(lat), Math.cos(lat) * Math.sin(lon)], radius); }, 36); }
      }, T.cyan, Math.max(1, unit * 0.0018), 0.55 + 0.35 * audio.mid);
      const core = radius * (0.35 + 0.2 * audio.bass), a2 = -yaw * 2;
      const v = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]].map(([x, y, z]) => [x * Math.cos(a2) - z * Math.sin(a2), y, x * Math.sin(a2) + z * Math.cos(a2)]);
      neon(ctx, () => { ctx.beginPath(); for (let a = 0; a < 6; a++) for (let b = a + 1; b < 6; b++) if ((a >> 1) !== (b >> 1)) { ctx.moveTo(...project(v[a], core)); ctx.lineTo(...project(v[b], core)); } }, T.magenta, Math.max(1, unit * 0.003));
      ctx.save(); ctx.beginPath(); poly(s => { const a = s / 60 * Math.PI * 2; return project([Math.cos(a) * 1.35, 0.05 * Math.sin(a * 6 + time * 3), Math.sin(a) * 1.35], radius); }, 60);
      ctx.setLineDash([unit * 0.01, unit * 0.006]); ctx.strokeStyle = rgba(T.acid, 0.7); ctx.lineWidth = Math.max(1, unit * 0.002); ctx.stroke(); ctx.restore();
      const bars = Math.round(audio.level * 10);
      ctx.save(); ctx.font = `500 ${unit * 0.022}px ui-monospace, Menlo, monospace`; ctx.textBaseline = 'top'; ctx.textAlign = 'left'; ctx.fillStyle = rgba(T.cyan, 0.85);
      ['SYS.LINK   ONLINE', `TEMPO      ${String(Math.round(audio.bpm)).padStart(3, '0')} BPM`, 'SIGNAL     ' + '█'.repeat(bars) + '░'.repeat(10 - bars), `BEAT       ${String(audio.beatCount % 100000).padStart(5, '0')}`]
        .forEach((s, i) => ctx.fillText(s, unit * 0.06, unit * 0.08 + i * unit * 0.035));
      ctx.restore();
      // VHS glitch: a few bands jump sideways on the big beats.
      const glitch = 0.08 + 0.9 * Math.pow(audio.beatPulse, 3) * audio.bass, cv = ctx.canvas;
      if (cv && cv.width && glitch > 0.15) {
        const ky = cv.height / h, kx = cv.width / w, frame = Math.floor(time * 14);
        for (let i = 0; i < 6; i++) {
          if (hash01(i, frame) > glitch) continue;
          const y = hash01(i + 20, frame) * h, bh = unit * (0.008 + 0.03 * hash01(i + 40, frame)), shift = (hash01(i + 60, frame) - 0.5) * 60 * glitch;
          ctx.drawImage(cv, 0, y * ky, cv.width, Math.max(1, bh * ky), shift, y, cv.width / kx, bh);
        }
      }
      scanlines(ctx, w, h, time, 0.18, 3);
    },
  };
}

// ---------------------------------------------------------------- Megacity
function towers(ctx, w, h, unit, layer, time, audio) {
  const depth = layer / 2, count = 10 - layer * 2, screens = [], windows = new Path2D(), bodies = new Path2D();
  for (let i = 0; i < count; i++) {
    const seed = layer * 50 + i, bw = w / count * (0.55 + 0.35 * hash01(seed, 1)), x = w * ((i + hash01(seed, 2) * 0.4) / count) - bw * 0.2;
    const top = h * (0.05 + 0.35 * hash01(seed, 3) * (1 - depth * 0.5)) + layer * unit * 0.08;
    bodies.rect(x, top, bw, h - top); bodies.rect(x + bw / 2 - unit * 0.002, top - unit * 0.05, unit * 0.004, unit * 0.05);
    let y = top + unit * 0.02, row = 0;
    while (y < h) { for (let c = 0; c < Math.floor(bw / (unit * 0.018)); c++) if (hash01(seed * 11 + c, row) > 0.62) windows.rect(x + unit * 0.006 + c * unit * 0.018, y, unit * 0.008, unit * 0.006); y += unit * 0.016; row++; }
    if (hash01(seed, 4) > 0.45) screens.push([x + bw * 0.12, top + (h - top) * (0.1 + 0.3 * hash01(seed, 5)), bw * 0.76, Math.min((h - top) * 0.25, unit * (0.12 + 0.1 * depth)), seed]);
  }
  ctx.fillStyle = rgba(mix(hex(0x241A3E), T.black, depth)); ctx.fill(bodies);
  ctx.fillStyle = rgba(T.cyan, 0.18 + 0.2 * depth); ctx.fill(windows);
  const n = audio.spectrum.length;
  for (const [x, y, sw, sh, seed] of screens) {
    const color = NEONS[seed % 5], accent = NEONS[(seed + 2) % 5], bin = (seed * 5) % n, e = audio.spectrum[bin];
    ctx.fillStyle = lin(ctx, x, y, x + sw, y + sh, [rgba(color, 0.35 + 0.5 * e), rgba(accent, 0.25 + 0.4 * e)]); ctx.fillRect(x, y, sw, sh);
    ctx.fillStyle = 'rgba(255,255,255,0.7)'; ctx.beginPath();
    const ad = (Math.floor(audio.beatCount / 4) + seed) % 3;
    if (ad === 0) for (let b = 0; b < 8; b++) { const bh = sh * 0.8 * audio.spectrum[(bin + b * 3) % n]; ctx.rect(x + sw * (0.06 + 0.11 * b), y + sh * 0.9 - bh, sw * 0.07, bh); }
    else if (ad === 1) ctx.arc(x + sw / 2, y + sh / 2, sh * 0.3 * (1 + 0.3 * audio.beatPulse), 0, Math.PI * 2);
    else ctx.rect(x, y + sh * ((time * 0.6 + seed) % 1), sw, sh * 0.12);
    ctx.fill();
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = rgba(color, 0.06 + 0.12 * e); ctx.fillRect(x - unit * 0.02, y - unit * 0.02, sw + unit * 0.04, sh + unit * 0.04); ctx.restore();
  }
}
function traffic(ctx, w, h, unit, lane, time, audio) {
  const y = h * (0.3 + 0.18 * lane), s = unit * (0.012 + 0.012 * lane), speed = (0.08 + 0.08 * lane) * (0.7 + 0.8 * audio.level);
  for (let car = 0; car < 4 + lane * 2; car++) {
    const dir = (car + lane) % 2 === 0 ? 1 : -1, p = (hash01(car, lane + 70) + time * speed * (0.8 + 0.4 * hash01(car, lane + 71))) % 1;
    const travel = p * (w + unit * 0.4) - unit * 0.2, x = dir > 0 ? travel : w - travel, cy = y + (hash01(car, lane + 72) - 0.5) * unit * 0.06;
    ctx.fillStyle = '#1C1830'; ctx.beginPath(); ctx.ellipse(x, cy, s * 1.4, s * 0.35, 0, 0, Math.PI * 2); ctx.fill();
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    dot(ctx, x + dir * s * 1.4, cy, s * 0.15, '#fff');
    const bx = x - dir * s * 1.4;
    lines(ctx, [[bx, cy], [bx - dir * s * 6, cy]]); ctx.strokeStyle = lin(ctx, bx, cy, bx - dir * s * 6, cy, [rgba(T.red, 0.8), rgba(T.red, 0.05)]); ctx.lineWidth = Math.max(1, s * 0.2); ctx.lineCap = 'round'; ctx.stroke();
    ctx.restore();
  }
}
function makeMegacity() {
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h);
      ctx.fillStyle = lin(ctx, 0, 0, 0, h, ['#0B0716', '#2A0E3A', '#4A1240']); ctx.fillRect(0, 0, w, h);
      for (let layer = 0; layer < 3; layer++) { towers(ctx, w, h, unit, layer, time, audio); traffic(ctx, w, h, unit, layer, time, audio); }
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = lin(ctx, 0, h * 0.6, 0, h, [rgba(T.magenta, 0), rgba(T.magenta, 0.18 + 0.12 * audio.bass)]); ctx.fillRect(0, h * 0.6, w, h * 0.4); ctx.restore();
      drawRain(ctx, w, h, time, 0.5 + 0.5 * audio.level, 0.08);
    },
  };
}

export const cyber = {
  id: 'cyber', name: 'Cyberpunk', accent: T.magenta,
  wallpapers: [
    { id: 'cyber.hologram', name: 'Hologram', summary: 'A wireframe globe over a neon grid that glitches on the big beats.', make: makeHologram },
    { id: 'cyber.megacity', name: 'Megacity', summary: 'Towering neon city with flying cars and ad screens flashing with the spectrum.', make: makeMegacity },
    { id: 'cyber.code-rain', name: 'Code Rain', summary: 'Strange glyphs pour down faster as the music gets louder.', make: makeCodeRain },
  ],
};

// Synthwave collection, ported from BeatsWall/Collections/Synthwave/*.swift. Film grain is omitted.
import { PhaseClock, hash01, hex, rgba, mix, smoothstep } from '../kit.js';
import { lin, rad, rrect, circle, lines, neon, scratch } from './draw.js';

const T = {
  magenta: hex(0xFF2E97), purple: hex(0x7B2FF7), cyan: hex(0x00E5FF), yellow: hex(0xFFD23F), orange: hex(0xFF8C42),
  night: hex(0x12002B), deepNight: hex(0x0B0221), dusk: hex(0x2A0A4A),
};
const tempo = a => (a.bpm > 0 ? Math.min(Math.max((a.bpm - 70) / 90, 0), 1) : 0.5);
const c = rgba;

/** The classic striped sunset sun. Stripes scroll downward and thicken with the bass. */
function drawSun(ctx, cx, cy, radius, bass, scroll) {
  const glow = radius * 1.7;
  ctx.fillStyle = rad(ctx, cx, cy, radius * 0.8, glow, [c(T.magenta, 0.45), c(T.magenta, 0)]);
  circle(ctx, cx, cy, glow); ctx.fill();
  const size = Math.ceil(radius * 2) + 2;
  const layer = scratch('sun', size, size);
  const g = layer ? layer.ctx : ctx, ox = layer ? size / 2 : cx, oy = layer ? size / 2 : cy;
  g.fillStyle = lin(g, 0, oy - radius, 0, oy + radius, [c(T.yellow), c(T.orange), c(T.magenta)]);
  circle(g, ox, oy, radius); g.fill();
  if (layer) {
    g.globalCompositeOperation = 'destination-out'; g.fillStyle = '#000';
    const count = 7, offset = scroll - Math.floor(scroll);
    for (let i = -1; i < count; i++) {
      const t = (i + offset) / count;
      if (t < 0) continue;
      g.fillRect(ox - radius, oy - radius * 0.05 + radius * 1.05 * t, radius * 2, radius * (0.025 + 0.1 * t) * (0.75 + 0.8 * bass));
    }
    g.globalCompositeOperation = 'source-over';
    ctx.drawImage(layer.canvas, cx - size / 2, cy - size / 2);
  }
}

function drawStars(ctx, w, h, maxY, count, twinkle, time) {
  const unit = Math.min(w, h);
  ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.beginPath();
  for (let i = 0; i < count; i++) {
    const x = hash01(i, 101) * w, y = hash01(i, 102) * maxY;
    const shimmer = 0.5 + 0.5 * Math.sin(time * (1 + 3 * hash01(i, 103)) + i);
    const r = unit * 0.0022 * (0.5 + hash01(i, 104) + twinkle * shimmer);
    ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, Math.PI * 2);
  }
  ctx.fill();
}

function makeOutrunGrid() {
  const road = new PhaseClock(), sunScroll = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.58, center = w / 2, pulse = audio.beatPulse;
      const scroll = road.advance(time, 0.6 + 1.6 * tempo(audio) + 0.8 * audio.level);
      const sunPhase = sunScroll.advance(time, 0.15);

      ctx.fillStyle = lin(ctx, 0, 0, 0, horizon, [c(T.deepNight), c(T.dusk), c(T.purple), c(T.magenta)]);
      ctx.fillRect(0, 0, w, horizon);
      drawStars(ctx, w, h, horizon * 0.6, 90, audio.treble, time);
      drawSun(ctx, center, horizon - unit * 0.07, unit * 0.26, audio.bass, sunPhase);

      // Wireframe mountains: peaks rise with the spectrum, lowest bins on the outside.
      const points = 48, ridge = [];
      for (let i = 0; i <= points; i++) {
        const x = w * i / points, fromCenter = Math.abs(i / points - 0.5) * 2;
        const bin = Math.min(Math.floor((1 - fromCenter) * 26), audio.spectrum.length - 1);
        const jagged = i % 2 === 0 ? 1 : 0.45, gap = smoothstep(0.3, 0.55, fromCenter);
        ridge.push([x, horizon - unit * (0.03 + 0.1 * hash01(i, 7) + 0.14 * audio.spectrum[bin]) * jagged * gap]);
      }
      ctx.fillStyle = lin(ctx, 0, horizon - unit * 0.25, 0, horizon, [c(T.dusk), c(T.night)]);
      ctx.beginPath(); ctx.moveTo(0, horizon); ridge.forEach(p => ctx.lineTo(p[0], p[1])); ctx.lineTo(w, horizon); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = c(T.cyan, 0.25); ctx.lineWidth = Math.max(1, unit * 0.0015); ctx.beginPath();
      for (const p of ridge) if (p[1] < horizon - 1) { ctx.moveTo(p[0], p[1]); ctx.lineTo(p[0] + (center - p[0]) * 0.15, horizon); }
      ctx.stroke();
      neon(ctx, () => lines(ctx, ridge), T.cyan, Math.max(1, unit * 0.002));

      // Floor and grid.
      const depth = h - horizon;
      ctx.fillStyle = lin(ctx, 0, horizon, 0, h, [c(T.night), c(T.deepNight)]);
      ctx.fillRect(0, horizon, w, depth);
      ctx.save(); ctx.beginPath(); ctx.rect(0, horizon, w, depth); ctx.clip();
      const offset = scroll - Math.floor(scroll), spacing = unit * 0.16, columns = Math.floor(w / spacing) + 4;
      neon(ctx, () => {
        ctx.beginPath();
        for (let i = 0; i < 40; i++) { const y = horizon + depth / (i + 1 - offset); if (y <= h + 2) { ctx.moveTo(0, y); ctx.lineTo(w, y); } }
        for (let col = -columns; col <= columns; col++) { ctx.moveTo(center, horizon); ctx.lineTo(center + col * spacing * 1.6, h); }
      }, T.magenta, Math.max(1, unit * 0.0022), 0.6 + 0.4 * pulse);
      ctx.fillStyle = lin(ctx, 0, horizon, 0, horizon + depth * 0.35, [c(T.night), c(T.night, 0)]);
      ctx.fillRect(0, horizon, w, depth * 0.35);
      ctx.restore();
      neon(ctx, () => lines(ctx, [[0, horizon], [w, horizon]]), T.magenta, Math.max(1, unit * 0.003), 0.8 + 0.2 * pulse);
    },
  };
}

function makeNeonPalms() {
  const water = new PhaseClock(), sway = new PhaseClock();
  const PALMS = [[0.1, 0.78, 0.12, 1.0], [0.22, 0.6, 0.06, 0.75], [0.9, 0.82, -0.14, 1.05], [0.79, 0.55, -0.05, 0.7]];

  function drawPalm(ctx, bx, by, height, lean, scale, swayAmt) {
    const sil = c(T.night), tx = bx + lean, ty = by - height, cx = bx + lean * 0.1, cy = by - height * 0.6;
    const left = [], right = [];
    for (let s = 0; s <= 20; s++) {
      const t = s / 20, a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, d = t * t;
      const px = bx * a + cx * b + tx * d, py = by * a + cy * b + ty * d, wd = scale * (0.028 - 0.014 * t);
      left.push([px - wd, py]); right.push([px + wd, py]);
    }
    ctx.fillStyle = sil; lines(ctx, left.concat(right.reverse()), true); ctx.fill();
    const fronds = 8;
    for (let i = 0; i < fronds; i++) {
      const spread = i / (fronds - 1), angle = -Math.PI * (0.06 + 0.88 * spread) + swayAmt * (1 + spread);
      const length = scale * (0.2 + 0.06 * Math.sin(i * 2.1)), droop = scale * 0.09;
      const tipX = tx + Math.cos(angle) * length, tipY = ty + Math.sin(angle) * length * 0.55 + droop;
      const mx = tx + Math.cos(angle) * length * 0.55, my = ty + Math.sin(angle) * length * 0.55 - droop * 0.2;
      const nx = -Math.sin(angle) * scale * 0.035, ny = Math.cos(angle) * scale * 0.035;
      ctx.beginPath(); ctx.moveTo(tx, ty); ctx.quadraticCurveTo(mx + nx, my + ny, tipX, tipY); ctx.quadraticCurveTo(mx - nx, my - ny, tx, ty); ctx.closePath(); ctx.fill();
    }
    for (const off of [-0.012, 0.012]) { circle(ctx, tx + scale * off, ty + scale * 0.012 + scale * 0.016, scale * 0.016); ctx.fill(); }
  }

  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.64, center = w / 2;
      const ripple = water.advance(time, 0.8 + 2.5 * audio.mid), breeze = sway.advance(time, 0.6 + 0.8 * audio.mid);

      ctx.fillStyle = lin(ctx, 0, 0, 0, horizon, [c(hex(0x1B0638)), c(hex(0x5B1A6E)), c(T.magenta), c(T.orange), c(T.yellow)]);
      ctx.fillRect(0, 0, w, horizon);
      drawStars(ctx, w, h, horizon * 0.35, 50, audio.treble, time);
      const sunR = unit * 0.3;
      drawSun(ctx, center, horizon - sunR * 0.35, sunR, audio.bass, time * 0.12);

      // Water with a rippling sun reflection.
      ctx.fillStyle = lin(ctx, 0, horizon, 0, h, [c(hex(0x3A0E5A)), c(T.night)]);
      ctx.fillRect(0, horizon, w, h - horizon);
      const nLines = 22;
      for (let i = 0; i < nLines; i++) {
        const t = i / nLines, y = horizon + (h - horizon) * Math.pow(t, 1.35) + unit * 0.004;
        const wobble = 0.6 + 0.4 * Math.sin(ripple * 2 + i * 1.3);
        const half = sunR * (1 - t * 0.7) * wobble * (0.75 + 0.4 * audio.mid);
        const shift = Math.sin(ripple + i * 0.7) * unit * 0.01;
        ctx.fillStyle = c(mix(T.yellow, T.magenta, Math.min(1, t * 1.4)), 0.85 - 0.6 * t);
        rrect(ctx, center - half + shift, y, half * 2, unit * (0.004 + 0.006 * t), unit * 0.003); ctx.fill();
      }
      neon(ctx, () => lines(ctx, [[0, horizon], [w, horizon]]), T.magenta, Math.max(1, unit * 0.002));

      PALMS.forEach(([x, hh, lean, sc], i) => drawPalm(ctx, w * x, h + unit * 0.02, h * hh, unit * lean, unit * sc,
        Math.sin(breeze + i * 1.7) * (0.04 + 0.08 * audio.mid)));

      // The neon sign: steady, brightening on the beat; some beats make the tube sputter.
      let brightness = 0.7 + 0.3 * audio.beatPulse;
      if (hash01(audio.beatCount, 3) > 0.7 && audio.beatPulse > 0.45 && Math.sin(time * 90) > 0) brightness *= 0.25;
      const px = w / 2, py = h * 0.17;
      ctx.save();
      ctx.font = `italic 800 ${unit * 0.12}px ui-rounded, "SF Pro Rounded", system-ui, sans-serif`;
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.shadowColor = c(T.cyan, brightness); ctx.fillStyle = c(mix([255, 255, 255], T.cyan, 0.4), 0.35 + 0.65 * brightness);
      ctx.shadowBlur = unit * 0.06; ctx.fillText('Beats', px, py);
      ctx.shadowBlur = unit * 0.016; ctx.fillText('Beats', px, py);
      ctx.restore();
      neon(ctx, () => lines(ctx, [[px - unit * 0.17, py + unit * 0.08], [px + unit * 0.17, py + unit * 0.08]]), T.magenta, Math.max(1, unit * 0.004), brightness);
    },
  };
}

function makeMidnightDrive() {
  const road = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.52, center = w / 2, depth = h - horizon;
      const scroll = road.advance(time, 1.2 + 2.5 * tempo(audio) + audio.level);
      const offset = scroll - Math.floor(scroll);

      ctx.fillStyle = lin(ctx, 0, 0, 0, horizon, [c(T.deepNight), c(T.dusk), c(T.purple)]);
      ctx.fillRect(0, 0, w, horizon);
      drawStars(ctx, w, h, horizon * 0.7, 110, audio.treble, time);
      drawSun(ctx, center, horizon - unit * 0.05, unit * 0.2, audio.bass, time * 0.15);

      // Skyline equalizer on the horizon.
      const buildings = 36, slot = w / buildings;
      ctx.fillStyle = c(T.night); ctx.beginPath();
      const windows = [];
      for (let i = 0; i < buildings; i++) {
        const bin = Math.min(Math.floor(Math.abs(i / (buildings - 1) - 0.5) * 2 * 30), audio.spectrum.length - 1);
        const bh = unit * (0.03 + 0.05 * hash01(i, 5) + 0.12 * audio.spectrum[audio.spectrum.length - 1 - bin]);
        const rx = i * slot + slot * 0.08, ry = horizon - bh, rw = slot * 0.84;
        ctx.rect(rx, ry, rw, bh);
        for (let y = ry + unit * 0.012; y < horizon - unit * 0.01; y += unit * 0.016) {
          for (let col = 0; col < 2; col++) {
            if (hash01(i * 7 + col, Math.trunc(y)) > 0.55) windows.push([rx + rw * (0.22 + 0.4 * col), y, rw * 0.16, unit * 0.006]);
          }
        }
      }
      ctx.fill();
      ctx.fillStyle = c(T.cyan, 0.7); ctx.beginPath(); windows.forEach(r => ctx.rect(r[0], r[1], r[2], r[3])); ctx.fill();
      neon(ctx, () => lines(ctx, [[0, horizon], [w, horizon]]), T.magenta, Math.max(1, unit * 0.002));

      // Ground and road.
      ctx.fillStyle = lin(ctx, 0, horizon, 0, h, [c(T.night), c(T.deepNight)]);
      ctx.fillRect(0, horizon, w, depth);
      const roadHalf = w * 0.62;
      ctx.fillStyle = c(hex(0x140629));
      lines(ctx, [[center - unit * 0.01, horizon], [center + unit * 0.01, horizon], [center + roadHalf, h], [center - roadHalf, h]], true); ctx.fill();
      for (const side of [-1, 1]) neon(ctx, () => lines(ctx, [[center + side * unit * 0.01, horizon], [center + side * roadHalf, h]]), T.cyan, Math.max(1, unit * 0.003));

      // Lane dashes and street lamps rushing past in perspective.
      ctx.fillStyle = c(T.yellow, 0.85); ctx.beginPath();
      for (let i = 0; i < 30; i++) {
        const near = i + 1 - offset, far = near + 0.45;
        const yNear = horizon + depth / near, yFar = horizon + depth / far;
        if (yFar >= h) continue;
        const hn = unit * 0.012 / near, hf = unit * 0.012 / far, yn = Math.min(yNear, h);
        ctx.moveTo(center - hf, yFar); ctx.lineTo(center + hf, yFar); ctx.lineTo(center + hn, yn); ctx.lineTo(center - hn, yn); ctx.closePath();
      }
      ctx.fill();
      const lampOffset = scroll / 2 - Math.floor(scroll / 2);
      for (let i = 0; i < 10; i++) {
        const z = (i + 1 - lampOffset) * 2 - 1;
        if (z <= 0.35) continue;
        const y = horizon + depth / z, ph = unit * 0.45 / z;
        for (const side of [-1, 1]) {
          const x = center + side * roadHalf * 1.12 / z, lx = x - side * ph * 0.18, ly = y - ph;
          ctx.strokeStyle = c(hex(0x4A1F80)); ctx.lineWidth = Math.max(1, unit * 0.008 / z); ctx.lineCap = 'butt'; ctx.lineJoin = 'miter';
          ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, ly); ctx.lineTo(lx, ly); ctx.stroke();
          const glow = unit * 0.05 / z * (1 + 0.6 * audio.beatPulse);
          ctx.fillStyle = rad(ctx, lx, ly, 0, glow, [c(T.magenta), c(T.magenta, 0)]);
          circle(ctx, lx, ly, glow); ctx.fill();
        }
      }

      // The car.
      const cw = unit * 0.5, bounce = unit * 0.006 * audio.bass + unit * 0.002 * Math.sin(time * 9);
      const bottom = h * 0.95 - bounce, left = w / 2 - cw / 2, bh = cw * 0.26, top = bottom - bh;
      ctx.fillStyle = '#000';
      for (const s of [0.06, 0.8]) { rrect(ctx, left + cw * s, bottom - cw * 0.03, cw * 0.14, cw * 0.07, cw * 0.015); ctx.fill(); }
      ctx.fillStyle = c(hex(0x1D0A3A));
      lines(ctx, [[left + cw * 0.12, top], [left + cw * 0.24, top - cw * 0.17], [left + cw * 0.76, top - cw * 0.17], [left + cw * 0.88, top]], true); ctx.fill();
      ctx.fillStyle = lin(ctx, 0, top - cw * 0.15, 0, top, [c(T.purple), c(T.magenta, 0.8)]);
      lines(ctx, [[left + cw * 0.17, top - cw * 0.012], [left + cw * 0.26, top - cw * 0.15], [left + cw * 0.74, top - cw * 0.15], [left + cw * 0.83, top - cw * 0.012]], true); ctx.fill();
      ctx.fillStyle = lin(ctx, 0, top, 0, bottom, [c(hex(0x2B1050)), c(hex(0x12002B))]);
      rrect(ctx, left, top, cw, bh, cw * 0.04); ctx.fill();
      neon(ctx, () => rrect(ctx, left, top, cw, bh, cw * 0.04), T.magenta, Math.max(1, unit * 0.0015), 0.6);

      // Full-width taillight strip pulsing with the bass.
      const lx = left + cw * 0.04, ly = top + bh * 0.22, lw = cw * 0.92, lh = bh * 0.2;
      const intensity = 0.55 + 0.45 * audio.bass, red = hex(0xFF2E57);
      ctx.save(); ctx.shadowColor = c(red, intensity); ctx.shadowBlur = unit * (0.01 + 0.03 * audio.bass) * 2;
      ctx.fillStyle = c(mix(red, [255, 255, 255], 0.25 * intensity)); rrect(ctx, lx, ly, lw, lh, lh / 2); ctx.fill(); ctx.restore();
      ctx.strokeStyle = c(hex(0x7A0A2A), 0.6); ctx.lineWidth = Math.max(1, unit * 0.0015); ctx.beginPath();
      for (let i = 1; i < 12; i++) { const x = lx + lw * i / 12; ctx.moveTo(x, ly); ctx.lineTo(x, ly + lh); }
      ctx.stroke();
      const pw = cw * 0.2, ph2 = bh * 0.28, px = w / 2 - cw * 0.1, py = top + bh * 0.55;
      ctx.fillStyle = c(hex(0xE8E4F0)); rrect(ctx, px, py, pw, ph2, cw * 0.008); ctx.fill();
      ctx.fillStyle = c(T.night); ctx.font = `800 ${ph2 * 0.7}px ui-monospace, Menlo, monospace`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText('BEATS', px + pw / 2, py + ph2 / 2);
    },
  };
}

export const synthwave = {
  id: 'synthwave', name: 'Synthwave', accent: T.magenta,
  wallpapers: [
    { id: 'synthwave.outrun-grid', name: 'Outrun Grid', summary: 'A neon grid racing toward a striped sun, with wireframe mountains that rise with the spectrum.', make: makeOutrunGrid },
    { id: 'synthwave.neon-palms', name: 'Neon Palms', summary: 'Palm silhouettes at sunset over rippling water, and a neon sign that flickers on the beat.', make: makeNeonPalms },
    { id: 'synthwave.midnight-drive', name: 'Midnight Drive', summary: 'Cruising a neon highway. Taillights pulse with the bass and the skyline is an equalizer.', make: makeMidnightDrive },
  ],
};

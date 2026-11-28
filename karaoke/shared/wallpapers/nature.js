// Ocean & Nature collection, ported from BeatsWall/Collections/Nature/*.swift. Film grain is omitted.
import { hex, rgba, mix, hash01, PhaseClock, BeatEdge } from '../kit.js';
import { lin, rad, lines, dot, glow, scratch, withBlur } from './draw.js';

const T = { night: hex(0x0B1D3A), nightSky: hex(0x24496B), farWater: hex(0x2A5A85), nearWater: hex(0x0B2340), foam: hex(0xE8F4F2), moon: hex(0xF4EBC8), grass: hex(0x0F1A14), firefly: hex(0xD7F75B), white: [255, 255, 255] };
const addDot = (ctx, x, y, r) => { ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, Math.PI * 2); };

// ---------------------------------------------------------------- Swell
function makeSwell() {
  const tide = new PhaseClock(), N = 6;
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.5, phase = tide.advance(time, 0.7 + 1.2 * audio.mid), swell = 0.45 + 1.3 * audio.bass;
      ctx.fillStyle = lin(ctx, 0, 0, 0, horizon, [rgba(T.night), rgba(T.nightSky)]); ctx.fillRect(0, 0, w, h);
      ctx.fillStyle = 'rgba(255,255,255,0.7)'; ctx.beginPath();
      for (let i = 0; i < 80; i++) addDot(ctx, hash01(i, 0) * w, hash01(i, 1) * horizon * 0.8, Math.max(0, unit * 0.0018 * (0.5 + hash01(i, 2) + 0.5 * Math.sin(time * 2 + i))));
      ctx.fill();
      const mx = w * 0.72, my = h * 0.2, mr = unit * 0.06;
      glow(ctx, mx, my, mr * (4 + audio.level * 2), T.moon, 0.25); dot(ctx, mx, my, mr, rgba(T.moon));
      for (let layer = 0; layer < N; layer++) {
        const d = layer / (N - 1), base = horizon + (h - horizon) * (0.04 + 0.9 * d ** 1.3), amp = unit * (0.004 + 0.022 * d) * swell;
        const f = 2 * Math.PI / (unit * (0.12 + 0.3 * d)), speed = phase * (0.6 + 0.6 * d);
        const height = x => base - amp * (Math.sin(x * f + speed + layer * 1.7) + 0.35 * Math.sin(x * f * 2.3 - speed * 1.3 + layer));
        const step = unit * 0.008;
        const crest = () => { ctx.beginPath(); ctx.moveTo(0, height(0)); for (let x = step; x <= w + 2 * step; x += step) ctx.lineTo(x, height(x)); };
        crest(); ctx.lineTo(w + step, h); ctx.lineTo(0, h); ctx.closePath(); ctx.fillStyle = rgba(mix(T.farWater, T.nearWater, d)); ctx.fill();
        crest(); ctx.strokeStyle = rgba(T.foam, 0.12 + 0.15 * d); ctx.lineWidth = Math.max(1, unit * 0.002); ctx.stroke();
        ctx.fillStyle = rgba(T.foam, 0.85); ctx.beginPath();
        for (let x = 0, i = 0; x < w; x += unit * 0.012, i++) {
          if (Math.sin(x * f + speed + layer * 1.7) > 0.8 && hash01(i * 13 + layer, Math.floor(time * 6)) < 0.15 + 0.6 * audio.treble) addDot(ctx, x, height(x), unit * 0.0025 * (0.5 + d));
        }
        ctx.fill();
      }
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = rgba(T.moon, 0.35);
      for (let row = 0; row < 28; row++) {
        const t = row / 27, y = horizon + (h - horizon) * t ** 1.4 + unit * 0.004;
        const width = mr * (0.6 + 2.2 * t) * (0.5 + 0.5 * Math.sin(phase * 2 + row * 1.9)), shift = unit * 0.012 * Math.sin(phase + row * 0.9) * (0.5 + audio.mid);
        ctx.fillRect(mx - width / 2 + shift, y, width, unit * 0.004);
      }
      ctx.restore();
    },
  };
}

// ---------------------------------------------------------------- Firefly Meadow
function fireflies(ctx, w, h, unit, horizon, time, audio, front) {
  ctx.save(); ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 80; i++) {
    if ((i % 3 === 0) !== front) continue;
    const seed = hash01(i, 51), t = time * (0.08 + 0.1 * hash01(i, 52));
    const x = hash01(i, 53) * w + unit * 0.12 * Math.sin(t * 2.1 + seed * 9), y = horizon - unit * 0.05 + (h - horizon) * 0.8 * hash01(i, 54) + unit * 0.06 * Math.sin(t * 3.3 + seed * 5);
    const blink = Math.pow(Math.max(0, Math.sin(time * (0.6 + hash01(i, 55)) + seed * 20)), 6), flash = hash01(i, audio.beatCount) > 0.55 ? audio.beatPulse : 0;
    const b = Math.min(1, 0.15 + 0.85 * Math.max(blink, flash) * (0.6 + 0.6 * audio.treble)), s = front ? 1.4 : 1;
    glow(ctx, x, y, unit * 0.025 * s, T.firefly, 0.5 * b);
    dot(ctx, x, y, unit * 0.0035 * s, rgba(mix(T.firefly, T.white, 0.4), 0.3 + 0.7 * b));
  }
  ctx.restore();
}
function makeMeadow() {
  const breeze = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.62, wind = breeze.advance(time, 0.8 + 1.6 * audio.mid);
      ctx.fillStyle = lin(ctx, 0, 0, 0, horizon, ['#1B2A4A', '#6B4C7A', '#E07A5F']); ctx.fillRect(0, 0, w, h);
      ctx.fillStyle = 'rgba(255,255,255,0.6)'; ctx.beginPath();
      for (let i = 0; i < 40; i++) addDot(ctx, hash01(i, 0) * w, hash01(i, 1) * horizon * 0.35, unit * 0.0016 * (0.6 + hash01(i, 2)));
      ctx.fill();
      const ridge = (base, height, f, seed, color, bumps) => {
        ctx.beginPath(); ctx.moveTo(0, h);
        for (let x = 0; x <= w + 4; x += 4) {
          const s = x / unit * f; let y = base - height * (0.5 + 0.3 * Math.sin(s + seed) + 0.2 * Math.sin(s * 2.7 + seed * 3));
          if (bumps) y -= height * 0.25 * Math.abs(Math.sin(s * 9 + seed));
          ctx.lineTo(x, y);
        }
        ctx.lineTo(w + 4, h); ctx.closePath(); ctx.fillStyle = color; ctx.fill();
      };
      ridge(horizon, unit * 0.12, 2.2, 1, '#3A3554', false);
      ridge(horizon + unit * 0.03, unit * 0.1, 3.5, 4, '#1F2238', true);
      ctx.fillStyle = lin(ctx, 0, horizon, 0, h, ['#1A2420', rgba(T.grass)]); ctx.fillRect(0, horizon + unit * 0.02, w, h);
      fireflies(ctx, w, h, unit, horizon, time, audio, false);
      const layers = [new Path2D(), new Path2D(), new Path2D()];
      for (let i = 0; i < 320; i++) {
        const d = i / 320, x = hash01(i, 31) * (w + unit * 0.1) - unit * 0.05, base = horizon + (h - horizon) * (0.15 + 0.9 * d);
        const height = unit * (0.04 + 0.08 * hash01(i, 32)) * (0.5 + d), bend = Math.sin(wind + x / unit * 2.5 + hash01(i, 33)) * (0.25 + 0.5 * audio.mid) * height * 0.35, bw = unit * 0.004 * (0.6 + d);
        const p = layers[Math.min(Math.floor(d * 3), 2)];
        p.moveTo(x - bw, base); p.quadraticCurveTo(x - bw * 0.5, base - height * 0.6, x + bend, base - height); p.quadraticCurveTo(x + bw * 0.5, base - height * 0.6, x + bw, base); p.closePath();
      }
      ['#24332B', '#17241D', rgba(T.grass)].forEach((c, i) => { ctx.fillStyle = c; ctx.fill(layers[i]); });
      fireflies(ctx, w, h, unit, horizon, time, audio, true);
    },
  };
}

// ---------------------------------------------------------------- Rainy Window
function makeRainyWindow() {
  const BOKEH = [hex(0xFFB86B), hex(0xFF5A5F), hex(0x2EC4B6), hex(0xFFE8C2), hex(0x8E7CFF)];
  const clock = new PhaseClock(), edge = new BeatEdge();
  let drops = [];
  const bead = (ctx, x, y, r) => {
    const c = hex(0xC8D8E8);
    dot(ctx, x, y + r * 0.25, r, 'rgba(0,0,0,0.25)'); dot(ctx, x, y, r, rad(ctx, x, y, 0, r, [rgba(c, 0.15), rgba(c, 0.45)])); dot(ctx, x - r * 0.35, y - r * 0.35, r * 0.28, 'rgba(255,255,255,0.7)');
  };
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h);
      clock.advance(time);
      const dt = clock.deltaTime;
      if (edge.isNewBeat(audio)) for (let i = 0; i < 1 + Math.floor(2 * audio.bass); i++) {
        const x = Math.random() * w, y = Math.random() * h * 0.45;
        drops.push({ x, y, v: unit * 0.05, r: unit * (0.006 + 0.005 * Math.random()), trail: [[x, y]], seed: Math.random() * 10 });
      }
      for (const d of drops) {
        d.v += unit * 0.5 * dt; d.y += d.v * dt; d.x += Math.sin(time * 3 + d.seed) * unit * 0.01 * dt;
        d.trail.push([d.x, d.y]); if (d.trail.length > 60) d.trail.shift();
      }
      drops = drops.filter(d => d.y <= h + unit * 0.1);

      const k = 0.35, buf = scratch('nature.bokeh', Math.ceil(w * k), Math.ceil(h * k)), g = buf ? buf.ctx : ctx;
      g.save(); if (buf) g.scale(k, k);
      g.fillStyle = lin(g, 0, 0, 0, h, ['#0A1222', '#1B2438']); g.fillRect(0, 0, w, h);
      g.globalCompositeOperation = 'lighter';
      withBlur(g, unit * 0.018 * k, () => {
        for (let i = 0; i < 46; i++) {
          const x = hash01(i, 61) * w, y = h * (0.3 + 0.65 * hash01(i, 62)), r = unit * (0.025 + 0.055 * hash01(i, 63)), c = BOKEH[Math.floor(hash01(i, 64) * 5) % 5];
          const b = 0.28 + 0.7 * audio.spectrum[i % audio.spectrum.length];
          dot(g, x, y, r, rad(g, x, y, 0, r, [rgba(c, b), rgba(c, b * 0.6), rgba(c, 0)]));
        }
      });
      g.restore(); if (buf) ctx.drawImage(buf.canvas, 0, 0, w, h);

      ctx.beginPath();
      const streaks = 40 + Math.floor(140 * audio.level);
      for (let i = 0; i < streaks; i++) {
        const fall = (hash01(i, 72) + time * (1.2 + hash01(i, 71)) * 0.6) % 1, x = hash01(i, 73) * w + fall * unit * 0.05, y = fall * (h + unit * 0.1) - unit * 0.05;
        ctx.moveTo(x, y); ctx.lineTo(x - unit * 0.006, y - unit * 0.04);
      }
      ctx.strokeStyle = 'rgba(255,255,255,0.12)'; ctx.lineWidth = Math.max(1, unit * 0.0012); ctx.stroke();
      const beads = 90 + Math.floor(90 * audio.level);
      for (let i = 0; i < beads; i++) bead(ctx, hash01(i, 81) * w, hash01(i, 82) * h, unit * (0.002 + 0.005 * hash01(i, 83) ** 2));
      for (const d of drops) {
        if (d.trail.length > 1) { lines(ctx, d.trail); ctx.strokeStyle = 'rgba(159,180,200,0.18)'; ctx.lineWidth = d.r * 1.1; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke(); }
        bead(ctx, d.x, d.y, d.r);
      }
      const bar = unit * 0.03; ctx.fillStyle = '#070B12';
      ctx.fillRect(0, 0, w, bar); ctx.fillRect(0, h - bar, w, bar); ctx.fillRect(0, 0, bar, h); ctx.fillRect(w - bar, 0, bar, h); ctx.fillRect(w / 2 - bar * 0.4, 0, bar * 0.8, h);
    },
  };
}

export const nature = {
  id: 'nature', name: 'Ocean & Nature', accent: hex(0x3FA7A3),
  wallpapers: [
    { id: 'nature.swell', name: 'Swell', summary: 'Moonlit waves that rise with the bass.', make: makeSwell },
    { id: 'nature.firefly-meadow', name: 'Firefly Meadow', summary: 'Dusk grass swaying while fireflies blink.', make: makeMeadow },
    { id: 'nature.rainy-window', name: 'Rainy Window', summary: 'City lights blurred behind wet glass.', make: makeRainyWindow },
  ],
};

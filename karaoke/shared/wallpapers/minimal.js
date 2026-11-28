// Abstract Minimal collection, ported from BeatsWall/Collections/Minimal/*.swift. Dither is omitted.
import { PhaseClock, hex, rgba, mix, clamp } from '../kit.js';
import { rad, rrect, circle, dot, scratch, withBlur } from './draw.js';

const T = { paper: hex(0xF5F1EA), paperShade: hex(0xEAE3D8), slate: hex(0x24272F), peach: hex(0xF4A99B), sage: hex(0xA8C3A0), sky: hex(0x9CC3E6), lilac: hex(0xC3B1E1), butter: hex(0xF6D98B), coral: hex(0xF28482) };
const PALETTE = [T.peach, T.butter, T.sage, T.sky, T.lilac, T.coral];
const blend = t => { const s = clamp(t) * (PALETTE.length - 1), i = Math.min(Math.floor(s), PALETTE.length - 2); return mix(PALETTE[i], PALETTE[i + 1], s - i); };
function band(i, n, spec) {
  const size = Math.max(Math.floor(spec.length / n), 1), start = Math.min(i * size, spec.length - size);
  let sum = 0; for (let k = start; k < start + size; k++) sum += spec[k];
  return sum / size;
}

function makeRings() {
  const spin = new PhaseClock(), N = 12;
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), cx = w / 2, cy = h / 2, rot = spin.advance(time, 0.05 + 0.25 * audio.mid);
      const breathe = 1 + 0.025 * audio.beatPulse + 0.02 * Math.sin(time * 0.5);
      ctx.fillStyle = rad(ctx, cx, cy, 0, Math.max(w, h) * 0.7, [rgba(T.paper), rgba(T.paperShade)]); ctx.fillRect(0, 0, w, h);
      const core = unit * 0.04 * (1 + 0.6 * audio.level) * breathe;
      dot(ctx, cx, cy, core, rad(ctx, cx, cy, 0, core, [rgba(T.peach), rgba(T.peach, 0.3)]));
      ctx.save(); ctx.lineCap = 'round';
      for (let i = 0; i < N; i++) {
        const e = band(i, N, audio.spectrum), r = (unit * (0.075 + 0.032 * i) + unit * 0.012 * e) * breathe, color = blend(i / (N - 1));
        ctx.lineWidth = unit * (0.003 + 0.009 * e);
        if (i % 3 === 1) {
          const dash = 2 * Math.PI * r / (24 + i * 2), dir = i % 2 === 0 ? 1 : -1;
          ctx.setLineDash([dash * 0.35, dash * 0.65]); ctx.lineDashOffset = rot * dir * r * 0.6; ctx.strokeStyle = rgba(color, 0.45 + 0.55 * e);
        } else { ctx.setLineDash([]); ctx.strokeStyle = rgba(color, 0.35 + 0.65 * e); }
        circle(ctx, cx, cy, r); ctx.stroke();
      }
      ctx.restore();
    },
  };
}

function makeBarGrid() {
  return {
    draw(ctx, w, h, { audio }) {
      const unit = Math.min(w, h), cx = w / 2, cy = h / 2;
      ctx.fillStyle = rgba(T.slate); ctx.fillRect(0, 0, w, h);
      const sp = unit * 0.05; ctx.fillStyle = 'rgba(255,255,255,0.06)'; ctx.beginPath();
      for (let y = (h % sp) / 2; y < h; y += sp) for (let x = (w % sp) / 2; x < w; x += sp) { ctx.moveTo(x + 1, y); ctx.arc(x, y, 1, 0, Math.PI * 2); }
      ctx.fill();
      const n = audio.spectrum.length, total = Math.min(w * 0.72, unit * 1.3), pitch = total / n, bw = pitch * 0.55, maxH = unit * 0.26;
      audio.spectrum.forEach((e, i) => {
        const bh = Math.max(bw, maxH * (0.04 + 0.96 * e));
        rrect(ctx, cx - total / 2 + pitch * (i + 0.5) - bw / 2, cy - bh, bw, bh * 2, bw / 2);
        ctx.fillStyle = rgba(blend(i / (n - 1)), 0.55 + 0.45 * e); ctx.fill();
      });
      for (let i = 0; i < 4; i++) dot(ctx, cx + (i - 1.5) * unit * 0.03, cy + maxH + unit * 0.08, unit * 0.006, `rgba(255,255,255,${i === audio.beatCount % 4 ? 0.4 + 0.5 * audio.beatPulse : 0.12})`);
    },
  };
}

function makeBlobs() {
  const drift = new PhaseClock(), COLORS = [T.coral, T.butter, T.sky, T.lilac, T.sage];
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), phase = drift.advance(time, 0.08 + 0.2 * audio.mid);
      ctx.fillStyle = '#F7F2EE'; ctx.fillRect(0, 0, w, h);
      // Blur a small offscreen copy: much cheaper than blurring at full size.
      const k = 0.25, layer = scratch('minimal.blobs', Math.ceil(w * k), Math.ceil(h * k)), g = layer ? layer.ctx : ctx, s = layer ? k : 1;
      const paint = () => COLORS.forEach((color, i) => {
        const x = w * (0.5 + 0.32 * Math.sin(phase * (0.7 + 0.25 * i) + i * 1.7)), y = h * (0.5 + 0.3 * Math.cos(phase * (0.9 + 0.17 * i) + i * 2.3));
        const r = unit * (0.22 + 0.08 * band(i, COLORS.length, audio.spectrum)) * (1 + 0.06 * audio.beatPulse);
        dot(g, x * s, y * s, r * s, rgba(color, 0.85));
      });
      if (layer) { withBlur(g, unit * 0.14 * k, paint); ctx.drawImage(layer.canvas, 0, 0, w, h); } else paint();
    },
  };
}

export const minimal = {
  id: 'minimal', name: 'Abstract Minimal', accent: T.lilac,
  wallpapers: [
    { id: 'minimal.breathing-rings', name: 'Breathing Rings', summary: 'Concentric pastel rings, each one a slice of the spectrum, breathing gently on the beat.', make: makeRings },
    { id: 'minimal.bar-grid', name: 'Bar Grid', summary: 'A mirrored equalizer of rounded bars on a quiet dot grid.', make: makeBarGrid },
    { id: 'minimal.gradient-blobs', name: 'Gradient Blobs', summary: 'Soft color blobs drifting and melting together.', make: makeBlobs },
  ],
};

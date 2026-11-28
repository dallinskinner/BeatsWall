// Tropical Jungle collection, ported from BeatsWall/Collections/Jungle/*.swift. Film grain is omitted.
import { hex, rgba, mix, hash01, PhaseClock, BeatEdge, beatProgress } from '../kit.js';
import { lin, rad, lines, dot, ell, glow, scratch, withBlur } from './draw.js';

const T = { deep: hex(0x0B2A1C), shade: hex(0x123D29), mid: hex(0x1E5A3A), leaf: hex(0x2E8B57), leafLight: hex(0x6BBF59), sun: hex(0xFFE9A8), mist: hex(0xDDEFE3), bark: hex(0x5A3A22), red: hex(0xE63946), blue: hex(0x1D7FD8), yellow: hex(0xFFC300), frog: hex(0x7CFFB2), white: [255, 255, 255] };

/** Basis of a leaf: returns P(along, side) in screen space. */
const basis = (bx, by, a) => (d, n) => [bx + Math.cos(a) * d - Math.sin(a) * n, by + Math.sin(a) * d + Math.cos(a) * n];
/** Adds a monstera leaf outline to the current path. */
function addLeaf(ctx, bx, by, a, len) {
  const P = basis(bx, by, a), s = len * 0.35, wd = len * 0.36;
  ctx.moveTo(...P(s, 0));
  ctx.bezierCurveTo(...P(s + len * 0.05, wd * 1.3), ...P(len * 0.85, wd * 0.6), ...P(len, 0));
  ctx.bezierCurveTo(...P(len * 0.85, -wd * 0.6), ...P(s + len * 0.05, -wd * 1.3), ...P(s, 0));
  ctx.closePath();
}
function addSlits(ctx, bx, by, a, len) {
  const P = basis(bx, by, a);
  for (let i = 1; i <= 4; i++) {
    const t = i / 5, d = len * (0.35 + 0.65 * t), reach = len * 0.36 * (1 - Math.abs(t - 0.4));
    for (const side of [-1, 1]) { ctx.moveTo(...P(d, side * reach * 0.35)); ctx.lineTo(...P(d + len * 0.06, side * reach * 1.1)); ctx.lineTo(...P(d + len * 0.1, side * reach * 1.1)); ctx.closePath(); }
  }
}
function addFrond(ctx, bx, by, a, len, droop) {
  const dx = Math.cos(a), dy = Math.sin(a), nx = -dy, ny = dx;
  for (let i = 0; i < 14; i++) {
    const t = 0.15 + 0.85 * i / 14, px = bx + dx * len * t, py = by + dy * len * t + droop * t * t, l = len * 0.22 * (1 - t * 0.6);
    for (const side of [-1, 1]) {
      ctx.moveTo(px, py);
      ctx.quadraticCurveTo(px + nx * side * l * 0.5 + dx * l * 0.4, py + ny * side * l * 0.5 + dy * l * 0.4, px + nx * side * l + dx * l * 0.5, py + ny * side * l + dy * l * 0.5 + l * 0.3);
      ctx.quadraticCurveTo(px + nx * side * l * 0.4 + dx * l * 0.1, py + ny * side * l * 0.4 + dy * l * 0.1, px + dx * len * 0.03, py + dy * len * 0.03);
      ctx.closePath();
    }
  }
}

// ---------------------------------------------------------------- Canopy
function makeCanopy() {
  const breeze = new PhaseClock();
  const LAYERS = [[hex(0x5FAF6A), 10, 0.18], [T.leaf, 9, 0.26], [T.mid, 7, 0.36], [T.shade, 6, 0.5]];
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), wind = breeze.advance(time, 0.6 + 1.4 * audio.mid), sway = 0.04 + 0.1 * audio.mid;
      ctx.fillStyle = rad(ctx, w * 0.55, h * 0.35, 0, Math.max(w, h) * 0.7, ['#BFE3A8', rgba(T.leafLight), rgba(T.mid)]); ctx.fillRect(0, 0, w, h);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 5; i++) {
        const x = w * (0.2 + 0.15 * i);
        lines(ctx, [[x, 0], [x + unit * 0.06, 0], [x + unit * 0.3, h], [x + unit * 0.16, h]], true);
        ctx.fillStyle = lin(ctx, x, 0, x, h, [rgba(T.sun, 0.18), rgba(T.sun, 0)]); ctx.fill();
      }
      ctx.restore();
      LAYERS.forEach(([color, count, size], layer) => {
        const leaves = Array.from({ length: count }, (_, i) => {
          const seed = layer * 40 + i, edge = Math.floor(hash01(seed, 1) * 4), along = hash01(seed, 2), r = hash01(seed, 3);
          const [x, y, a] = edge === 0 ? [along * w, -unit * 0.05, Math.PI / 2 + (r - 0.5) * 1.2]
            : edge === 1 ? [-unit * 0.05, along * h, r - 0.6]
              : edge === 2 ? [w + unit * 0.05, along * h, Math.PI + (0.6 - r)]
                : [along * w, h + unit * 0.05, -Math.PI / 2 + (r - 0.5) * 1.2];
          return { x, y, a: a + Math.sin(wind + seed) * sway * (1 + layer * 0.3), len: unit * size * (0.7 + 0.5 * hash01(seed, 4)), broad: hash01(seed, 5) > 0.4 };
        });
        ctx.beginPath();
        for (const l of leaves) if (l.broad) { ctx.moveTo(l.x, l.y); ctx.lineTo(l.x + Math.cos(l.a) * l.len * 0.85, l.y + Math.sin(l.a) * l.len * 0.85); }
        ctx.strokeStyle = rgba(color); ctx.lineWidth = unit * 0.006; ctx.stroke();
        const buf = scratch('jungle.leaves', Math.ceil(w), Math.ceil(h)), g = buf ? buf.ctx : ctx;
        g.fillStyle = rgba(color);
        for (const l of leaves) { g.beginPath(); if (l.broad) addLeaf(g, l.x, l.y, l.a, l.len); else addFrond(g, l.x, l.y, l.a, l.len * 1.3, l.len * 0.25); g.fill(); }
        if (buf) {
          g.globalCompositeOperation = 'destination-out'; g.fillStyle = '#000'; g.beginPath();
          for (const l of leaves) if (l.broad) addSlits(g, l.x, l.y, l.a, l.len);
          g.fill(); g.globalCompositeOperation = 'source-over'; ctx.drawImage(buf.canvas, 0, 0, w, h);
        }
        if (layer < 3) { ctx.fillStyle = rgba(T.mist, 0.06); ctx.fillRect(0, 0, w, h); }
      });
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 18; i++) {
        const b = (0.5 + 0.5 * Math.sin(time * (2 + 3 * hash01(i, 8)) + i)) * (0.3 + 0.7 * audio.treble);
        glow(ctx, hash01(i, 6) * w + unit * 0.02 * Math.sin(wind + i), hash01(i, 7) * h, unit * (0.02 + 0.03 * hash01(i, 9)), T.sun, 0.35 * b);
      }
      ctx.restore();
    },
  };
}

// ---------------------------------------------------------------- Parrot Party
const PARROTS = [[0.2, T.red, T.blue, T.yellow, T.white], [0.4, T.blue, hex(0x155A9E), T.yellow, T.white], [0.6, hex(0x3BB273), hex(0x1F7A4D), T.red, hex(0xE8F5C8)], [0.8, T.yellow, hex(0x3BB273), T.blue, T.white]];
function parrot(ctx, x, y, s, bob, flare, facing, [, body, wing, accent, face]) {
  ctx.save(); ctx.translate(x, y); ctx.scale(s * facing, s);
  const dip = bob * 0.12;
  const poly = (pts, color) => { lines(ctx, pts, true); ctx.fillStyle = rgba(color); ctx.fill(); };
  const oval = (ox, oy, ow, oh, color) => { ell(ctx, ox, oy, ow, oh); ctx.fillStyle = color; ctx.fill(); };
  poly([[-0.12, -0.15], [-0.35, 0.9], [-0.22, 0.95], [0.05, -0.1]], wing);
  poly([[-0.3, 0.7], [-0.35, 0.9], [-0.22, 0.95], [-0.17, 0.72]], accent);
  ctx.save(); ctx.rotate(0.25 + dip);
  oval(-0.22, -0.75, 0.44, 0.8, rgba(body));
  ctx.translate(-0.05, -0.5); ctx.rotate(-1.6 * flare);
  ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(0.2, 0.3, -0.12, 0.62); ctx.quadraticCurveTo(-0.25, 0.2, 0, 0); ctx.fillStyle = rgba(wing); ctx.fill();
  ctx.beginPath(); for (let k = 1; k <= 3; k++) { ctx.moveTo(-0.02 * k, 0.15 * k); ctx.lineTo(-0.1 - 0.02 * k, 0.2 + 0.15 * k); }
  ctx.strokeStyle = 'rgba(0,0,0,0.2)'; ctx.lineWidth = 0.015; ctx.stroke();
  oval(-0.04, 0.05, 0.12, 0.18, rgba(accent));
  ctx.restore();
  const hx = 0.12 + dip * 0.8, hy = -0.82 + dip;
  oval(hx - 0.19, hy - 0.19, 0.38, 0.38, rgba(body)); oval(hx - 0.02, hy - 0.1, 0.2, 0.2, rgba(face));
  oval(hx + 0.05, hy - 0.06, 0.07, 0.07, '#000'); oval(hx + 0.07, hy - 0.05, 0.02, 0.02, '#fff');
  ctx.beginPath(); ctx.moveTo(hx + 0.14, hy - 0.06); ctx.quadraticCurveTo(hx + 0.3, hy - 0.06, hx + 0.24, hy + 0.12); ctx.quadraticCurveTo(hx + 0.18, hy + 0.06, hx + 0.14, hy + 0.06); ctx.closePath(); ctx.fillStyle = '#2B2B2B'; ctx.fill();
  for (const dx of [-0.05, 0.08]) oval(dx - 0.05, -0.04, 0.1, 0.07, '#6B6B6B');
  ctx.restore();
}
function makeParrots() {
  const breeze = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), wind = breeze.advance(time, 0.5 + audio.mid);
      ctx.fillStyle = lin(ctx, 0, 0, 0, h, ['#9FD48A', rgba(T.leaf), rgba(T.mid)]); ctx.fillRect(0, 0, w, h);
      // Soft-focus leaves: drawn small and blurred, then scaled up.
      const k = 0.33, buf = scratch('jungle.soft', Math.ceil(w * k), Math.ceil(h * k)), g = buf ? buf.ctx : ctx;
      g.save(); if (buf) g.scale(k, k);
      withBlur(g, unit * 0.02 * k, () => {
        for (let i = 0; i < 14; i++) {
          const x = hash01(i, 1) * w, y = i % 2 === 0 ? -unit * 0.05 : h + unit * 0.05;
          const a = (i % 2 === 0 ? Math.PI / 2 : -Math.PI / 2) + (hash01(i, 2) - 0.5) + Math.sin(wind + i) * 0.05;
          g.beginPath(); addLeaf(g, x, y, a, unit * (0.3 + 0.2 * hash01(i, 3))); g.fillStyle = i % 3 === 0 ? rgba(T.shade, 0.7) : rgba(T.mid, 0.8); g.fill();
        }
      });
      g.restore(); if (buf) ctx.drawImage(buf.canvas, 0, 0, w, h);
      const by = h * 0.68;
      for (const [color, width] of [[rgba(T.bark), 0.035], ['#7A5233', 0.01]]) {
        ctx.beginPath(); ctx.moveTo(-unit * 0.05, by + unit * 0.04); ctx.bezierCurveTo(w * 0.3, by - unit * 0.03, w * 0.7, by + unit * 0.05, w + unit * 0.05, by - unit * 0.02);
        ctx.strokeStyle = color; ctx.lineWidth = unit * width; ctx.lineCap = 'round'; ctx.stroke();
      }
      const beat = beatProgress(audio, time);
      PARROTS.forEach((p, i) => {
        const t = p[0], perch = by + unit * (0.04 * (1 - t) ** 3 - 0.09 * (1 - t) ** 2 * t + 0.15 * (1 - t) * t * t - 0.02 * t ** 3);
        const local = beat + (i % 2 === 0 ? 0 : 0.5), bob = Math.exp(-(local - Math.floor(local)) * 6);
        parrot(ctx, w * t, perch - unit * 0.015, unit * 0.17, bob, audio.bass > 0.65 ? audio.beatPulse : 0, i < 2 ? 1 : -1, p);
      });
    },
  };
}

// ---------------------------------------------------------------- Waterfall Pool
function frog(ctx, x, y, s, puff, bright) {
  const body = rgba(mix(T.frog, T.leaf, 0.4));
  ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, x, y, s * 2, T.frog, 0.15 + 0.3 * bright); ctx.restore();
  ell(ctx, x - s * 0.7, y - s * 0.35, s * 1.4, s * 0.8); ctx.fillStyle = body; ctx.fill();
  for (const side of [-1, 1]) {
    const ex = x + side * s * 0.35, ey = y - s * 0.35;
    dot(ctx, ex, ey, s * 0.2, body); dot(ctx, ex, ey, s * 0.11, '#FFB000');
    ell(ctx, ex - s * 0.03, ey - s * 0.09, s * 0.06, s * 0.18); ctx.fillStyle = '#000'; ctx.fill();
  }
  const sac = s * (0.12 + 0.35 * puff), ty = y + s * 0.32;
  ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, x, ty, sac * 2.5, T.frog, 0.5 * puff); ctx.restore();
  ell(ctx, x - sac, ty - sac * 0.8, sac * 2, sac * 1.6); ctx.fillStyle = rgba(hex(0xE8FFD8), 0.9); ctx.fill();
}
function makeWaterfall() {
  const flow = new PhaseClock(), edge = new BeatEdge();
  let rings = [], lastIdle = 0;
  return {
    draw(ctx, w, h, { time, audio }) {
      if (edge.isNewBeat(audio)) rings.push({ x: 0.35 + 0.3 * Math.random(), y: 0.05 + 0.25 * Math.random(), born: time });
      if (time - lastIdle > 0.8) { lastIdle = time; rings.push({ x: 0.1 + 0.8 * Math.random(), y: 0.1 + 0.8 * Math.random(), born: time }); }
      rings = rings.filter(r => time - r.born <= 2.5 && time >= r.born);
      const unit = Math.min(w, h), phase = flow.advance(time, 1 + audio.level), pool = h * 0.68, fx = w * 0.42, fw = w * 0.16;
      ctx.fillStyle = lin(ctx, 0, 0, 0, h, ['#16324A', '#1E4A3A', rgba(T.deep)]); ctx.fillRect(0, 0, w, h);
      for (const side of [-1, 1]) {
        const inner = side < 0 ? fx : fx + fw, outer = side < 0 ? -unit * 0.05 : w + unit * 0.05, pts = [[outer, pool + unit * 0.02], [outer, h * 0.05]];
        for (let s = 0; s <= 10; s++) { const t = s / 10; pts.push([outer + (inner - outer) * t, h * 0.05 * (1 - t) + unit * 0.02 * hash01(s, side < 0 ? 1 : 2)]); }
        pts.push([inner, pool + unit * 0.02]);
        lines(ctx, pts, true); ctx.fillStyle = lin(ctx, outer, 0, inner, 0, ['#2A3A36', '#16211E']); ctx.fill();
        for (let i = 0; i < 6; i++) {
          ctx.beginPath(); addFrond(ctx, outer + (inner - outer) * (0.1 + 0.15 * i), h * (0.03 + 0.05 * hash01(i, 4)), Math.PI / 2 + side * 0.3 + Math.sin(phase * 0.5 + i) * 0.05, unit * (0.12 + 0.08 * hash01(i, 5)), unit * 0.02);
          ctx.fillStyle = rgba(i % 2 === 0 ? T.leaf : T.mid); ctx.fill();
        }
      }
      ctx.fillStyle = lin(ctx, 0, 0, 0, pool, ['#8FD0E8', '#CFEFF8']); ctx.fillRect(fx, 0, fw, pool);
      ctx.fillStyle = 'rgba(255,255,255,0.7)';
      for (let i = 0; i < 40; i++) {
        const len = unit * (0.06 + 0.1 * hash01(i, 11)), y = ((hash01(i, 12) + phase * (0.6 + 0.4 * hash01(i, 13))) % 1) * (pool + len) - len;
        ctx.fillRect(fx + fw * hash01(i, 10), y, Math.max(1, unit * 0.003), len);
      }
      ctx.fillStyle = lin(ctx, 0, pool, 0, h, ['#2C6E78', '#123A3E']); ctx.fillRect(0, pool, w, h - pool);
      for (const r of rings) {
        const age = time - r.born, rr = unit * (0.02 + age * 0.12);
        ell(ctx, w * r.x - rr, pool + (h - pool) * r.y - rr * 0.3, rr * 2, rr * 0.6); ctx.strokeStyle = `rgba(255,255,255,${Math.max(0, 0.35 * (1 - age / 2.5))})`; ctx.lineWidth = Math.max(1, unit * 0.002); ctx.stroke();
      }
      for (let i = 0; i < 18; i++) {
        const rise = (hash01(i, 20) + phase * 0.12) % 1, r = unit * (0.03 + 0.05 * rise) * 1.6;
        glow(ctx, fx + fw / 2 + fw * (hash01(i, 21) * 1.8 - 0.9), pool - unit * 0.3 * rise, r, T.white, 0.35 * (1 - rise));
      }
      for (let i = 0; i < 10; i++) glow(ctx, fx + fw * i / 9, pool + unit * 0.01 * Math.sin(phase * 4 + i), unit * 0.055, T.white, 0.8);
      [[0.18, 0.8, 0.07], [0.75, 0.84, 0.08], [0.88, 0.74, 0.05], [0.3, 0.92, 0.05]].forEach(([px, py, r], i) => {
        const x = w * px, y = h * py;
        ell(ctx, x - unit * r, y - unit * r * 0.35, unit * r * 2, unit * r * 0.7); ctx.fillStyle = '#3E8E4A'; ctx.fill();
        if (i < 2) frog(ctx, x, y - unit * 0.02, unit * 0.05, audio.beatPulse * (i === 0 ? 1 : audio.beatCount % 2 === 0 ? 0.3 : 1), audio.level);
      });
    },
  };
}

export const jungle = {
  id: 'jungle', name: 'Tropical Jungle', accent: T.leafLight,
  wallpapers: [
    { id: 'jungle.canopy', name: 'Canopy', summary: 'Giant leaves swaying while sunlight dapples through on the hi-hats.', make: makeCanopy },
    { id: 'jungle.parrot-party', name: 'Parrot Party', summary: 'Four parrots bobbing on and off the beat.', make: makeParrots },
    { id: 'jungle.waterfall-pool', name: 'Waterfall Pool', summary: 'A misty waterfall and glowing frogs puffing their throats on the beat.', make: makeWaterfall },
  ],
};

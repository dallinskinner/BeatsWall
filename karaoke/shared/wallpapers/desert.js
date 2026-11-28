// Desert Night collection, ported from BeatsWall/Collections/Desert/*.swift. Film grain is omitted.
import { PhaseClock, BeatEdge, hash01, hex, rgba, mix, beatProgress } from '../kit.js';
import { lin, rad, circle, lines, ell, withBlur } from './draw.js';

const T = {
  skyTop: hex(0x0D0A24), skyMid: hex(0x231A48), horizon: hex(0x5E3A5E), sandLit: hex(0x9B6A6A), sand: hex(0x5A3A4A),
  duneShadow: hex(0x2A1B34), silhouette: hex(0x140E1C), moon: hex(0xF3E7C9), fire: hex(0xFF8C2B), flame: hex(0xFFD45C), ember: hex(0xFF4D1A),
};
const c = rgba, H = hex;

function glow(ctx, x, y, radius, color, opacity) {
  ctx.fillStyle = rad(ctx, x, y, 0, radius, [c(color, opacity), c(color, 0)]);
  circle(ctx, x, y, radius); ctx.fill();
}
function sky(ctx, w, h, horizon) {
  ctx.fillStyle = lin(ctx, 0, 0, 0, horizon, [c(T.skyTop), c(T.skyMid), c(T.horizon)]); ctx.fillRect(0, 0, w, h);
}
function drawStars(ctx, w, h, maxY, count, time, twinkle) {
  const unit = Math.min(w, h), dim = [], bright = [];
  for (let i = 0; i < count; i++) {
    const x = hash01(i, 401) * w, y = hash01(i, 402) * maxY;
    const shimmer = 0.5 + 0.5 * Math.sin(time * (0.8 + 2 * hash01(i, 403)) + i);
    const r = unit * 0.0014 * (0.5 + hash01(i, 404) * 1.2 + twinkle * shimmer * 0.6);
    if (hash01(i, 405) > 0.85) bright.push(x, y, r * 1.4); else dim.push(x, y, r);
  }
  const dots = (list, color) => { ctx.fillStyle = color; ctx.beginPath(); for (let i = 0; i < list.length; i += 3) { ctx.moveTo(list[i] + list[i + 2], list[i + 1]); ctx.arc(list[i], list[i + 1], list[i + 2], 0, Math.PI * 2); } ctx.fill(); };
  dots(dim, 'rgba(255,255,255,0.6)'); dots(bright, 'rgba(255,255,255,0.95)');
}
/** Adds a rounded rect as a subpath (no beginPath). */
function addRR(ctx, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}
/** A saguaro: trunk with one or two upturned arms. Adds to the current path. */
function addCactus(ctx, bx, by, height, seed) {
  const width = height * 0.14;
  addRR(ctx, bx - width / 2, by - height, width, height, width / 2);
  for (const side of [-1, 1]) {
    const k = side < 0 ? 0 : 1;
    if (!(hash01(seed, k + 1) > 0.25)) continue;
    const armY = by - height * (0.35 + 0.25 * hash01(seed, 3 + k)), reach = width * 1.4, rise = height * (0.2 + 0.15 * hash01(seed, 5 + k)), aw = width * 0.75;
    addRR(ctx, side < 0 ? bx - reach - aw / 2 : bx, armY - aw / 2, reach + aw / 2, aw, aw / 2);
    addRR(ctx, bx + side * reach - aw / 2, armY - rise, aw, rise + aw / 2, aw / 2);
  }
}

// ---------------------------------------------------------------- Campfire
function makeCampfire() {
  const TONGUES = [[-0.035, 0.13, 0.045, T.ember], [0.035, 0.14, 0.045, T.ember], [0, 0.2, 0.06, T.fire], [-0.018, 0.12, 0.035, T.fire], [0.02, 0.13, 0.035, T.flame], [0, 0.09, 0.03, H(0xFFF3C4)]];
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.62, ground = h * 0.8, fx = w * 0.5, fy = ground + unit * 0.02, heat = 0.45 + 0.55 * audio.bass;
      sky(ctx, w, h, horizon);
      drawStars(ctx, w, h, horizon * 0.9, 260, time, audio.treble);

      [[horizon, 0.04, c(T.sand, 0.7)], [horizon + unit * 0.06, 0.05, c(T.duneShadow)]].forEach(([base, amp, color], index) => {
        ctx.fillStyle = color; ctx.beginPath(); ctx.moveTo(0, h);
        for (let x = 0; x <= w + 6; x += 6) { const s = x / unit; ctx.lineTo(x, base - unit * amp * (1 + Math.sin(s * 1.6 + index * 2) * 0.8 + Math.sin(s * 3.7) * 0.2)); }
        ctx.lineTo(w + 6, h); ctx.closePath(); ctx.fill();
      });
      ctx.fillStyle = lin(ctx, 0, ground, 0, h, [c(H(0x24182C)), c(T.silhouette)]); ctx.fillRect(0, ground - unit * 0.03, w, h);

      // Firelight washing over the ground and the camp.
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.translate(fx, fy); ctx.scale(1, 0.35);
      glow(ctx, 0, 0, unit * (0.5 + 0.2 * heat), T.fire, 0.35 * heat); ctx.restore();

      // Tent on the left, lit on its fire-facing side.
      const tbx = w * 0.27, tby = ground;
      ctx.fillStyle = lin(ctx, tbx - unit * 0.16, 0, tbx + unit * 0.14, 0, [c(T.silhouette), c(mix(H(0x7A3E2A), T.silhouette, 1 - heat * 0.8))]);
      lines(ctx, [[tbx - unit * 0.16, tby], [tbx, tby - unit * 0.2], [tbx + unit * 0.14, tby]], true); ctx.fill();
      ctx.fillStyle = c(T.silhouette);
      lines(ctx, [[tbx - unit * 0.01, tby - unit * 0.18], [tbx + unit * 0.05, tby], [tbx - unit * 0.04, tby]], true); ctx.fill();

      ctx.beginPath(); addCactus(ctx, w * 0.78, ground + unit * 0.01, unit * 0.3, 1); addCactus(ctx, w * 0.9, ground - unit * 0.01, unit * 0.18, 4); ctx.fill();
      ctx.fillStyle = c(H(0x3A2A30)); ctx.beginPath(); // rocks circling the fire
      for (let i = 0; i < 7; i++) {
        const a = i / 7 * Math.PI + Math.PI * 0.02, px = fx + Math.cos(a) * unit * 0.09, py = fy + Math.sin(a) * unit * 0.018 + unit * 0.005;
        ctx.moveTo(px + unit * 0.018, py); ctx.ellipse(px, py, unit * 0.018, unit * 0.011, 0, 0, Math.PI * 2);
      }
      ctx.fill();
      ctx.strokeStyle = c(H(0x3A2218)); ctx.lineWidth = unit * 0.018; ctx.lineCap = 'round'; ctx.beginPath(); // logs
      ctx.moveTo(fx - unit * 0.07, fy + unit * 0.005); ctx.lineTo(fx + unit * 0.06, fy - unit * 0.02);
      ctx.moveTo(fx + unit * 0.07, fy + unit * 0.005); ctx.lineTo(fx - unit * 0.06, fy - unit * 0.02); ctx.stroke();

      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      glow(ctx, fx, fy - unit * 0.08, unit * (0.25 + 0.12 * heat), T.fire, 0.3 * heat);
      TONGUES.forEach(([dx, th, tw, color], i) => {
        const flicker = 0.85 + 0.15 * Math.sin(time * (9 + i * 2.3) + i) * Math.sin(time * 5.1 + i);
        const height = unit * th * ((0.65 + 0.5 * heat) * flicker), bx = fx + unit * dx, by = fy - unit * 0.01;
        const sway = unit * 0.02 * Math.sin(time * 3 + i * 1.7), tipX = bx + sway, tipY = by - height, half = unit * tw / 2;
        ctx.fillStyle = c(color, 0.85); ctx.beginPath(); ctx.moveTo(bx - half, by);
        ctx.quadraticCurveTo(bx - half * 1.1 + sway * 0.3, by - height * 0.55, tipX, tipY);
        ctx.quadraticCurveTo(bx + half * 1.1 + sway * 0.3, by - height * 0.55, bx + half, by);
        ctx.quadraticCurveTo(bx, by + half * 0.6, bx - half, by); ctx.closePath(); ctx.fill();
      });
      ctx.fillStyle = c(T.flame, 0.9); ctx.beginPath(); // sparks rising, more with the hi-hats
      for (let i = 0; i < 70; i++) {
        const cycle = time * (0.35 + 0.4 * hash01(i, 11)) + hash01(i, 12), whole = Math.floor(cycle), p = cycle - whole;
        if (!(hash01(i, whole) < 0.25 + 0.75 * audio.treble)) continue;
        const px = fx + unit * 0.04 * Math.sin(p * 6 + i) * p + unit * 0.02 * (hash01(i, 13) - 0.5), py = fy - unit * 0.08 - unit * 0.45 * p, r = unit * 0.0025 * (1 - p * 0.6);
        ctx.moveTo(px + r, py); ctx.arc(px, py, r, 0, Math.PI * 2);
      }
      ctx.fill(); ctx.restore();
    },
  };
}

// ---------------------------------------------------------------- Dune Moon
function makeDuneMoon() {
  const wind = new PhaseClock();
  const ridge = (x, layer, h, unit) => {
    const s = x / unit, base = h * (0.6 + 0.12 * layer);
    const shape = Math.sin(s * (1.1 + 0.3 * layer) + layer * 2.1) + 0.35 * Math.sin(s * 2.9 + layer);
    return base - unit * (0.06 + 0.02 * layer) * shape;
  };
  function caravan(ctx, w, h, unit, time, audio) {
    const beat = beatProgress(audio, time), travel = ((time * 0.008) % 1) * (w + unit * 0.8) - unit * 0.4;
    for (let camel = 0; camel < 4; camel++) {
      const x = travel - camel * unit * 0.1, gy = ridge(x, 0, h, unit), s = unit * 0.045;
      ctx.save(); ctx.translate(x, gy); ctx.scale(s, s);
      ctx.fillStyle = c(T.silhouette); ctx.beginPath(); // long body, one tall hump, long curved neck, small head
      ctx.moveTo(-1.1, -1.55); ctx.quadraticCurveTo(-1.05, -1.95, -0.55, -2.0); ctx.quadraticCurveTo(-0.1, -2.75, 0.35, -1.95);
      ctx.quadraticCurveTo(0.65, -1.8, 0.85, -1.75); ctx.quadraticCurveTo(1.05, -1.9, 1.25, -2.45); ctx.quadraticCurveTo(1.45, -2.62, 1.65, -2.4);
      ctx.lineTo(1.62, -2.22); ctx.quadraticCurveTo(1.5, -2.18, 1.35, -2.2); ctx.quadraticCurveTo(1.1, -1.6, 0.95, -1.35);
      ctx.quadraticCurveTo(-0.1, -1.05, -1.1, -1.55); ctx.closePath();
      ctx.moveTo(-1.05, -1.6); ctx.lineTo(-1.25, -1.15); ctx.lineTo(-1.15, -1.15); ctx.closePath(); // tail
      if (camel === 0) { addRR(ctx, -0.75, -2.85, 0.36, 0.95, 0.15); ctx.moveTo(-0.42, -3); ctx.ellipse(-0.57, -3, 0.15, 0.15, 0, 0, Math.PI * 2); } // robed rider
      ctx.fill();
      ctx.strokeStyle = c(T.silhouette); ctx.lineWidth = 0.16; ctx.lineCap = 'round'; ctx.beginPath();
      [-0.75, -0.5, 0.45, 0.7].forEach((lx, i) => { const swing = Math.sin(beat * Math.PI + (i % 2) * Math.PI + camel * 0.5) * 0.25; ctx.moveTo(lx, -1.4); ctx.lineTo(lx + swing, 0); });
      ctx.stroke(); ctx.restore();
    }
  }
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), gust = wind.advance(time, 0.3 + 1.2 * audio.mid);
      sky(ctx, w, h, h * 0.62);
      drawStars(ctx, w, h, h * 0.5, 160, time, audio.treble);

      const mx = w * 0.62, my = h * 0.46, mr = unit * 0.28; // a giant moon sitting low on the horizon
      glow(ctx, mx, my, mr * 2.2, T.moon, 0.18 + 0.08 * audio.level);
      ctx.fillStyle = rad(ctx, mx - mr * 0.3, my - mr * 0.3, 0, mr * 1.4, [c(T.moon), c(H(0xE8C9A0))]); circle(ctx, mx, my, mr); ctx.fill();
      ctx.fillStyle = c(H(0xCDB48E), 0.5); ctx.beginPath();
      for (const [dx, dy, r] of [[-0.3, -0.2, 0.22], [0.2, 0.15, 0.3], [0.35, -0.35, 0.12], [-0.15, 0.45, 0.14]]) {
        const x = mx + dx * mr, y = my + dy * mr; ctx.moveTo(x + mr * r, y); ctx.arc(x, y, mr * r, 0, Math.PI * 2);
      }
      ctx.fill();

      for (let layer = 0; layer < 3; layer++) { // dunes: moonlit crests, shadowed slopes
        const depth = layer / 2;
        ctx.beginPath(); ctx.moveTo(0, h);
        for (let x = 0; x <= w + 6; x += 6) ctx.lineTo(x, ridge(x, layer, h, unit));
        ctx.lineTo(w + 6, h); ctx.closePath();
        ctx.fillStyle = lin(ctx, 0, h * (0.55 + 0.12 * layer), 0, h, [c(mix(T.sandLit, T.sand, depth)), c(T.duneShadow)]); ctx.fill();
        ctx.strokeStyle = c(T.moon, 0.35 - 0.1 * depth); ctx.lineWidth = Math.max(1, unit * 0.002); ctx.lineCap = 'butt'; ctx.beginPath();
        for (let x = 0; x <= w + 6; x += 6) { const y = ridge(x, layer, h, unit); if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y); }
        ctx.stroke();
        ctx.fillStyle = c(T.moon, 0.45); ctx.beginPath(); // sand streaming off the crest in the wind
        for (let g = 0; g < 80; g++) {
          const start = hash01(g, layer + 10) * w, drift = (gust * 0.2 + hash01(g, layer + 20)) % 1;
          if (hash01(g, Math.trunc(gust * 2)) < 0.2 + 0.7 * audio.mid) {
            const px = start + unit * 0.12 * drift, py = ridge(start, layer, h, unit) - unit * 0.03 * Math.sin(Math.PI * drift), r = unit * 0.0015;
            ctx.moveTo(px + r, py); ctx.arc(px, py, r, 0, Math.PI * 2);
          }
        }
        ctx.fill();
        if (layer === 0) caravan(ctx, w, h, unit, time, audio);
      }
    },
  };
}

// ---------------------------------------------------------------- Shooting Stars
function makeShootingStars() {
  const CONSTELLATIONS = [
    [[0.08, 0.18], [0.13, 0.1], [0.2, 0.14], [0.24, 0.07], [0.3, 0.12], [0.27, 0.22]],
    [[0.42, 0.3], [0.47, 0.22], [0.53, 0.26], [0.5, 0.36], [0.42, 0.3]],
    [[0.66, 0.08], [0.71, 0.15], [0.78, 0.12], [0.84, 0.2], [0.9, 0.16]],
    [[0.72, 0.36], [0.78, 0.31], [0.83, 0.38], [0.79, 0.45], [0.86, 0.48]],
  ];
  const edge = new BeatEdge();
  let meteors = [], lastSpawn = 0, bandCache = null;
  const spawn = t => { lastSpawn = t; meteors.push({ x: 0.1 + Math.random() * 0.7, y: 0.02 + Math.random() * 0.33, angle: 0.35 + Math.random() * 0.35, born: t, life: 0.5 + Math.random() * 0.4 }); };
  const band = (b, w, h, unit) => { // the Milky Way: a soft diagonal band dense with tiny stars
    b.save(); b.translate(w / 2, h * 0.38); b.rotate(-0.42);
    withBlur(b, unit * 0.06, () => {
      b.fillStyle = c(H(0x8C7BC9), 0.28); ell(b, -w * 0.75, -unit * 0.09, w * 1.5, unit * 0.18); b.fill();
      b.fillStyle = c(H(0xE8D8F0), 0.18); ell(b, -w * 0.4, -unit * 0.04, w * 0.8, unit * 0.08); b.fill();
    });
    b.fillStyle = 'rgba(255,255,255,0.55)'; b.beginPath();
    for (let i = 0; i < 600; i++) { const x = (hash01(i, 1) - 0.5) * w * 1.4, y = (hash01(i, 2) + hash01(i, 3) - 1) * unit * 0.09, r = unit * 0.0011; b.moveTo(x + r * 2, y + r); b.ellipse(x + r, y + r, r, r, 0, 0, Math.PI * 2); }
    b.fill(); b.restore();
  };
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.78;
      if (edge.isNewBeat(audio) && hash01(audio.beatCount, 3) < 0.25 + 0.5 * audio.bass) spawn(time);
      else if (time - lastSpawn > 3.5) spawn(time);
      meteors = meteors.filter(m => time - m.born <= m.life);

      sky(ctx, w, h, horizon);
      if (typeof document !== 'undefined') { // the band is static, so render it once per size
        if (!bandCache || bandCache.w !== w || bandCache.h !== h) {
          const cv = document.createElement('canvas'); cv.width = Math.ceil(w); cv.height = Math.ceil(h);
          band(cv.getContext('2d'), w, h, unit); bandCache = { w, h, cv };
        }
        ctx.drawImage(bandCache.cv, 0, 0, w, h);
      } else band(ctx, w, h, unit);
      drawStars(ctx, w, h, horizon, 240, time, audio.treble);

      // Constellations draw themselves as their part of the spectrum swells.
      ctx.strokeStyle = c(H(0xBFD7FF), 0.45); ctx.lineWidth = Math.max(1, unit * 0.0015); ctx.lineCap = 'round'; ctx.beginPath();
      const anchors = [];
      CONSTELLATIONS.forEach((stars, index) => {
        const size = Math.max(Math.floor(audio.spectrum.length / CONSTELLATIONS.length), 1), start = Math.min(index * size, audio.spectrum.length - size);
        let energy = 0; for (let k = start; k < start + size; k++) energy += audio.spectrum[k]; energy /= size;
        const pts = stars.map(([x, y]) => [x * w, y * horizon]), segs = pts.length - 1, reveal = Math.min(1, energy * 1.4) * segs;
        for (let s = 0; s < segs; s++) {
          if (!(s < reveal)) continue;
          const amt = Math.min(1, reveal - s);
          ctx.moveTo(pts[s][0], pts[s][1]); ctx.lineTo(pts[s][0] + (pts[s + 1][0] - pts[s][0]) * amt, pts[s][1] + (pts[s + 1][1] - pts[s][1]) * amt);
        }
        pts.forEach(p => anchors.push(p));
      });
      ctx.stroke();
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = '#fff'; ctx.beginPath(); anchors.forEach(p => { ctx.moveTo(p[0] + unit * 0.004, p[1]); ctx.arc(p[0], p[1], unit * 0.004, 0, Math.PI * 2); }); ctx.fill();
      for (const m of meteors) { // shooting stars
        const age = (time - m.born) / m.life, sx = m.x * w, sy = m.y * horizon, dx = Math.cos(m.angle), dy = Math.sin(m.angle);
        const hx = sx + dx * unit * 0.6 * age, hy = sy + dy * unit * 0.6 * age, len = unit * 0.18 * (1 - age * 0.5), tx = hx - dx * len, ty = hy - dy * len, fade = Math.sin(Math.PI * age);
        ctx.strokeStyle = lin(ctx, tx, ty, hx, hy, ['rgba(255,255,255,0)', `rgba(255,255,255,${fade})`]); ctx.lineWidth = Math.max(1, unit * 0.003);
        ctx.beginPath(); ctx.moveTo(tx, ty); ctx.lineTo(hx, hy); ctx.stroke();
        glow(ctx, hx, hy, unit * 0.012, [255, 255, 255], 0.8 * fade);
      }
      ctx.restore();

      // Mesas and a lone cactus on the horizon.
      ctx.fillStyle = c(T.silhouette); ctx.beginPath(); ctx.moveTo(0, h); ctx.lineTo(0, horizon);
      let x = 0;
      for (const [start, width, height] of [[0.1, 0.22, 0.09], [0.55, 0.16, 0.06], [0.8, 0.12, 0.12]]) {
        ctx.lineTo(w * start, horizon); ctx.lineTo(w * start + unit * 0.03, horizon - unit * height);
        ctx.lineTo(w * (start + width) - unit * 0.03, horizon - unit * height); ctx.lineTo(w * (start + width), horizon); x = w * (start + width);
      }
      ctx.lineTo(Math.max(x, w), horizon); ctx.lineTo(w, h); ctx.closePath(); ctx.fill();
      ctx.beginPath(); addCactus(ctx, w * 0.42, horizon + unit * 0.01, unit * 0.16, 7); ctx.fill();
    },
  };
}

export const desert = {
  id: 'desert', name: 'Desert Night', accent: T.fire,
  wallpapers: [
    { id: 'desert.campfire', name: 'Campfire', summary: 'A crackling fire under the stars. Flames leap with the bass and sparks rise with the hi-hats.', make: makeCampfire },
    { id: 'desert.dune-moon', name: 'Dune Moon', summary: 'A camel caravan crosses moonlit dunes in step with the beat while sand streams off the crests.', make: makeDuneMoon },
    { id: 'desert.shooting-stars', name: 'Shooting Stars', summary: 'The Milky Way over desert mesas. Shooting stars fall on the beat and constellations draw themselves with the music.', make: makeShootingStars },
  ],
};

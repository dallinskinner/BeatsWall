// Neon Tokyo collection, ported from BeatsWall/Collections/Tokyo/*.swift. Film grain is omitted.
import { PhaseClock, BeatEdge, hash01, hex, rgba, mix, beatProgress } from '../kit.js';
import { lin, rad, rrect, circle, lines, neon, scratch, ell, withBlur } from './draw.js';

const T = {
  night: hex(0x0A0E1F), navy: hex(0x161C38), haze: hex(0x3A2850), building: hex(0x0F1326), asphalt: hex(0x0E1019),
  pink: hex(0xFF3D7F), cyan: hex(0x2DE2E6), amber: hex(0xFFB000), red: hex(0xFF2A2A), purple: hex(0xB06BFF),
  lantern: hex(0xE63946), warm: hex(0xFFD6A0),
};
const NEON = [T.pink, T.cyan, T.amber, T.purple, T.red];
const c = rgba, H = hex;
const R = (x, y, w, h) => ({ x, y, w, h });
const inset = (r, dx, dy) => R(r.x + dx, r.y + dy, r.w - 2 * dx, r.h - 2 * dy);

/** Kana-like neon glyphs: a few short strokes per cell, deterministic per seed. Adds to the current path. */
function addGlyphs(ctx, rect, count, vertical, seed) {
  const cell = vertical ? rect.h / count : rect.w / count;
  for (let i = 0; i < count; i++) {
    const ox = vertical ? rect.x : rect.x + i * cell, oy = vertical ? rect.y + i * cell : rect.y;
    const box = inset(R(ox, oy, vertical ? rect.w : cell, vertical ? cell : rect.h), cell * 0.2, cell * 0.2);
    const maxX = box.x + box.w, maxY = box.y + box.h, midX = box.x + box.w / 2, midY = box.y + box.h / 2;
    const strokes = 2 + Math.trunc(hash01(seed, i) * 3);
    for (let s = 0; s < strokes; s++) {
      const kind = Math.trunc(hash01(seed * 7 + i, s) * 4), a = hash01(seed * 13 + i, s), b = hash01(seed * 17 + i, s);
      if (kind === 0) { ctx.moveTo(box.x + box.w * a * 0.3, box.y + box.h * b); ctx.lineTo(maxX - box.w * b * 0.3, box.y + box.h * b); }
      else if (kind === 1) { ctx.moveTo(box.x + box.w * a, box.y + box.h * b * 0.3); ctx.lineTo(box.x + box.w * a, maxY); }
      else if (kind === 2) { ctx.moveTo(box.x + box.w * (0.3 + 0.4 * a), box.y); ctx.quadraticCurveTo(midX, midY + box.h * 0.2 * b, box.x, maxY); }
      else { ctx.moveTo(box.x + box.w * 0.2, box.y + box.h * a); ctx.lineTo(maxX, box.y + box.h * a); ctx.lineTo(maxX - box.w * 0.2, maxY); }
    }
  }
}

/** A neon sign: dark panel, glowing border and glyphs. */
function drawSign(ctx, rect, glyphCount, vertical, seed, color, brightness) {
  const unit = Math.min(rect.w, rect.h);
  ctx.fillStyle = 'rgba(7,8,15,0.9)'; rrect(ctx, rect.x, rect.y, rect.w, rect.h, unit * 0.08); ctx.fill();
  const b = inset(rect, unit * 0.06, unit * 0.06);
  neon(ctx, () => rrect(ctx, b.x, b.y, b.w, b.h, unit * 0.06), color, Math.max(1, unit * 0.025), brightness * 0.8);
  neon(ctx, () => { ctx.beginPath(); addGlyphs(ctx, inset(rect, unit * 0.1, unit * 0.1), glyphCount, vertical, seed); }, color, Math.max(1, unit * 0.045), brightness);
}

export function drawRain(ctx, w, h, time, density, slant = 0.12) {
  const unit = Math.min(w, h), count = Math.trunc(80 + 220 * density);
  ctx.strokeStyle = 'rgba(191,215,255,0.22)'; ctx.lineWidth = Math.max(1, unit * 0.0012); ctx.lineCap = 'butt'; ctx.beginPath();
  for (let i = 0; i < count; i++) {
    const speed = 1.4 + hash01(i, 91), fall = (hash01(i, 92) + time * speed * 0.7) % 1;
    const len = unit * (0.02 + 0.03 * hash01(i, 93));
    const x = hash01(i, 94) * (w + unit * 0.2) - unit * 0.1 + fall * h * slant, y = fall * (h + len) - len;
    ctx.moveTo(x, y); ctx.lineTo(x - len * slant, y - len);
  }
  ctx.stroke();
}

/** Distant skyline with dim windows. */
function drawSkyline(ctx, w, h, base, height, seed, color, windowColor, spectrum) {
  const unit = Math.min(w, h);
  ctx.fillStyle = color; ctx.beginPath();
  const wins = [];
  let x = -unit * 0.02, index = seed;
  while (x < w) {
    const bw = unit * (0.05 + 0.08 * hash01(index, 1)), tall = height * (0.35 + 0.65 * hash01(index, 2));
    ctx.rect(x, base - tall, bw, tall + unit);
    const bin = Math.min(Math.max(Math.trunc(x / w * 32), 0), 31), energy = spectrum ? spectrum[bin] : 0.3;
    let y = base - tall + unit * 0.012, row = 0;
    while (y < base - unit * 0.01) {
      for (let col = 0; col < 3; col++) if (hash01(index * 5 + col, row) < 0.15 + 0.55 * energy) wins.push([x + bw * (0.15 + 0.28 * col), y, bw * 0.14, unit * 0.007]);
      y += unit * 0.018; row++;
    }
    x += bw + unit * 0.003; index++;
  }
  ctx.fill();
  ctx.fillStyle = windowColor; ctx.beginPath(); wins.forEach(r => ctx.rect(r[0], r[1], r[2], r[3])); ctx.fill();
}

// ---------------------------------------------------------------- Rainy Crossing
function makeRainyCrossing() {
  const SIGNS = [[0.04, 0.12, 0.6, 4, 0], [0.13, 0.25, 0.45, 3, 1], [0.22, 0.08, 0.5, 4, 2], [0.74, 0.1, 0.55, 4, 3], [0.83, 0.3, 0.42, 3, 0], [0.92, 0.06, 0.62, 5, 1]];
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), street = h * 0.64;
      ctx.fillStyle = lin(ctx, 0, 0, 0, street, [c(T.night), c(T.navy), c(T.haze)]); ctx.fillRect(0, 0, w, h);
      drawSkyline(ctx, w, h, street, h * 0.45, 3, c(H(0x1A1F3D)), c(T.warm, 0.35), null);

      const signs = g => {
        g.fillStyle = c(T.building); g.fillRect(0, 0, w * 0.3, street); g.fillRect(w * 0.7, 0, w * 0.3, street);
        SIGNS.forEach(([sx, top, height, glyphs, col], i) => {
          let brightness = 0.3 + 0.7 * audio.spectrum[(i * 5 + 2) % 32];
          if (i % 3 === 1 && Math.sin(time * 23 + i) > 0.7) brightness *= 0.3; // a dodgy tube
          drawSign(g, R(w * sx, street * top, unit * 0.075, street * height), glyphs, true, i + 1, NEON[col], brightness);
        });
        drawSign(g, R(w * 0.38, street * 0.28, w * 0.24, unit * 0.08), 6, false, 42, T.cyan, 0.5 + 0.5 * audio.beatPulse);
      };
      signs(ctx);

      // Wet street with the signs mirrored in it.
      ctx.fillStyle = c(T.asphalt); ctx.fillRect(0, street, w, h - street);
      const layer = scratch('refl', Math.ceil(w), Math.ceil(h));
      if (layer) {
        signs(layer.ctx);
        ctx.save(); ctx.beginPath(); ctx.rect(0, street, w, h - street); ctx.clip();
        ctx.globalAlpha = 0.4; ctx.translate(0, street * 2); ctx.scale(1, -1);
        withBlur(ctx, unit * 0.012, () => ctx.drawImage(layer.canvas, 0, 0, w, h));
        ctx.restore();
      }
      ctx.fillStyle = c(T.asphalt, 0.85); ctx.beginPath(); // ripples breaking up the reflection
      for (let i = 0; i < 26; i++) {
        const y = street + (h - street) * hash01(i, 3), x = hash01(i, 4) * w + Math.sin(time * 0.8 + i) * unit * 0.02;
        ctx.rect(x, y, unit * (0.05 + 0.1 * hash01(i, 5)), Math.max(1, unit * 0.002));
      }
      ctx.fill();

      // Zebra crossing in perspective.
      ctx.fillStyle = c(H(0xD8DCE8), 0.28); ctx.beginPath();
      const near = h * 0.98;
      for (let i = 0; i < 9; i++) {
        const t0 = i / 9, t1 = t0 + 0.06, y0 = street + unit * 0.06;
        ctx.moveTo(w * (0.35 + 0.3 * t0), y0); ctx.lineTo(w * (0.35 + 0.3 * t1), y0);
        ctx.lineTo(w * (0.05 + 0.9 * t1), near); ctx.lineTo(w * (0.05 + 0.9 * t0), near); ctx.closePath();
      }
      ctx.fill();

      // Umbrella silhouettes crossing, stepping in tempo.
      const beat = beatProgress(audio, time), colors = [c(T.pink), c(H(0x2A2F4A)), c(T.cyan, 0.7), c(H(0x2A2F4A))];
      for (let i = 0; i < 4; i++) {
        const dir = i % 2 === 0 ? 1 : -1, span = w + unit * 0.4;
        const raw = hash01(i, 8) * span + dir * time * unit * 0.035, travel = raw - Math.floor(raw / span) * span - unit * 0.2;
        const x = dir > 0 ? travel : w - travel, ground = street + unit * (0.16 + 0.14 * hash01(i, 9)), s = unit * (0.12 + 0.08 * hash01(i, 9));
        const bob = Math.abs(Math.sin(Math.PI * beat)) * s * 0.04, stride = Math.sin(Math.PI * beat) * s * 0.12;
        ctx.fillStyle = c(H(0x05060C));
        rrect(ctx, x - s * 0.12, ground - s * 0.85 - bob, s * 0.24, s * 0.55, s * 0.08); ctx.fill();
        ctx.fillRect(x - s * 0.08 + stride, ground - s * 0.32, s * 0.07, s * 0.32);
        ctx.fillRect(x + s * 0.02 - stride, ground - s * 0.32, s * 0.07, s * 0.32);
        ctx.fillStyle = colors[i]; ctx.beginPath(); ctx.moveTo(x - s * 0.42, ground - s * 0.95 - bob);
        ctx.quadraticCurveTo(x, ground - s * 1.45 - bob, x + s * 0.42, ground - s * 0.95 - bob); ctx.closePath(); ctx.fill();
      }
      drawRain(ctx, w, h, time, 0.4 + 0.6 * audio.level);
    },
  };
}

// ---------------------------------------------------------------- Midnight Train
function makeMidnightTrain() {
  const edge = new BeatEdge();
  let departure = null;
  const CROSSING = 5;
  const progress = t => { if (departure === null) return null; const p = (t - departure) / CROSSING; return p >= 0 && p <= 1 ? p : null; };
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), track = h * 0.56, street = h * 0.82;
      // Trains roll through on the downbeat of every 16 beats, or every 15 seconds when it's quiet.
      const busy = progress(time) !== null;
      if (edge.isNewBeat(audio) && audio.beatCount % 16 === 0 && !busy) departure = time;
      else if (!busy && time - (departure === null ? -100 : departure) > 15) departure = time;

      ctx.fillStyle = lin(ctx, 0, 0, 0, street, [c(T.night), c(H(0x24204A)), c(H(0x6A3D6E))]); ctx.fillRect(0, 0, w, h);
      ctx.fillStyle = lin(ctx, 0, h * 0.3, 0, h * 0.7, [c(T.pink, 0), c(T.pink, 0.12 + 0.1 * audio.bass), c(T.pink, 0)]);
      ctx.fillRect(0, h * 0.3, w, h * 0.4);
      drawSkyline(ctx, w, h, street, h * 0.55, 20, c(H(0x1B1D3A)), c(T.warm, 0.4), null);
      drawSkyline(ctx, w, h, street, h * 0.38, 60, c(T.building), c(T.cyan, 0.75), audio.spectrum);

      // Elevated track and pillars; overhead wire poles.
      const deckH = unit * 0.035, deckBottom = track + deckH;
      const structure = () => {
        ctx.beginPath(); ctx.rect(0, track, w, deckH);
        for (let x = unit * 0.1; x < w; x += unit * 0.42) {
          ctx.rect(x, deckBottom, unit * 0.03, street - deckBottom);
          ctx.moveTo(x - unit * 0.05, deckBottom); ctx.lineTo(x + unit * 0.08, deckBottom); ctx.lineTo(x + unit * 0.015, deckBottom + unit * 0.05); ctx.closePath();
        }
      };
      const poles = () => {
        ctx.beginPath();
        for (let x = unit * 0.25; x < w; x += unit * 0.42) ctx.rect(x, track - unit * 0.12, unit * 0.006, unit * 0.12);
        ctx.rect(0, track - unit * 0.1, w, Math.max(1, unit * 0.0015));
      };

      const p = progress(time);
      if (p !== null) {
        const carLen = unit * 0.32, cars = 6, trainLen = carLen * cars, head = -trainLen + p * (w + trainLen * 1.1), th = unit * 0.07, top = track - th;
        ctx.fillStyle = c(H(0xC9CED8));
        const wins = [];
        for (let car = 0; car < cars; car++) {
          const left = head + car * carLen;
          rrect(ctx, left + unit * 0.004, top, carLen - unit * 0.008, th, unit * 0.008); ctx.fill();
          for (let wx = left + unit * 0.02; wx < left + carLen - unit * 0.03; wx += unit * 0.04) wins.push([wx, top + th * 0.2, unit * 0.03, th * 0.35]);
        }
        ctx.fillStyle = c(T.cyan, 0.9); ctx.fillRect(head, top + th * 0.68, trainLen, th * 0.1);
        const addWins = () => { ctx.beginPath(); wins.forEach(r => ctx.rect(r[0], r[1], r[2], r[3])); };
        ctx.fillStyle = c(T.warm, 0.75 + 0.25 * audio.treble); addWins(); ctx.fill();
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        ctx.fillStyle = c(T.warm, 0.35);
        withBlur(ctx, unit * 0.01, () => { addWins(); ctx.fill(); ell(ctx, head + trainLen - unit * 0.01, top + th * 0.6 - unit * 0.01, unit * 0.02, unit * 0.02); ctx.fillStyle = '#fff'; ctx.fill(); });
        ctx.restore();
      }
      ctx.fillStyle = c(H(0x080A16)); structure(); ctx.fill(); poles(); ctx.fill();

      // Street level: shopfronts and passing car lights.
      ctx.fillStyle = c(T.asphalt); ctx.fillRect(0, street, w, h - street);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 12; i++) {
        ctx.fillStyle = c(NEON[i % 5], 0.2 + 0.4 * audio.spectrum[(i * 3) % 32]);
        ctx.fillRect(w * i / 12 + unit * 0.01, street - unit * 0.05, w / 12 - unit * 0.02, unit * 0.04);
      }
      ctx.fillStyle = c(H(0xFFE6B0), 0.6);
      for (let i = 0; i < 10; i++) {
        const speed = (0.15 + 0.2 * hash01(i, 2)) * (i % 2 === 0 ? 1 : -1);
        const raw = (hash01(i, 1) + time * speed) % 1;
        rrect(ctx, (raw < 0 ? raw + 1 : raw) * (w + unit * 0.2) - unit * 0.1, street + unit * (i % 2 === 0 ? 0.05 : 0.09), unit * 0.06, unit * 0.006, unit * 0.003); ctx.fill();
      }
      ctx.restore();
      drawRain(ctx, w, h, time, 0.3 + 0.4 * audio.level);
    },
  };
}

// ---------------------------------------------------------------- Ramen Alley
function makeRamenAlley() {
  const sway = new PhaseClock();
  const DARK = c(H(0x05060C));
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), phase = sway.advance(time, 0.8 + 1.5 * audio.mid);
      const floor = h * 0.8, vx = w / 2, vy = h * 0.46, farHalf = unit * 0.12;

      ctx.fillStyle = c(H(0x0B0D18)); ctx.fillRect(0, 0, w, h);
      const openB = vy + unit * 0.05;
      ctx.fillStyle = lin(ctx, 0, 0, 0, openB, [c(T.night), c(T.haze)]); ctx.fillRect(vx - farHalf, 0, farHalf * 2, openB);

      for (const side of [-1, 1]) {
        const farX = vx + side * farHalf, nearX = side < 0 ? 0 : w;
        ctx.fillStyle = lin(ctx, farX, 0, nearX, 0, [c(H(0x1A1A2E)), c(H(0x0C0D18))]);
        lines(ctx, [[farX, 0], [nearX, 0], [nearX, h], [farX, openB]], true); ctx.fill();
        ctx.fillStyle = c(H(0x23253A)); ctx.beginPath();
        for (let i = 0; i < 4; i++) {
          const t = 0.25 + 0.17 * i, x = farX + (nearX - farX) * t, y = h * (0.15 + 0.12 * hash01(i, side < 0 ? 1 : 2)), s = unit * 0.06 * (0.4 + t);
          ctx.rect(x - s / 2, y, s, s * 0.7);
        }
        ctx.rect(farX + (nearX - farX) * 0.55, 0, unit * 0.012, h); ctx.fill();
      }
      drawSign(ctx, R(w * 0.08, h * 0.12, unit * 0.09, unit * 0.32), 4, true, 5, T.pink, 0.4 + 0.6 * audio.spectrum[6]);
      drawSign(ctx, R(w * 0.86, h * 0.2, unit * 0.08, unit * 0.26), 3, true, 9, T.cyan, 0.4 + 0.6 * audio.spectrum[18]);

      // Wet ground.
      ctx.fillStyle = lin(ctx, 0, openB, 0, h, [c(H(0x1A1626)), c(H(0x0A0B12))]);
      lines(ctx, [[vx - farHalf, openB], [vx + farHalf, openB], [w, h], [0, h]], true); ctx.fill();

      stall(ctx, w, unit, floor, phase, audio);
      lanterns(ctx, w, h, unit, phase, audio);
      vending(ctx, R(w * 0.78, floor - unit * 0.34, unit * 0.17, unit * 0.34), unit);
      cat(ctx, w * 0.17, floor + unit * 0.04, unit, audio);
      drawRain(ctx, w, h, time, 0.15 + 0.3 * audio.level, 0.05);
    },
  };

  function stall(ctx, w, unit, floor, phase, audio) {
    const width = unit * 0.5, left = w / 2 - width / 2, roof = floor - unit * 0.38, warmth = 0.55 + 0.35 * audio.level;
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    ctx.fillStyle = rad(ctx, w / 2, floor - unit * 0.18, 0, unit * 0.4, [c(T.warm, 0.35 * warmth), c(T.warm, 0)]);
    ell(ctx, left - unit * 0.2, roof - unit * 0.05, width + unit * 0.4, unit * 0.65); ctx.fill(); ctx.restore();
    ctx.fillStyle = c(H(0xF2B66D), 0.75 * warmth + 0.2); ctx.fillRect(left, roof + unit * 0.06, width, unit * 0.2);
    ctx.fillStyle = c(H(0x6B3E22)); ctx.fillRect(left - unit * 0.02, floor - unit * 0.12, width + unit * 0.04, unit * 0.03);
    ctx.fillStyle = c(H(0x4A2A17)); ctx.fillRect(left, floor - unit * 0.09, width, unit * 0.09);
    ctx.fillStyle = c(H(0x2A1A14)); ctx.fillRect(left - unit * 0.03, roof, width + unit * 0.06, unit * 0.06);

    // Noren curtain swaying with the melody.
    const strips = 5, sw = width / strips;
    ctx.fillStyle = c(T.lantern);
    for (let i = 0; i < strips; i++) {
      const swing = Math.sin(phase * 1.3 + i * 0.8) * unit * 0.012 * (0.4 + audio.mid), x = left + i * sw;
      lines(ctx, [[x + unit * 0.003, roof + unit * 0.06], [x + sw - unit * 0.003, roof + unit * 0.06], [x + sw - unit * 0.003 + swing, roof + unit * 0.16], [x + unit * 0.003 + swing, roof + unit * 0.16]], true); ctx.fill();
    }
    ctx.strokeStyle = 'rgba(255,255,255,0.85)'; ctx.lineWidth = unit * 0.006;
    ell(ctx, w / 2 - unit * 0.025, roof + unit * 0.085, unit * 0.05, unit * 0.05); ctx.stroke();

    // Bowls with steam.
    for (let i = 0; i < 3; i++) {
      const bx = left + width * (0.25 + 0.25 * i), by = floor - unit * 0.12;
      ctx.fillStyle = c(H(0xEDE6DA)); ell(ctx, bx - unit * 0.025, by - unit * 0.02, unit * 0.05, unit * 0.025); ctx.fill();
      ctx.beginPath(); ctx.moveTo(bx, by - unit * 0.02);
      for (let s = 1; s <= 14; s++) { const t = s / 14; ctx.lineTo(bx + unit * 0.01 * Math.sin(phase * 2 + t * 6 + i) * t, by - unit * 0.02 - unit * 0.1 * t); }
      ctx.strokeStyle = lin(ctx, 0, by, 0, by - unit * 0.12, ['rgba(255,255,255,0.4)', 'rgba(255,255,255,0)']);
      ctx.lineWidth = unit * 0.006; ctx.lineCap = 'round'; ctx.stroke();
    }
  }

  function lanterns(ctx, w, h, unit, phase, audio) {
    const wireY = h * 0.08;
    ctx.strokeStyle = DARK; ctx.lineWidth = Math.max(1, unit * 0.003); ctx.lineCap = 'butt';
    ctx.beginPath(); ctx.moveTo(0, wireY); ctx.quadraticCurveTo(w / 2, wireY + unit * 0.08, w, wireY); ctx.stroke();
    for (let i = 0; i < 5; i++) {
      const t = 0.15 + 0.175 * i, hx = w * t, hy = wireY + unit * 0.08 * 2 * t * (1 - t) * 2;
      const angle = Math.sin(phase + i * 1.1) * 0.12 * (0.4 + audio.mid), len = unit * 0.05;
      const cx = hx + Math.sin(angle) * len, cy = hy + Math.cos(angle) * len, rx = unit * 0.035, ry = unit * 0.045, light = 0.5 + 0.5 * audio.bass;
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = rad(ctx, cx, cy, 0, ry * 3, [c(T.lantern, 0.35 * light), c(T.lantern, 0)]); ell(ctx, cx - rx * 3, cy - ry * 3, rx * 6, ry * 6); ctx.fill(); ctx.restore();
      ctx.strokeStyle = DARK; ctx.lineWidth = Math.max(1, unit * 0.002); ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(cx, cy); ctx.stroke();
      ctx.fillStyle = rad(ctx, cx, cy, 0, ry, [c(mix(H(0xFF8A65), [255, 255, 255], 0.3 * light)), c(T.lantern)]); ell(ctx, cx - rx, cy - ry, rx * 2, ry * 2); ctx.fill();
      ctx.strokeStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath();
      for (const rib of [-0.5, 0, 0.5]) { const half = rx * Math.sqrt(1 - rib * rib); ctx.moveTo(cx - half, cy + ry * rib); ctx.lineTo(cx + half, cy + ry * rib); }
      ctx.stroke();
      ctx.fillStyle = c(H(0x1A1A1A)); ctx.fillRect(cx - rx * 0.5, cy - ry - unit * 0.006, rx, unit * 0.008); ctx.fillRect(cx - rx * 0.5, cy + ry - unit * 0.002, rx, unit * 0.008);
    }
  }

  function vending(ctx, r, unit) {
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    ctx.fillStyle = rad(ctx, r.x + r.w / 2, r.y + r.h / 2, 0, unit * 0.25, [c(H(0xBFE8FF), 0.25), c(H(0xBFE8FF), 0)]);
    ell(ctx, r.x + r.w / 2 - unit * 0.25, r.y + r.h / 2 - unit * 0.25, unit * 0.5, unit * 0.5); ctx.fill(); ctx.restore();
    ctx.fillStyle = c(H(0xE8EEF5)); rrect(ctx, r.x, r.y, r.w, r.h, unit * 0.008); ctx.fill();
    const win = R(r.x + unit * 0.012, r.y + unit * 0.02 - unit * 0.04, r.w - unit * 0.024, r.h - unit * 0.04);
    ctx.fillStyle = c(H(0xF6FBFF)); ctx.fillRect(win.x, win.y, win.w, win.h * 0.62);
    const cols = [T.red, T.cyan, T.amber, H(0x6BCB77), T.purple];
    for (let row = 0; row < 3; row++) for (let col = 0; col < 5; col++) {
      ctx.fillStyle = c(cols[(row + col) % 5]);
      rrect(ctx, win.x + win.w * (0.06 + 0.19 * col), win.y + win.h * (0.05 + 0.2 * row), win.w * 0.12, win.h * 0.15, unit * 0.003); ctx.fill();
    }
    ctx.fillStyle = c(H(0x2A2F3A)); ctx.fillRect(r.x + unit * 0.03, r.y + r.h - unit * 0.06, r.w - unit * 0.06, unit * 0.03);
  }

  function cat(ctx, bx, by, unit, audio) {
    ctx.fillStyle = c(H(0x2A2234)); ctx.fillRect(bx - unit * 0.07, by - unit * 0.08, unit * 0.14, unit * 0.08); ctx.fillRect(bx - unit * 0.07, by - unit * 0.045, unit * 0.14, unit * 0.006);
    const sx = bx, sy = by - unit * 0.08, flick = audio.beatPulse;
    ctx.strokeStyle = DARK; ctx.lineWidth = unit * 0.01; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(sx + unit * 0.03, sy - unit * 0.01);
    ctx.quadraticCurveTo(sx + unit * 0.08, sy, sx + unit * (0.08 + 0.02 * flick), sy - unit * (0.03 + 0.06 * flick)); ctx.stroke();
    ctx.fillStyle = DARK; ell(ctx, sx - unit * 0.035, sy - unit * 0.08, unit * 0.07, unit * 0.08); ctx.fill();
    const hx = sx - unit * 0.005, hy = sy - unit * 0.095;
    ell(ctx, hx - unit * 0.025, hy - unit * 0.022, unit * 0.05, unit * 0.044);
    for (const side of [-1, 1]) {
      ctx.moveTo(hx + side * unit * 0.022, hy - unit * 0.008); ctx.lineTo(hx + side * unit * 0.02, hy - unit * 0.04); ctx.lineTo(hx + side * unit * 0.005, hy - unit * 0.02); ctx.closePath();
    }
    ctx.fill();
    ctx.fillStyle = c(H(0xC6FF6B));
    for (const side of [-1, 1]) { ell(ctx, hx + side * unit * 0.01 - unit * 0.004, hy - unit * 0.004, unit * 0.008, unit * 0.006); ctx.fill(); }
  }
}

export const tokyo = {
  id: 'tokyo', name: 'Neon Tokyo', accent: T.pink,
  wallpapers: [
    { id: 'tokyo.rainy-crossing', name: 'Rainy Crossing', summary: 'Neon signs flicker with the spectrum above a wet crossing, mirrored in the puddles as umbrellas step in time.', make: makeRainyCrossing },
    { id: 'tokyo.midnight-train', name: 'Midnight Train', summary: "An elevated train glides past on the downbeat while the skyline's windows light up like an equalizer.", make: makeMidnightTrain },
    { id: 'tokyo.ramen-alley', name: 'Ramen Alley', summary: 'A glowing ramen stall in a narrow alley, with lanterns swaying to the melody and a cat flicking its tail on the beat.', make: makeRamenAlley },
  ],
};

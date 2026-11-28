// Winter Holidays collection, ported from BeatsWall/Collections/Winter/*.swift. Film grain is omitted.
import { hex, rgba, mix, hash01, PhaseClock, BeatEdge } from '../kit.js';
import { lin, rad, rrect, circle, lines, dot, ell, glow, scratch, withBlur } from './draw.js';

const T = { night: hex(0x0E1A33), deep: hex(0x1B2D52), dusk: hex(0x3A4E7A), snow: hex(0xEEF4FF), snowShade: hex(0xB9C9E6), pine: hex(0x1F4A3A), pineDark: hex(0x143326), wood: hex(0x6B3E22), woodDark: hex(0x4A2A17), warm: hex(0xFFC46B), red: hex(0xE63946), green: hex(0x2A9D8F), gold: hex(0xFFD166), blue: hex(0x4EA8DE), white: [255, 255, 255], black: [0, 0, 0] };
const BULBS = [T.red, T.gold, T.green, T.blue, hex(0xFF8FAB)];
const box = (ctx, color, x, y, w, h) => { ctx.fillStyle = color; ctx.fillRect(x, y, w, h); };
const poly = (ctx, pts, color) => { lines(ctx, pts, true); ctx.fillStyle = color; ctx.fill(); };
const addDot = (ctx, x, y, r) => { ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, Math.PI * 2); };
const lit = (ctx, fn) => { ctx.save(); ctx.globalCompositeOperation = 'lighter'; fn(); ctx.restore(); };

function snowfall(ctx, w, h, time, density, max) {
  const unit = Math.min(w, h), near = new Path2D(), far = new Path2D();
  for (let i = 0; i < Math.floor(max * (0.3 + 0.7 * density)); i++) {
    const d = hash01(i, 71), fall = (hash01(i, 72) + time * (0.04 + 0.08 * d)) % 1;
    const x = hash01(i, 73) * w + unit * 0.02 * Math.sin(time * (0.5 + d) + i), y = fall * (h + unit * 0.02) - unit * 0.01, r = unit * (0.0015 + 0.003 * d);
    addDot(d > 0.6 ? near : far, x, y, r);
  }
  ctx.fillStyle = rgba(T.snow, 0.55); ctx.fill(far); ctx.fillStyle = rgba(T.snow, 0.9); ctx.fill(near);
}
function pine(ctx, x, y, height, tiers, treeColor, snowColor) {
  const width = height * 0.55;
  box(ctx, treeColor, x - width * 0.06, y - height * 0.12, width * 0.12, height * 0.12);
  for (let tier = 0; tier < tiers; tier++) {
    const t = tier / tiers, bottom = y - height * 0.1 - height * 0.8 * t * 0.85, top = bottom - height * 0.42, half = width / 2 * (1 - t * 0.7), dy = bottom - top;
    poly(ctx, [[x - half, bottom], [x, top], [x + half, bottom]], treeColor);
    poly(ctx, [[x - half * 0.35, top + dy * 0.35], [x, top], [x + half * 0.35, top + dy * 0.35], [x + half * 0.15, top + dy * 0.3], [x - half * 0.1, top + dy * 0.38]], snowColor);
  }
}

// ---------------------------------------------------------------- Snowy Cabin
function cabin(ctx, w, unit, ground, drift, audio) {
  const width = unit * 0.42, wall = unit * 0.18, left = w * 0.42 - width / 2, top = ground - wall, warmth = 0.45 + 0.55 * audio.level;
  lit(ctx, () => glow(ctx, left + width / 2, ground, unit * 0.35, T.warm, 0.25 * warmth));
  const chx = left + width * 0.7, chy = top - unit * 0.17;
  box(ctx, '#5A4A48', chx, chy, unit * 0.045, unit * 0.12);
  for (let p = 0; p < 6; p++) { const t = (drift * 0.15 + p / 6) % 1; dot(ctx, chx + unit * 0.0225 + unit * 0.05 * Math.sin(t * 5 + drift * 0.3) + unit * 0.08 * t, chy - unit * 0.25 * t, unit * (0.012 + 0.03 * t), rgba(T.snowShade, 0.35 * (1 - t))); }
  box(ctx, rgba(T.wood), left, top, width, wall);
  for (let y = top + unit * 0.02; y < ground; y += unit * 0.025) box(ctx, rgba(T.woodDark), left, y, width, Math.max(1, unit * 0.003));
  for (const k of [0.14, 0.66]) {
    const x = left + width * k, y = top + wall * 0.25, ww = width * 0.2, wh = wall * 0.38;
    box(ctx, rgba(mix(T.warm, T.black, 0.5 - 0.45 * warmth)), x, y, ww, wh);
    lit(ctx, () => glow(ctx, x + ww / 2, y + wh / 2, ww, T.warm, 0.3 * warmth));
    box(ctx, rgba(T.woodDark), x + ww / 2 - unit * 0.002, y, unit * 0.004, wh); box(ctx, rgba(T.woodDark), x, y + wh / 2 - unit * 0.002, ww, unit * 0.004);
    rrect(ctx, x - unit * 0.004, y + wh - unit * 0.004, ww + unit * 0.008, unit * 0.012, unit * 0.006); ctx.fillStyle = rgba(T.snow); ctx.fill();
  }
  const dx = left + width * 0.42, dy = top + wall * 0.3, dw = width * 0.16, dh = wall * 0.7;
  box(ctx, rgba(T.woodDark), dx, dy, dw, dh);
  ctx.strokeStyle = rgba(T.pine); ctx.lineWidth = unit * 0.007; circle(ctx, dx + dw / 2, dy + dh * 0.3, unit * 0.014); ctx.stroke();
  dot(ctx, dx + dw / 2, dy + dh * 0.3 + unit * 0.014, unit * 0.004, rgba(T.red));
  const eave = unit * 0.035, px = left + width / 2, py = top - unit * 0.15;
  poly(ctx, [[left - eave, top + unit * 0.01], [px, py], [left + width + eave, top + unit * 0.01]], '#3A2A28');
  ctx.beginPath(); ctx.moveTo(left - eave * 1.4, top + unit * 0.005); ctx.lineTo(px, py - unit * 0.02); ctx.lineTo(left + width + eave * 1.4, top + unit * 0.005);
  for (let s = 10; s >= 0; s--) { const x = left - eave * 1.4 + (width + eave * 2.8) * s / 10; ctx.quadraticCurveTo(x + unit * 0.015, top + unit * 0.03, x, top + unit * 0.012); }
  ctx.closePath(); ctx.fillStyle = rgba(T.snow); ctx.fill();
  const bulbs = Array.from({ length: 18 }, (_, i) => { const t = i / 17; return [left - eave + (width + eave * 2) * t, top + unit * 0.03 + unit * 0.012 * Math.sin(Math.PI * ((t * 17) % 1))]; });
  lines(ctx, bulbs); ctx.strokeStyle = '#1A2A1F'; ctx.lineWidth = Math.max(1, unit * 0.002); ctx.stroke();
  const beat = audio.beatCount, mode = Math.floor(beat / 4) % 4;
  bulbs.forEach(([x, y], i) => {
    const on = mode === 0 || (mode === 1 ? (i + beat) % 2 === 0 : mode === 2 ? (i + beat) % 3 === 0 : hash01(i, beat) > 0.4), b = on ? 0.6 + 0.4 * audio.bass : 0.12, c = BULBS[i % 5];
    lit(ctx, () => glow(ctx, x, y, unit * 0.025, c, 0.6 * b));
    ell(ctx, x - unit * 0.004, y - unit * 0.002, unit * 0.008, unit * 0.012); ctx.fillStyle = rgba(mix(c, T.white, 0.35 * b), 0.35 + 0.65 * b); ctx.fill();
  });
}
function makeCabin() {
  const smoke = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), ground = h * 0.74, drift = smoke.advance(time, 0.5 + audio.mid);
      box(ctx, lin(ctx, 0, 0, 0, ground, [rgba(T.night), rgba(T.deep), rgba(T.dusk)]), 0, 0, w, h);
      ctx.fillStyle = 'rgba(255,255,255,0.7)'; ctx.beginPath(); for (let i = 0; i < 70; i++) addDot(ctx, hash01(i, 1) * w, hash01(i, 2) * ground * 0.5, unit * 0.0015 * (0.6 + hash01(i, 3))); ctx.fill();
      glow(ctx, w * 0.82, h * 0.16, unit * 0.2, T.snow, 0.18); dot(ctx, w * 0.82, h * 0.16, unit * 0.045, rgba(T.snow));
      [[ground - unit * 0.08, 0.05, rgba(T.snowShade, 0.55)], [ground, 0.03, rgba(T.snowShade)]].forEach(([base, amp, c], layer) => {
        ctx.beginPath(); ctx.moveTo(0, h); for (let x = 0; x <= w + 6; x += 6) ctx.lineTo(x, base - unit * amp * (1 + Math.sin(x / unit * 2.1 + layer * 2))); ctx.lineTo(w + 6, h); ctx.closePath(); ctx.fillStyle = c; ctx.fill();
      });
      for (const [x, ht, lift] of [[0.08, 0.36, 0], [0.18, 0.26, 0.02], [0.72, 0.3, 0.01], [0.86, 0.42, 0], [0.95, 0.28, 0.02], [0.6, 0.18, -0.02]]) pine(ctx, w * x, ground - unit * lift, unit * ht, 4, rgba(T.pineDark), rgba(T.snow, 0.9));
      cabin(ctx, w, unit, ground, drift, audio);
      ctx.beginPath(); ctx.moveTo(0, h); for (let x = 0; x <= w + 6; x += 6) ctx.lineTo(x, h * 0.9 - unit * 0.02 * Math.sin(x / unit * 3)); ctx.lineTo(w + 6, h); ctx.closePath(); ctx.fillStyle = rgba(T.snow); ctx.fill();
      snowfall(ctx, w, h, time, audio.level, 400);
    },
  };
}

// ---------------------------------------------------------------- Snow Globe
function makeGlobe() {
  const flakes = Array.from({ length: 220 }, () => { const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * 0.85; return { x: Math.cos(a) * r, y: Math.sin(a) * r, vx: 0, vy: 0, size: 0.5 + 0.9 * Math.random() }; });
  const clock = new PhaseClock(), edge = new BeatEdge();
  let shake = 0;
  return {
    draw(ctx, w, h, { time, audio }) {
      clock.advance(time);
      const dt = clock.deltaTime;
      if (edge.isNewBeat(audio) && audio.bass > 0.5) {
        shake = Math.min(1.5, shake + audio.bass);
        for (const f of flakes) { f.vx += (Math.random() * 1.2 - 0.6) * audio.bass; f.vy -= (0.2 + 0.8 * Math.random()) * audio.bass; }
      }
      shake *= Math.exp(-dt * 2.5);
      for (const f of flakes) {
        const swirl = shake * 0.8;
        f.vx += (-f.y * swirl - f.vx * 1.5) * dt; f.vy += (f.x * swirl + 0.06 - f.vy * 1.5) * dt;
        f.x += f.vx * dt + Math.sin(time + f.size * 10) * 0.01 * dt; f.y += f.vy * dt;
        const d = Math.hypot(f.x, f.y);
        if (d > 0.95) { f.x *= 0.95 / d; f.y *= 0.95 / d; f.vx *= -0.3; f.vy *= -0.3; }
        if (f.y > 0.42) { f.y = 0.42; f.vy = 0; f.vx *= 0.5; }
      }
      const unit = Math.min(w, h), cx = w / 2 + Math.sin(time * 45) * unit * 0.004 * shake, cy = h * 0.44, R = unit * 0.33;
      box(ctx, lin(ctx, 0, 0, 0, h, ['#2B1D2E', '#120C18']), 0, 0, w, h);
      const k = 0.35, buf = scratch('winter.bokeh', Math.ceil(w * k), Math.ceil(h * k)), g = buf ? buf.ctx : ctx;
      g.save(); if (buf) g.scale(k, k); g.globalCompositeOperation = 'lighter';
      withBlur(g, unit * 0.02 * k, () => { for (let i = 0; i < 24; i++) dot(g, hash01(i, 1) * w, hash01(i, 2) * h * 0.7, unit * (0.02 + 0.04 * hash01(i, 3)), rgba(BULBS[i % 5], 0.15 + 0.35 * audio.spectrum[(i * 3) % 32])); });
      g.restore(); if (buf) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.drawImage(buf.canvas, 0, 0, w, h); ctx.restore(); }
      poly(ctx, [[cx - R * 0.78, cy + R * 0.82], [cx + R * 0.78, cy + R * 0.82], [cx + R * 0.95, cy + R * 1.3], [cx - R * 0.95, cy + R * 1.3]], lin(ctx, cx - R, 0, cx + R, 0, ['#7A4A2A', '#3E2414']));
      box(ctx, rgba(T.gold, 0.85), cx - R * 0.86, cy + R, R * 1.72, R * 0.07);
      ctx.save(); circle(ctx, cx, cy, R); ctx.clip();
      box(ctx, lin(ctx, 0, cy - R, 0, cy + R, [rgba(T.night), rgba(T.dusk)]), cx - R, cy - R, R * 2, R * 2);
      const floor = cy + R * 0.45;
      ctx.beginPath(); ctx.moveTo(cx - R, cy + R); ctx.lineTo(cx - R, floor + R * 0.1); ctx.quadraticCurveTo(cx, floor - R * 0.2, cx + R, floor + R * 0.1); ctx.lineTo(cx + R, cy + R); ctx.closePath(); ctx.fillStyle = rgba(T.snow); ctx.fill();
      [[-0.45, 0.22, T.red], [-0.05, 0.28, hex(0x4A6FA5)], [0.38, 0.2, T.green]].forEach(([dx, s, c], i) => {
        const bw = R * s, bh = R * s * 0.7, base = floor + R * 0.02 - R * 0.06 * (1 - Math.abs(dx) * 1.2), x = cx + R * dx - bw / 2, y = base - bh;
        box(ctx, rgba(c), x, y, bw, bh);
        poly(ctx, [[x - bw * 0.1, y], [x + bw / 2, y - bh * 0.7], [x + bw * 1.1, y]], rgba(T.snow));
        box(ctx, rgba(T.warm, 0.5 + 0.5 * (0.5 + 0.5 * audio.spectrum[(i * 7 + 4) % 32])), x + bw * 0.38, y + bh * 0.3, bw * 0.24, bh * 0.3);
      });
      for (const dx of [-0.75, 0.68, 0.18]) pine(ctx, cx + R * dx, floor + R * 0.06, R * 0.42, 3, rgba(T.pine), rgba(T.snow));
      ctx.fillStyle = 'rgba(255,255,255,0.92)'; ctx.beginPath(); for (const f of flakes) addDot(ctx, cx + f.x * R, cy + f.y * R, R * 0.012 * f.size); ctx.fill();
      ctx.restore();
      ctx.strokeStyle = 'rgba(255,255,255,0.25)'; ctx.lineWidth = Math.max(1, unit * 0.004); circle(ctx, cx, cy, R); ctx.stroke();
      ctx.beginPath(); ctx.arc(cx, cy, R * 0.86, 200 * Math.PI / 180, 255 * Math.PI / 180); ctx.strokeStyle = 'rgba(255,255,255,0.35)'; ctx.lineWidth = R * 0.05; ctx.lineCap = 'round'; ctx.stroke();
      dot(ctx, cx + R * 0.45, cy - R * 0.5, R * 0.05, 'rgba(255,255,255,0.3)');
    },
  };
}

// ---------------------------------------------------------------- Twinkling Tree
function makeTree() {
  const ORN = [T.red, T.gold, T.blue, hex(0xD8DEE9), hex(0xFF8FAB)];
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), floor = h * 0.84, bx = w * 0.5, by = floor - unit * 0.04, th = unit * 0.68, tw = th * 0.62, top = by - th;
      box(ctx, lin(ctx, 0, 0, 0, floor, ['#3B2533', '#24161F']), 0, 0, w, h);
      const wx = w * 0.74, wy = h * 0.16, ww = unit * 0.26, wh = unit * 0.34, e = unit * 0.012;
      box(ctx, '#4A3040', wx - e, wy - e, ww + 2 * e, wh + 2 * e);
      ctx.save(); ctx.beginPath(); ctx.rect(wx, wy, ww, wh); ctx.clip();
      box(ctx, lin(ctx, 0, wy, 0, wy + wh, [rgba(T.night), rgba(T.dusk)]), wx, wy, ww, wh);
      ctx.translate(wx, wy); snowfall(ctx, ww, wh, time, audio.level, 60); ctx.restore();
      box(ctx, '#4A3040', wx + ww / 2 - unit * 0.004, wy, unit * 0.008, wh); box(ctx, '#4A3040', wx, wy + wh / 2 - unit * 0.004, ww, unit * 0.008);
      box(ctx, '#5A3A26', 0, floor, w, h - floor);
      for (let y = floor + unit * 0.03; y < h; y += unit * 0.035) box(ctx, '#3E2618', 0, y, w, Math.max(1, unit * 0.002));
      lit(ctx, () => glow(ctx, bx, by - th * 0.4, unit * 0.55, T.warm, 0.12 + 0.15 * audio.level));
      box(ctx, rgba(T.woodDark), bx - unit * 0.025, by - unit * 0.02, unit * 0.05, unit * 0.06);
      for (let tier = 0; tier < 4; tier++) {
        const t = tier / 4, bottom = by - th * 0.75 * t, half = tw / 2 * (1 - t * 0.68);
        ctx.beginPath(); ctx.moveTo(bx - half, bottom); ctx.lineTo(bx, Math.max(bottom - th * 0.4, top)); ctx.lineTo(bx + half, bottom); ctx.quadraticCurveTo(bx, bottom + unit * 0.03, bx - half, bottom);
        ctx.fillStyle = lin(ctx, bx - half, 0, bx + half, 0, ['#2F6B4F', rgba(T.pineDark)]); ctx.fill();
      }
      const halfAt = y => tw / 2 * Math.min(1, Math.max(0, (y - top) / th)) * 0.95;
      const sparkles = [];
      for (let swag = 0; swag < 4; swag++) {
        const y0 = top + th * (0.25 + 0.18 * swag), y1 = y0 + th * 0.1, x0 = bx - halfAt(y0) * 0.85, x1 = bx + halfAt(y1) * 0.85;
        ctx.beginPath(); ctx.moveTo(x0, y0); ctx.quadraticCurveTo(bx, (y0 + y1) / 2 + unit * 0.05, x1, y1); ctx.strokeStyle = rgba(T.gold, 0.75); ctx.lineWidth = unit * 0.006; ctx.lineCap = 'round'; ctx.stroke();
        for (let d = 0; d < 12; d++) if (hash01(swag * 20 + d, Math.floor(time * 6)) < 0.25 + 0.6 * audio.treble) { const t = d / 11; sparkles.push([x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + unit * 0.1 * t * (1 - t)]); }
      }
      lit(ctx, () => { for (const [x, y] of sparkles) dot(ctx, x, y, unit * 0.004, '#fff'); });
      for (let i = 0; i < 32; i++) {
        const y = top + th * (0.16 + 0.8 * (i + hash01(i, 5)) / 32), side = ((i * 7) % 11) / 10 + hash01(i, 6) * 0.08, x = bx + halfAt(y) * (side * 1.6 - 0.8);
        const en = audio.spectrum[i % 32], c = ORN[i % 5], r = unit * (0.012 + 0.006 * hash01(i, 7));
        if (en > 0.35) lit(ctx, () => glow(ctx, x, y, r * 4, c, 0.5 * en));
        dot(ctx, x, y, r, rad(ctx, x - r * 0.3, y - r * 0.3, 0, r * 1.4, [rgba(mix(c, T.white, 0.25 + 0.5 * en)), rgba(mix(c, T.black, Math.max(0, 0.4 - 0.3 * en)))]));
      }
      const p = audio.beatPulse, sy = top - unit * 0.01, sr = unit * 0.04 * (1 + 0.15 * p);
      lit(ctx, () => glow(ctx, bx, sy, unit * (0.08 + 0.08 * p), T.gold, 0.4 + 0.4 * p));
      poly(ctx, Array.from({ length: 10 }, (_, i) => { const a = i / 10 * Math.PI * 2 - Math.PI / 2, r = i % 2 === 0 ? sr : sr * 0.45; return [bx + Math.cos(a) * r, sy + Math.sin(a) * r]; }), rgba(mix(T.gold, T.white, 0.4 * p)));
      for (const [dx, pw, ph, c, ribbon] of [[-0.24, 0.1, 0.08, T.red, T.gold], [-0.12, 0.07, 0.06, T.blue, T.white], [0.13, 0.09, 0.07, T.green, T.red], [0.25, 0.06, 0.05, T.gold, T.red]]) {
        const x = bx + unit * dx - unit * pw / 2, y = floor - unit * ph, mx = x + unit * pw / 2;
        box(ctx, rgba(c), x, y, unit * pw, unit * ph);
        box(ctx, rgba(ribbon), mx - unit * 0.005, y, unit * 0.01, unit * ph); box(ctx, rgba(ribbon), x, y + unit * ph / 2 - unit * 0.005, unit * pw, unit * 0.01);
        for (const k of [-0.009, 0.009]) dot(ctx, mx + unit * k, y - unit * 0.005, unit * 0.007, rgba(ribbon));
      }
    },
  };
}

export const winter = {
  id: 'winter', name: 'Winter Holidays', accent: T.blue,
  wallpapers: [
    { id: 'winter.snowy-cabin', name: 'Snowy Cabin', summary: 'A log cabin in the pines with string lights that blink to the beat.', make: makeCabin },
    { id: 'winter.snow-globe', name: 'Snow Globe', summary: 'Every bass hit shakes the globe and sends the snow swirling.', make: makeGlobe },
    { id: 'winter.twinkling-tree', name: 'Twinkling Tree', summary: 'Ornaments glow with the spectrum and the star pulses on every beat.', make: makeTree },
  ],
};

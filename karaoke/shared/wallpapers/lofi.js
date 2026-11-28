// Lo-fi Chill collection, ported from BeatsWall/Collections/Lofi/*.swift. Film grain is omitted.
import { hex, rgba, mix, hash01, PhaseClock, beatProgress } from '../kit.js';
import { lin, rrect, circle, lines, dot, ell, glow } from './draw.js';

const T = { wall: hex(0x3A3560), wallDark: hex(0x2D2A4A), lamp: hex(0xFFB86B), wood: hex(0x8C5E3C), woodDark: hex(0x6B452B), pink: hex(0xE8A0A0), plant: hex(0x6A994E), plantDark: hex(0x4F7A3A), cream: hex(0xF2E8CF), ink: hex(0x1E1B2E), nightSky: hex(0x1D2549), teal: hex(0x5FA8A0), clay: hex(0xC9735A), white: [255, 255, 255] };
const oval = (ctx, x, y, rx, ry, color) => { ctx.beginPath(); ctx.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2); ctx.fillStyle = color; ctx.fill(); };
const box = (ctx, color, x, y, w, h) => { ctx.fillStyle = color; ctx.fillRect(x, y, w, h); };
const round = (ctx, color, x, y, w, h, r) => { rrect(ctx, x, y, w, h, r); ctx.fillStyle = color; ctx.fill(); };
const poly = (ctx, pts, color) => { lines(ctx, pts, true); ctx.fillStyle = color; ctx.fill(); };
const path = (ctx, pts, color, width) => { lines(ctx, pts); ctx.strokeStyle = color; ctx.lineWidth = width; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke(); };

// ---------------------------------------------------------------- Late Night Desk
function deskWindow(ctx, x, y, w, h, unit, time, audio) {
  const f = unit * 0.02;
  round(ctx, '#262241', x - f, y - f, w + 2 * f, h + 2 * f, unit * 0.008);
  ctx.save(); ctx.beginPath(); ctx.rect(x, y, w, h); ctx.clip();
  box(ctx, lin(ctx, 0, y, 0, y + h, [rgba(T.nightSky), '#3B4A7A']), x, y, w, h);
  const mx = x + w * 0.75, my = y + h * 0.22;
  glow(ctx, mx, my, unit * 0.08, T.cream, 0.3); dot(ctx, mx, my, unit * 0.03, rgba(T.cream));
  const windows = [];
  for (let bx = x, i = 0; bx < x + w; i++) {
    const bw = unit * (0.05 + 0.04 * hash01(i, 1)), bh = h * (0.2 + 0.35 * hash01(i, 2));
    box(ctx, '#161A35', bx, y + h - bh, bw, bh);
    for (let r = 0; r < Math.floor(bh / (unit * 0.025)); r++) for (let c = 0; c < 2; c++) if (hash01(i * 5 + c, r) > 0.6) windows.push([bx + bw * (0.2 + 0.4 * c), y + h - bh + unit * 0.012 + r * unit * 0.025, bw * 0.2]);
    bx += bw + unit * 0.006;
  }
  for (const [wx, wy, ww] of windows) box(ctx, rgba(T.lamp, 0.75), wx, wy, ww, unit * 0.01);
  ctx.beginPath();
  for (let d = 0; d < 30 + Math.floor(80 * audio.level); d++) {
    const fall = (hash01(d, 7) + time * (0.7 + 0.5 * hash01(d, 8))) % 1, px = x + hash01(d, 9) * w, py = y + fall * h * 1.1;
    ctx.moveTo(px, py); ctx.lineTo(px - unit * 0.003, py - unit * 0.025);
  }
  ctx.strokeStyle = 'rgba(255,255,255,0.18)'; ctx.lineWidth = Math.max(1, unit * 0.0015); ctx.stroke();
  ctx.restore();
  box(ctx, '#262241', x + w / 2 - f * 0.3, y, f * 0.6, h); box(ctx, '#262241', x, y + h / 2 - f * 0.3, w, f * 0.6); box(ctx, '#262241', x - f * 2, y + h + f, w + f * 4, f * 0.8);
}
function makeDesk() {
  const steam = new PhaseClock(), leaves = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), deskY = h * 0.7, lamp = 0.25 + 0.4 * audio.level;
      box(ctx, lin(ctx, 0, 0, 0, deskY, [rgba(T.wall), rgba(T.wallDark)]), 0, 0, w, h);
      deskWindow(ctx, w * 0.5, h * 0.1, w * 0.38, h * 0.46, unit, time, audio);
      const lx = w * 0.2, ly = deskY - unit * 0.3;
      glow(ctx, lx + unit * 0.06, ly + unit * 0.1, unit * 0.55, T.lamp, lamp);
      box(ctx, rgba(T.wood), 0, deskY, w, unit * 0.035); box(ctx, rgba(T.woodDark), 0, deskY + unit * 0.035, w, h);
      glow(ctx, lx + unit * 0.08, deskY, unit * 0.3, T.lamp, lamp * 0.8);
      const bx = w * 0.16;
      oval(ctx, bx, deskY, unit * 0.06, unit * 0.014, rgba(T.ink));
      path(ctx, [[bx, deskY], [bx - unit * 0.03, deskY - unit * 0.2], [lx, ly]], rgba(T.ink), unit * 0.012);
      poly(ctx, [[lx - unit * 0.02, ly + unit * 0.02], [lx + unit * 0.06, ly - unit * 0.035], [lx + unit * 0.35, deskY], [lx - unit * 0.05, deskY]], lin(ctx, lx, ly, lx + unit * 0.1, deskY, [rgba(T.lamp, lamp * 0.6), rgba(T.lamp, 0)]));
      poly(ctx, [[lx - unit * 0.05, ly - unit * 0.02], [lx + unit * 0.03, ly - unit * 0.07], [lx + unit * 0.09, ly], [lx - unit * 0.01, ly + unit * 0.04]], rgba(T.clay));
      glow(ctx, lx + unit * 0.03, ly + unit * 0.02, unit * 0.03, T.cream, 0.8);
      let by = deskY;
      for (const [bw, bh, c] of [[0.12, 0.022, T.pink], [0.11, 0.018, T.cream], [0.13, 0.024, T.teal]]) { by -= unit * bh; round(ctx, rgba(c), w * 0.3, by, unit * bw, unit * bh, unit * 0.003); }
      const mx = w * 0.42, my = deskY - unit * 0.07, mw = unit * 0.055;
      ctx.strokeStyle = rgba(T.cream); ctx.lineWidth = unit * 0.008; ctx.beginPath(); ctx.ellipse(mx + mw, my + unit * 0.035, unit * 0.016, unit * 0.018, 0, 0, Math.PI * 2); ctx.stroke();
      round(ctx, rgba(T.cream), mx, my, mw, unit * 0.07, unit * 0.01);
      const rise = steam.advance(time, 0.5 + 0.6 * audio.mid);
      for (let i = 0; i < 3; i++) {
        const sx = mx + mw * (0.25 + 0.25 * i), pts = [[sx, my - unit * 0.01]];
        for (let s = 1; s <= 20; s++) { const t = s / 20; pts.push([sx + unit * 0.012 * Math.sin(rise * 3 + t * 7 + i * 2.1) * t, my - unit * 0.01 - unit * 0.14 * t]); }
        path(ctx, pts, lin(ctx, sx, my, sx, my - unit * 0.15, [rgba(T.cream, 0.45), rgba(T.cream, 0)]), unit * 0.005);
      }
      const sway = leaves.advance(time, 1 + audio.mid), px = w * 0.9 - unit * 0.04, py = deskY - unit * 0.07, sx = px + unit * 0.04;
      for (let i = 0; i < 7; i++) {
        const a = -Math.PI / 2 + (i - 3) * 0.33 + Math.sin(sway + i) * 0.06 * (0.5 + audio.mid), len = unit * (0.09 + 0.03 * hash01(i, 4)), lw = unit * 0.022;
        const dx = Math.cos(a), dy = Math.sin(a), tx = sx + dx * len, ty = py + dy * len, cx = sx + dx * len / 2, cy = py + dy * len / 2;
        ctx.beginPath(); ctx.moveTo(sx, py); ctx.quadraticCurveTo(cx - dy * lw, cy + dx * lw, tx, ty); ctx.quadraticCurveTo(cx + dy * lw, cy - dx * lw, sx, py);
        ctx.fillStyle = rgba(i % 2 === 0 ? T.plant : T.plantDark); ctx.fill();
      }
      poly(ctx, [[px, py], [px + unit * 0.08, py], [px + unit * 0.07, deskY], [px + unit * 0.01, deskY]], rgba(T.clay));
      // The cat, tail tapping on the beat.
      const cx = w * 0.66, bodyY = deskY - unit * 0.07, ink = rgba(T.ink), a = -0.2 - 0.9 * audio.beatPulse, tx = cx + unit * 0.05, ty = deskY - unit * 0.012;
      ctx.beginPath(); ctx.moveTo(tx, ty); ctx.quadraticCurveTo(tx + unit * 0.07, ty + unit * 0.01, tx + Math.cos(a) * unit * 0.11, ty + Math.sin(a) * unit * 0.11);
      ctx.strokeStyle = ink; ctx.lineWidth = unit * 0.016; ctx.lineCap = 'round'; ctx.stroke();
      oval(ctx, cx, bodyY, unit * 0.062, unit * 0.072, ink);
      const hy = bodyY - unit * 0.085;
      oval(ctx, cx, hy, unit * 0.042, unit * 0.038, ink);
      for (const s of [-1, 1]) poly(ctx, [[cx + s * unit * 0.038, hy - unit * 0.012], [cx + s * unit * 0.034, hy - unit * 0.062], [cx + s * unit * 0.008, hy - unit * 0.032]], ink);
    },
  };
}

// ---------------------------------------------------------------- Vinyl Room
function makeVinyl() {
  const platter = new PhaseClock(), BULBS = [T.lamp, T.pink, T.teal, hex(0xFFE08A)];
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), shelf = h * 0.66, cx = w / 2;
      box(ctx, lin(ctx, 0, 0, 0, shelf, ['#4A3B5C', '#3A2F4C']), 0, 0, w, h);
      const ax = w * 0.12, ay = h * 0.2;
      round(ctx, rgba(T.cream), ax, ay, unit * 0.22, unit * 0.3, unit * 0.004);
      dot(ctx, ax + unit * 0.11, ay + unit * 0.12, unit * 0.06, rgba(T.clay));
      for (let r = 0; r < 3; r++) box(ctx, rgba(T.teal, 0.8), ax + unit * 0.025, ay + unit * 0.3 * (0.68 + 0.08 * r), unit * 0.17, unit * 0.008);
      const bx = w * 0.88 - unit * 0.2, by = h * 0.24;
      round(ctx, rgba(T.teal), bx, by, unit * 0.2, unit * 0.24, unit * 0.004);
      path(ctx, Array.from({ length: 21 }, (_, i) => [bx + unit * 0.02 + unit * 0.16 * i / 20, by + unit * 0.12 + unit * 0.03 * Math.sin(i * 0.9)]), rgba(T.cream), unit * 0.008);
      // Fairy lights
      const at = t => [w * t, h * 0.08 + h * 0.08 * (1 - (2 * t - 1) ** 2) + unit * 0.01 * Math.sin(t * 18)];
      path(ctx, Array.from({ length: 61 }, (_, i) => at(i / 60)), rgba(T.ink, 0.7), Math.max(1, unit * 0.002));
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 28; i++) {
        const [x, y0] = at((i + 0.5) / 28), y = y0 + unit * 0.012, tw = 0.5 + 0.5 * Math.sin(time * (1.5 + 3 * hash01(i, 9)) + i), beat = hash01(i, audio.beatCount) > 0.6 ? audio.beatPulse : 0;
        const b = Math.min(1, 0.35 + 0.4 * tw * (0.4 + audio.treble) + 0.5 * beat), c = BULBS[i % 4];
        glow(ctx, x, y, unit * 0.035, c, 0.45 * b); oval(ctx, x, y, unit * 0.006, unit * 0.008, rgba(mix(c, T.white, 0.3), 0.4 + 0.6 * b));
      }
      ctx.restore();
      box(ctx, rgba(T.wood), 0, shelf, w, unit * 0.03); box(ctx, rgba(T.woodDark), 0, shelf + unit * 0.03, w, h);
      for (const x of [0.25, 0.5, 0.75]) box(ctx, '#553620', w * x - unit * 0.002, shelf + unit * 0.05, unit * 0.004, h);
      for (const side of [-1, 1]) {
        const sx = cx + side * unit * 0.48, top = shelf - unit * 0.3;
        round(ctx, '#2A2238', sx - unit * 0.09, top, unit * 0.18, unit * 0.3, unit * 0.012);
        const wy = shelf - unit * 0.09, push = 1 + 0.08 * audio.bass + 0.04 * audio.beatPulse;
        dot(ctx, sx, wy, unit * 0.065, '#1A1524'); dot(ctx, sx, wy, unit * 0.055 * push, '#3A3048'); dot(ctx, sx, wy, unit * 0.022 * push, '#4E425E');
        dot(ctx, sx, top + unit * 0.06, unit * 0.025, '#1A1524'); dot(ctx, sx, top + unit * 0.06, unit * 0.014 * (1 + 0.15 * audio.treble), '#4E425E');
      }
      const px = cx - unit * 0.26, py = shelf - unit * 0.2;
      round(ctx, '#3A2618', px, py + unit * 0.015, unit * 0.52, unit * 0.2, unit * 0.02); round(ctx, '#5A3A2A', px, py, unit * 0.52, unit * 0.2, unit * 0.02);
      const sx = px + unit * 0.52 * 0.42, sy = py + unit * 0.1, rx = unit * 0.17, ry = unit * 0.075;
      oval(ctx, sx, sy, rx * 1.04, ry * 1.04, '#2A2A2E'); oval(ctx, sx, sy, rx, ry, '#121216');
      ctx.strokeStyle = 'rgba(255,255,255,0.06)'; ctx.lineWidth = Math.max(1, unit * 0.0015);
      for (let r = 0; r < 7; r++) { const s = 0.45 + 0.08 * r; ctx.beginPath(); ctx.ellipse(sx, sy, rx * s, ry * s, 0, 0, Math.PI * 2); ctx.stroke(); }
      ctx.save(); ctx.translate(sx, sy); ctx.scale(rx * 0.8, ry * 0.8); ctx.beginPath(); ctx.arc(0, 0, 1, 200 * Math.PI / 180, 250 * Math.PI / 180); ctx.strokeStyle = 'rgba(255,255,255,0.12)'; ctx.lineWidth = 0.12; ctx.stroke(); ctx.restore();
      const rot = platter.advance(time, 2 * Math.PI * 33.3 / 60);
      oval(ctx, sx, sy, rx * 0.3, ry * 0.3, rgba(T.clay));
      for (let m = 0; m < 2; m++) oval(ctx, sx + Math.cos(rot + m * Math.PI) * rx * 0.2, sy + Math.sin(rot + m * Math.PI) * ry * 0.2, rx * 0.05, ry * 0.05, rgba(T.cream));
      oval(ctx, sx, sy, unit * 0.004, unit * 0.003, '#fff');
      const ox = px + unit * 0.46, oy = py + unit * 0.04, nx = sx + rx * 0.7, ny = sy + ry * 0.35;
      oval(ctx, ox, oy, unit * 0.02, unit * 0.014, '#B9C0C9');
      path(ctx, [[ox, oy], [ox - unit * 0.02, oy + unit * 0.07], [nx, ny]], '#B9C0C9', unit * 0.006);
      round(ctx, '#2A2A2E', nx - unit * 0.012, ny - unit * 0.008, unit * 0.024, unit * 0.014, unit * 0.003);
    },
  };
}

// ---------------------------------------------------------------- Rooftop Sunset
function skyline(ctx, w, h, unit, base, seed, height, color, audio) {
  const lit = [];
  for (let x = -unit * 0.02, i = seed; x < w; i++) {
    const bw = unit * (0.06 + 0.07 * hash01(i, 1)), tall = unit * height * (0.35 + 0.65 * hash01(i, 2));
    box(ctx, color, x, base - tall, bw, tall + h);
    if (audio) {
      const bin = Math.max(0, Math.min(Math.floor(x / w * 32), 31)), e = audio.spectrum[bin];
      for (let r = 0; r < Math.floor(tall / (unit * 0.022)); r++) for (let c = 0; c < 3; c++) if (hash01(i * 7 + c, r) < 0.12 + 0.6 * e) lit.push([x + bw * (0.15 + 0.27 * c), base - tall + unit * 0.012 + r * unit * 0.022, bw * 0.16]);
    }
    x += bw + unit * 0.004;
  }
  for (const [x, y, ww] of lit) box(ctx, rgba(hex(0xFFD27A), 0.85), x, y, ww, unit * 0.009);
}
function makeRooftop() {
  const clouds = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), horizon = h * 0.66, drift = clouds.advance(time, 0.01 + 0.02 * audio.level);
      box(ctx, lin(ctx, 0, 0, 0, horizon, ['#5B4B8A', '#C46F8A', '#F28C6B', '#FFD5A5']), 0, 0, w, h);
      const sx = w * 0.3, sy = horizon - unit * 0.2;
      glow(ctx, sx, sy, unit * (0.3 + 0.08 * audio.bass), hex(0xFFE3A3), 0.55); dot(ctx, sx, sy, unit * 0.09, '#FFE9B8');
      for (let i = 0; i < 6; i++) {
        const span = w + unit * 0.8, x = (hash01(i, 1) * span + drift * unit * (0.6 + hash01(i, 2))) % span - unit * 0.4, y = h * (0.08 + 0.35 * hash01(i, 3)), s = unit * (0.04 + 0.04 * hash01(i, 4));
        ctx.beginPath();
        for (const [dx, dy, rx, ry] of [[-1.6, 0.1, 1.4, 0.55], [0, -0.15, 1.8, 0.75], [1.7, 0.1, 1.3, 0.5]]) { ctx.moveTo(x + (dx + rx) * s, y + dy * s); ctx.ellipse(x + dx * s, y + dy * s, rx * s, ry * s, 0, 0, Math.PI * 2); }
        ctx.fillStyle = rgba(hex(0xFFE1D0), 0.55); ctx.fill();
      }
      const beat = beatProgress(audio, time);
      ctx.beginPath();
      for (let i = 0; i < 6; i++) {
        const span = w + unit * 0.4, x = (hash01(i, 21) * span + time * unit * (0.025 + 0.02 * hash01(i, 22))) % span - unit * 0.2;
        const y = h * (0.15 + 0.3 * hash01(i, 23)) + unit * 0.01 * Math.sin(time + i), wing = unit * (0.012 + 0.006 * hash01(i, 24)), flap = Math.sin(2 * Math.PI * beat + i * 0.9) * wing * 0.8;
        ctx.moveTo(x - wing, y - flap); ctx.quadraticCurveTo(x - wing * 0.5, y - flap * 0.5 - wing * 0.3, x, y); ctx.quadraticCurveTo(x + wing * 0.5, y - flap * 0.5 - wing * 0.3, x + wing, y - flap);
      }
      ctx.strokeStyle = '#3A2F4C'; ctx.lineWidth = Math.max(1, unit * 0.003); ctx.lineCap = 'round'; ctx.stroke();
      skyline(ctx, w, h, unit, horizon, 0, 0.13, '#8A6A9A', null);
      skyline(ctx, w, h, unit, horizon + unit * 0.08, 50, 0.17, '#4A3B5C', audio);
      const roof = h * 0.84, dark = '#2E2540';
      box(ctx, dark, 0, roof, w, h); box(ctx, '#3A2F4C', 0, roof - unit * 0.025, w, unit * 0.025);
      const tx = w * 0.14, ty = roof - unit * 0.025;
      for (const dx of [-0.06, 0.06]) path(ctx, [[tx + unit * dx, ty], [tx + unit * dx * 0.8, ty - unit * 0.14]], dark, unit * 0.008);
      path(ctx, [[tx - unit * 0.055, ty - unit * 0.06], [tx + unit * 0.055, ty - unit * 0.06]], dark, unit * 0.008);
      const k = ty - unit * 0.29;
      round(ctx, dark, tx - unit * 0.07, k, unit * 0.14, unit * 0.15, unit * 0.01);
      poly(ctx, [[tx - unit * 0.08, k], [tx, k - unit * 0.06], [tx + unit * 0.08, k]], dark);
      const ax = w * 0.86;
      path(ctx, [[ax, ty], [ax, ty - unit * 0.22]], dark, unit * 0.005);
      for (const [half, y] of [[0.04, 0.15], [0.025, 0.19]]) path(ctx, [[ax - unit * half, ty - unit * y], [ax + unit * half, ty - unit * y]], dark, unit * 0.005);
      glow(ctx, ax, ty - unit * 0.225, unit * 0.03, hex(0xFF5A5F), 0.2 + 0.7 * audio.beatPulse); dot(ctx, ax, ty - unit * 0.225, unit * 0.005, '#FF5A5F');
    },
  };
}

export const lofi = {
  id: 'lofi', name: 'Lo-fi Chill', accent: T.lamp,
  wallpapers: [
    { id: 'lofi.late-night-desk', name: 'Late Night Desk', summary: 'Rain on the window, steaming coffee and a cat tapping its tail on the beat.', make: makeDesk },
    { id: 'lofi.vinyl-room', name: 'Vinyl Room', summary: 'A spinning record, thumping speakers and twinkling fairy lights.', make: makeVinyl },
    { id: 'lofi.rooftop-sunset', name: 'Rooftop Sunset', summary: 'Golden hour over the city: birds flap in tempo and windows light with the spectrum.', make: makeRooftop },
  ],
};

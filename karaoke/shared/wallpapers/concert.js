// Concert collection, ported from BeatsWall/Collections/Concert/*.swift. Film grain is omitted.
// Album art, stage images and song-name screens are Mac features and are not ported.
import { hex, rgba, mix, lerp, smoothstep, hash01, PhaseClock, beatProgress, beatLength, twoBoneJoint } from '../kit.js';
import { lin, rrect, circle, lines, dot, ell } from './draw.js';
import { T, rigColor, motion, glow, haze, beam, strobe, laserShow, crowd, confetti, sparkRain, firework, HypeMeter } from './stagekit.js';

const fill = (ctx, color, x, y, w, h) => { ctx.fillStyle = color; ctx.fillRect(x, y, w, h); };
const rgb = n => rgba(hex(n));
const add = ctx => { ctx.globalCompositeOperation = 'lighter'; };
const over = ctx => { ctx.globalCompositeOperation = 'source-over'; };
const stroke = (ctx, pts, color, width) => { lines(ctx, pts); ctx.strokeStyle = color; ctx.lineWidth = width; ctx.stroke(); };

// ---------------------------------------------------------------- Main Stage
function stageScreen(ctx, x, y, w, h, time, audio, bar, color, accent) {
  const pulse = audio.beatPulse, cx = x + w / 2, cy = y + h / 2;
  ctx.save(); ctx.beginPath(); ctx.rect(x, y, w, h); ctx.clip();
  const mode = ((bar % 4) + 4) % 4;
  if (mode === 0) {
    const bw = w / 32;
    for (let bin = 0; bin < 16; bin++) {
      const bh = h * (0.05 + 0.9 * audio.spectrum[Math.min(bin * 2, audio.spectrum.length - 1)]);
      for (const side of [-1, 1]) { const bx = cx + side * (bin + 0.5) * bw - bw * 0.4; fill(ctx, lin(ctx, bx, y + h, bx, y, [rgba(accent), rgba(color)]), bx, y + h - bh, bw * 0.8, bh); }
    }
  } else if (mode === 1) {
    for (let r = 0; r < 6; r++) {
      const p = (r + (beatProgress(audio, time) % 1)) / 6;
      ctx.strokeStyle = rgba(r % 2 === 0 ? color : accent, 1 - p); ctx.lineWidth = h * 0.04 * (1 + pulse); circle(ctx, cx, cy, w * p * 0.7); ctx.stroke();
    }
  } else if (mode === 2) {
    const cell = w / 8, rows = Math.floor(h / cell) + 1;
    ctx.fillStyle = rgba(color, 0.35 + 0.6 * pulse);
    for (let r = 0; r < rows; r++) for (let c = 0; c < 8; c++) if ((r + c + audio.beatCount) % 2 === 0) ctx.fillRect(x + c * cell, y + r * cell, cell, cell);
  } else {
    const spin = beatProgress(audio, time) * 0.25;
    ctx.beginPath();
    for (let i = 0; i < 18; i++) { const a = i / 18 * Math.PI * 2 + spin; ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(a - 0.06) * w, cy + Math.sin(a - 0.06) * w); ctx.lineTo(cx + Math.cos(a + 0.06) * w, cy + Math.sin(a + 0.06) * w); ctx.closePath(); }
    ctx.fillStyle = rgba(accent, 0.3 + 0.5 * pulse); ctx.fill();
    dot(ctx, cx, cy, h * (0.12 + 0.12 * audio.bass), rgba(color));
  }
  fill(ctx, `rgba(255,255,255,${0.12 * pulse})`, x, y, w, h);
  ctx.restore();
}

function makeMainStage() {
  const hype = new HypeMeter();
  return {
    draw(ctx, w, h, { time, audio }) {
      hype.update(time, audio);
      const unit = Math.min(w, h), beat = beatProgress(audio, time), bar = Math.floor(beat / 4), e = hype.energy, pulse = audio.beatPulse;
      const color = rigColor(bar), accent = rigColor(bar, 2), sw = Math.min(w * 0.94, unit * 1.7), sl = (w - sw) / 2, floorY = h * 0.64, trussY = h * 0.14;
      ctx.save();
      fill(ctx, lin(ctx, 0, 0, 0, h, [rgba(T.night), rgb(0x140A24), rgba(T.night)]), 0, 0, w, h);
      add(ctx); glow(ctx, w / 2, floorY - unit * 0.2, unit * 0.9, color, 0.12 + 0.2 * e + 0.25 * hype.dropPulse); over(ctx);
      const wx = w / 2 - sw * 0.3, wy = trussY + unit * 0.09, ww = sw * 0.6, wh = floorY - trussY - unit * 0.16;
      fill(ctx, '#05030A', wx, wy, ww, wh);
      add(ctx); stageScreen(ctx, wx, wy, ww, wh, time, audio, bar, color, accent);
      for (const side of [-1, 1]) {
        const rw = sw * 0.13, rx = w / 2 + side * sw * 0.4 - rw / 2, ry = wy + unit * 0.04, rh = wh * 0.7;
        over(ctx); fill(ctx, '#05030A', rx, ry, rw, rh); add(ctx);
        fill(ctx, lin(ctx, 0, ry, 0, ry + rh, [rgba(accent, 0.15 + 0.5 * pulse), rgba(color, 0.1 + 0.3 * e)]), rx + unit * 0.004, ry + unit * 0.004, rw - unit * 0.008, rh - unit * 0.008);
      }
      over(ctx);
      lines(ctx, [[sl, floorY], [sl + sw, floorY], [sl + sw + unit * 0.05, floorY + unit * 0.06], [sl - unit * 0.05, floorY + unit * 0.06]], true); ctx.fillStyle = rgba(T.stage); ctx.fill();
      add(ctx); stroke(ctx, [[sl - unit * 0.05, floorY + unit * 0.06], [sl + sw + unit * 0.05, floorY + unit * 0.06]], rgba(color, 0.4 + 0.6 * pulse), unit * 0.004); over(ctx);
      fill(ctx, '#1A1626', sl, trussY, sw, unit * 0.035);
      fill(ctx, '#1A1626', sl, trussY, unit * 0.035, floorY - trussY); fill(ctx, '#1A1626', sl + sw - unit * 0.035, trussY, unit * 0.035, floorY - trussY);
      ctx.beginPath(); for (let x = sl; x < sl + sw; x += unit * 0.035) { ctx.moveTo(x, trussY); ctx.lineTo(x + unit * 0.035, trussY + unit * 0.035); }
      ctx.strokeStyle = '#2E2840'; ctx.lineWidth = Math.max(1, unit * 0.002); ctx.stroke();
      const fan = 0.25 + 0.45 * hype.dropPulse;
      for (let i = 0; i < 8; i++) {
        const t = i / 7, ox = sl + sw * (0.08 + 0.84 * t), oy = trussY + unit * 0.045;
        const angle = (motion(i, 8, beat) + (t - 0.5) * 2 * fan) * (1 - hype.build * 0.7) - (t - 0.5) * 0.9 * hype.build;
        add(ctx); beam(ctx, ox, oy, angle, h * 1.05, 0.06 - 0.03 * hype.build, i % 2 === 0 ? color : accent, 0.25 + 0.55 * e + 0.3 * hype.build);
        over(ctx); rrect(ctx, ox - unit * 0.012, oy - unit * 0.015, unit * 0.024, unit * 0.02, unit * 0.004); ctx.fillStyle = '#2A2438'; ctx.fill();
      }
      add(ctx);
      for (let i = 0; i < 6; i++) {
        const t = i / 5, angle = Math.PI + (t - 0.5) * (0.5 + 0.9 * hype.dropPulse) + motion(i, 6, beat / 2) * 0.33;
        beam(ctx, sl + sw * (0.12 + 0.76 * t), floorY, angle, h * 0.75, 0.035, accent, 0.15 + 0.5 * audio.bass * e);
      }
      haze(ctx, 0, trussY, w, floorY - trussY + unit * 0.2, color, 0.05 + 0.12 * hype.build);
      const age = hype.secondsSinceDrop;
      if (age < 1.6) {
        const rise = 1 - Math.exp(-age * 6), fade = 1 - smoothstep(0.4, 1.6, age);
        for (let i = 0; i < 4; i++) {
          const bx = sl + sw * (0.2 + 0.2 * i), ph = unit * 0.45 * rise;
          ctx.beginPath(); ctx.moveTo(bx - unit * 0.01, floorY); ctx.quadraticCurveTo(bx - unit * 0.07, floorY - ph * 0.6, bx, floorY - ph); ctx.quadraticCurveTo(bx + unit * 0.07, floorY - ph * 0.6, bx + unit * 0.01, floorY); ctx.closePath();
          ctx.fillStyle = lin(ctx, 0, floorY, 0, floorY - ph - 1, [`rgba(255,255,255,${0.7 * fade})`, `rgba(255,255,255,${0.05 * fade})`]); ctx.fill();
        }
      }
      over(ctx);
      confetti(ctx, sl + unit * 0.05, floorY, 0.45, age, unit, 180, hype.dropCount * 7);
      confetti(ctx, sl + sw - unit * 0.05, floorY, -0.45, age, unit, 180, hype.dropCount * 7 + 3);
      [[0.8, 0.12, 30, rgb(0x120C1C)], [0.9, 0.17, 20, rgb(0x09060F)], [1.02, 0.25, 12, rgba(T.crowd)]].forEach(([base, scale, n, c], i) => {
        crowd(ctx, w, unit, h * base, scale, Math.floor(n * (w / unit) * 0.6 + 2), 40 + i * 10, c, audio, beat, 0.15 + 0.5 * e + 0.35 * hype.dropPulse, 0.2 + 0.7 * e);
      });
      strobe(ctx, w, h, Math.max(e > 0.6 && audio.secondsSinceBeat < 0.06 ? 0.5 : 0, age < 1.2 && Math.sin(time * 50) > 0.3 ? 0.8 : 0));
      ctx.restore();
    },
  };
}

// ---------------------------------------------------------------- Headliner
/** Adds a torso (hips to shoulders) to the current path. */
function torso(ctx, hx, hy, nx, ny, hw, sw) {
  const mx = (hx + nx) / 2, my = (hy + ny) / 2;
  ctx.moveTo(hx - hw / 2, hy); ctx.lineTo(hx + hw / 2, hy); ctx.quadraticCurveTo(mx + sw * 0.55, my, nx + sw / 2, ny);
  ctx.lineTo(nx - sw / 2, ny); ctx.quadraticCurveTo(mx - sw * 0.55, my, hx - hw / 2, hy); ctx.closePath();
}
const addDisc = (ctx, x, y, r) => { ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, Math.PI * 2); };
function limbs(ctx, list, color, width) {
  ctx.beginPath(); for (const pts of list) { ctx.moveTo(...pts[0]); for (let i = 1; i < pts.length; i++) ctx.lineTo(...pts[i]); }
  ctx.strokeStyle = color; ctx.lineWidth = width; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke();
}
const SIL = '#050308';

function drummer(ctx, sx, sy, unit, audio, glowColor) {
  const s = unit * 0.22, hx = sx, hy = sy - s * 0.15, nx = hx, ny = hy - s * 0.4, bl = beatLength(audio);
  const swing = Math.min(audio.secondsSinceBeat / Math.max(bl * 0.5, 0.1), 1), arms = [];
  for (const side of [-1, 1]) {
    const lift = (audio.beatCount % 2 === 0 ? 1 : -1) === side ? swing : 1 - swing * 0.5;
    const ax = nx + s * 0.12 * side, ay = ny + s * 0.05, px = ax + s * 0.28 * side, py = ay + s * (0.22 - 0.3 * lift), a = side * (0.4 + 1.1 * lift);
    arms.push([[ax, ay], twoBoneJoint(ax, ay, px, py, s * 0.2, s * 0.2, side), [px, py]], [[px, py], [px + Math.sin(a) * s * 0.25, py - Math.cos(a) * s * 0.25]]);
  }
  limbs(ctx, arms, SIL, s * 0.09);
  ctx.beginPath(); addDisc(ctx, nx, ny - s * 0.12, s * 0.1); torso(ctx, hx, hy, nx, ny, s * 0.22, s * 0.3); ctx.fillStyle = SIL; ctx.fill();
  const kx = sx, ky = sy + s * 0.12;
  dot(ctx, kx, ky, s * 0.3, SIL);
  add(ctx); glow(ctx, kx, ky, s * (0.28 + 0.1 * audio.bass), glowColor, 0.25 + 0.6 * audio.bass);
  ctx.strokeStyle = rgba(glowColor, 0.3 + 0.7 * audio.beatPulse); ctx.lineWidth = s * 0.02; circle(ctx, kx, ky, s * 0.26); ctx.stroke(); over(ctx);
  for (const side of [-1, 1]) {
    const cx = kx + s * 0.65 * side, cy = ky - s * 0.75;
    ctx.fillStyle = SIL; ell(ctx, kx + s * 0.35 * side - s * 0.12, ky - s * 0.35, s * 0.24, s * 0.16); ctx.fill();
    ell(ctx, cx - s * 0.2, cy - s * 0.03, s * 0.4, s * 0.06); ctx.fill();
    stroke(ctx, [[cx, cy], [cx, cy + s * 0.9]], SIL, s * 0.02);
    add(ctx); ell(ctx, cx - s * 0.2, cy - s * 0.03, s * 0.4, s * 0.06); ctx.fillStyle = rgba(T.amber, 0.5 * audio.treble); ctx.fill(); over(ctx);
  }
}
function guitarist(ctx, fx, fy, unit, audio, beat) {
  const s = unit * 0.42, hx = fx, hy = fy - s * 0.45, bang = audio.beatPulse * audio.bass;
  const nx = hx + s * 0.06 * bang, ny = hy - s * 0.38, ex = nx + s * (0.03 + 0.08 * bang), ey = ny - s * (0.1 - 0.06 * bang);
  const gx = nx - s * 0.35, gy = ny - s * 0.08, bx = hx + s * 0.05, by = hy - s * 0.05, strum = Math.sin(beat * Math.PI * 2) * 0.03;
  limbs(ctx, [[[fx - s * 0.18, fy], [hx, hy], [fx + s * 0.2, fy]], [[bx, by], [gx, gy]],
    [[nx - s * 0.04, ny + s * 0.04], [nx - s * 0.2, ny + s * 0.06], [gx + s * 0.05, gy + s * 0.02]],
    [[nx + s * 0.04, ny + s * 0.04], [hx + s * 0.15, hy - s * 0.15], [bx + s * 0.04, by + s * strum]]], SIL, s * 0.065);
  ctx.beginPath(); ctx.moveTo(ex - s * 0.05, ey - s * 0.02); ctx.quadraticCurveTo(ex + s * 0.12, ey - s * 0.05, ex + s * (0.06 + 0.1 * bang), ey + s * (0.12 + 0.05 * bang));
  ctx.strokeStyle = SIL; ctx.lineWidth = s * 0.06; ctx.stroke();
  ctx.beginPath(); torso(ctx, hx, hy, nx, ny, s * 0.12, s * 0.17); addDisc(ctx, ex, ey, s * 0.07);
  ctx.ellipse(bx, by, s * 0.13, s * 0.09, 0, 0, Math.PI * 2); ctx.fillStyle = SIL; ctx.fill('nonzero');
}
function singer(ctx, fx, fy, unit, audio, beat, raise) {
  const s = unit * 0.5, sway = Math.sin(beat * Math.PI / 2) * s * 0.02, hx = fx + sway, hy = fy - s * 0.45, nx = hx + sway, ny = hy - s * 0.36, ex = nx, ey = ny - s * 0.09;
  const mx = ex + s * 0.07, my = ey + s * 0.03, up = Math.max(raise, 0.3 * audio.mid);
  const px = nx - s * (0.22 - 0.1 * up), py = ny + s * (0.15 - 0.45 * up);
  stroke(ctx, [[fx + s * 0.12, fy], [mx + s * 0.03, my + s * 0.03]], SIL, s * 0.012);
  limbs(ctx, [[[fx - s * 0.08, fy], [hx, hy], [fx + s * 0.09, fy]], [[nx + s * 0.04, ny + s * 0.03], [nx + s * 0.12, ny + s * 0.12], [mx, my]],
    [[nx - s * 0.04, ny + s * 0.03], [nx - s * 0.16, ny + s * (0.08 - 0.15 * up)], [px, py]]], SIL, s * 0.055);
  ctx.beginPath(); torso(ctx, hx, hy, nx, ny, s * 0.1, s * 0.15); addDisc(ctx, ex, ey, s * 0.065); addDisc(ctx, px, py, s * 0.025); ctx.fillStyle = SIL; ctx.fill();
}
function flame(ctx, bx, by, height, width, time, seed) {
  [[1, T.pyro], [0.75, T.amber], [0.45, hex(0xFFF1C8)]].forEach(([k, c], i) => {
    const fh = height * k * (0.85 + 0.15 * Math.sin(time * (13 + i * 3) + seed)), half = width * k / 2, lick = Math.sin(time * 7 + seed * 2) * width * 0.3;
    ctx.beginPath(); ctx.moveTo(bx - half, by); ctx.quadraticCurveTo(bx - half * 1.6, by - fh * 0.5, bx + lick, by - fh); ctx.quadraticCurveTo(bx + half * 1.6 + lick * 0.5, by - fh * 0.5, bx + half, by); ctx.closePath();
    ctx.fillStyle = lin(ctx, bx, by, bx, by - fh - 1, [rgba(c, 0.95), rgba(c, 0.1)]); ctx.fill();
  });
}
function makeHeadliner() {
  const hype = new HypeMeter(), smoke = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      hype.update(time, audio);
      const unit = Math.min(w, h), beat = beatProgress(audio, time), e = hype.energy, pulse = audio.beatPulse, drift = smoke.advance(time, 0.4 + 0.6 * e);
      const cx = w / 2, floorY = h * 0.7, warm = mix(T.pyro, T.magenta, 0.5 + 0.5 * Math.sin(beat * Math.PI / 8));
      ctx.save();
      fill(ctx, rgba(T.night), 0, 0, w, h);
      add(ctx); glow(ctx, cx, floorY - unit * 0.15, unit * 0.85, warm, 0.25 + 0.35 * e + 0.3 * hype.dropPulse);
      const cols = Math.max(6, Math.floor(w / (unit * 0.12))), sp = w / cols, bins = audio.spectrum.length;
      for (let r = 0; r < 3; r++) for (let c = 0; c < cols; c++) {
        const on = audio.spectrum[(Math.floor(c * bins / cols) + r * 3) % bins], x = sp * (c + 0.5), y = h * 0.1 + r * unit * 0.1;
        over(ctx); dot(ctx, x, y, unit * 0.02, '#1A1420'); add(ctx);
        glow(ctx, x, y, unit * (0.03 + 0.05 * on), (r + c + Math.floor(audio.beatCount / 4)) % 3 === 0 ? T.amber : warm, 0.2 + 0.8 * on * e);
      }
      const singerX = cx + Math.min(unit * 0.24, w * 0.22);
      beam(ctx, cx + unit * 0.3, -unit * 0.05, Math.atan2(singerX - (cx + unit * 0.3), floorY), floorY * 1.15, 0.07, T.white, 0.35 + 0.3 * e);
      for (const side of [-1, 1]) beam(ctx, cx + side * w * 0.45, h * 0.05, -side * (0.5 + 0.55 * motion(side > 0 ? 1 : 0, 2, beat)), h, 0.08, warm, 0.2 + 0.5 * audio.mid);
      over(ctx);
      fill(ctx, rgba(T.stage), 0, floorY, w, h - floorY);
      const ry = floorY - unit * 0.12;
      fill(ctx, '#0A0710', cx - unit * 0.22, ry, unit * 0.44, unit * 0.12);
      add(ctx); stroke(ctx, [[cx - unit * 0.22, ry], [cx + unit * 0.22, ry]], rgba(warm, 0.4 + 0.6 * pulse), unit * 0.004); over(ctx);
      drummer(ctx, cx, ry, unit, audio, warm);
      guitarist(ctx, cx - Math.min(unit * 0.42, w * 0.3), floorY, unit, audio, beat);
      singer(ctx, singerX, floorY + unit * 0.02, unit, audio, beat, hype.dropPulse);
      add(ctx);
      const hit = e > 0.5 ? Math.pow(pulse, 1.5) * audio.bass : 0;
      for (let i = 0; i < 4; i++) {
        const fires = hype.dropPulse > 0.2 || hash01(i, audio.beatCount) < 0.5, k = Math.max(hype.dropPulse, fires ? hit : 0);
        if (k <= 0.05) continue;
        const bx = w * (0.08 + 0.84 * (i + 0.5) / 4), by = floorY + unit * 0.01;
        flame(ctx, bx, by, unit * 0.55 * k, unit * 0.07, time, i); glow(ctx, bx, by, unit * 0.5 * k, T.pyro, 0.4 * k);
      }
      const age = hype.secondsSinceDrop;
      sparkRain(ctx, 0, w, h * 0.04, floorY, isFinite(age) ? age : 0, unit, 220, isFinite(age) ? 1 - smoothstep(3, 6, age) : 0);
      for (let i = 0; i < 5; i++) {
        const x = (((drift * 0.05 + hash01(i, 21)) % 1.4) - 0.2) * w;
        ctx.save(); ctx.translate(x, floorY - unit * (0.02 + 0.08 * hash01(i, 22))); ctx.scale(2.4, 0.6);
        glow(ctx, 0, 0, unit * 0.2, mix(warm, T.white, 0.6), 0.08 + 0.1 * e); ctx.restore();
      }
      over(ctx);
      crowd(ctx, w, unit, h * 1.03, 0.24, Math.floor(w / unit * 7) + 2, 70, rgba(T.crowd), audio, beat, 0.25 + 0.5 * e + 0.3 * hype.dropPulse, 0.15 + 0.6 * e);
      strobe(ctx, w, h, Math.max(e > 0.7 && audio.secondsSinceBeat < 0.05 ? 0.35 : 0, age < 0.25 ? 0.7 * (1 - age * 4) : 0));
      ctx.restore();
    },
  };
}

// ---------------------------------------------------------------- Lights Up
function makeLightsUp() {
  const hype = new HypeMeter();
  return {
    draw(ctx, w, h, { time, audio }) {
      hype.update(time, audio);
      const unit = Math.min(w, h), beat = beatProgress(audio, time), e = hype.energy, pulse = audio.beatPulse, cx = w / 2, rimY = h * 0.36, fieldY = h * 0.62;
      ctx.save();
      fill(ctx, lin(ctx, 0, 0, 0, rimY, ['#050A22', '#1A1046', '#3A1550']), 0, 0, w, h);
      ctx.fillStyle = 'rgba(255,255,255,0.7)'; ctx.beginPath();
      for (let i = 0; i < 120; i++) addDisc(ctx, hash01(i, 1) * w, hash01(i, 2) * rimY * 0.8, unit * 0.0018 * (1.1 + 0.5 * Math.sin(time * (1 + 2 * hash01(i, 3)) + i)));
      ctx.fill();
      add(ctx);
      for (let back = 0; back < 4; back++) {
        const n = audio.beatCount - back;
        if (!(hash01(n, 7) < e * 0.8)) continue;
        firework(ctx, w * (0.15 + 0.7 * hash01(n, 8)), rimY * (0.2 + 0.5 * hash01(n, 9)), audio.secondsSinceBeat + back * beatLength(audio), unit * (0.12 + 0.1 * hash01(n, 10)), rigColor(n), n, 36);
      }
      for (let i = 0; i < 6; i++) firework(ctx, w * (0.1 + 0.8 * hash01(i, hype.dropCount + 50)), rimY * (0.15 + 0.45 * hash01(i, hype.dropCount + 60)), hype.secondsSinceDrop - i * 0.18, unit * 0.2, rigColor(i + hype.dropCount), i * 13 + hype.dropCount, 44);
      over(ctx);
      ctx.beginPath(); ctx.moveTo(0, rimY - unit * 0.05); ctx.quadraticCurveTo(cx, rimY + unit * 0.08, w, rimY - unit * 0.05); ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath();
      ctx.fillStyle = lin(ctx, 0, rimY, 0, h, ['#120B22', '#07050D']); ctx.fill();
      for (const side of [-1, 1]) {
        const tx = cx + side * w * 0.42, ty = rimY - unit * 0.18;
        stroke(ctx, [[tx, ty], [tx, ty + unit * 0.15]], '#120B22', unit * 0.008);
        add(ctx); beam(ctx, tx, ty, -side * 0.55, h * 0.8, 0.12, hex(0xCFE3FF), 0.15 + 0.15 * e); glow(ctx, tx, ty, unit * 0.06, T.white, 0.7); over(ctx);
      }
      const sw = unit * 0.32, sh = unit * 0.13, sx = cx - sw / 2, sy = fieldY - unit * 0.07 - sh, color = rigColor(Math.floor(beat / 4));
      fill(ctx, '#0A0712', sx - unit * 0.006, sy - unit * 0.006, sw + unit * 0.012, sh + unit * 0.012);
      add(ctx);
      fill(ctx, (() => { const g = ctx.createRadialGradient(cx, sy + sh / 2, 0, cx, sy + sh / 2, sw * 0.6); g.addColorStop(0, rgba(color, 0.4 + 0.5 * pulse)); g.addColorStop(1, rgba(color, 0.15)); return g; })(), sx, sy, sw, sh);
      const wave = [];
      for (let i = 0; i <= 40; i++) { const t = i / 40, bin = Math.min(Math.floor(t * audio.spectrum.length), audio.spectrum.length - 1); wave.push([sx + sw * t, sy + sh / 2 - sh * 0.4 * audio.spectrum[bin] * Math.sin(t * Math.PI * 6 + beat * Math.PI)]); }
      stroke(ctx, wave, 'rgba(255,255,255,0.8)', unit * 0.003);
      over(ctx); fill(ctx, '#0A0712', cx - unit * 0.24, fieldY - unit * 0.06, unit * 0.48, unit * 0.04); add(ctx);
      for (let i = 0; i < 5; i++) { const t = i / 4; beam(ctx, cx + unit * 0.4 * (t - 0.5), fieldY - unit * 0.06, Math.PI + (t - 0.5) * 0.8 + motion(i, 5, beat) * 0.45, unit * 0.5, 0.03, color, 0.2 + 0.6 * e); }
      glow(ctx, cx, fieldY - unit * 0.1, unit * 0.5, color, 0.12 + 0.2 * e);
      const cool = new Path2D(), warm = new Path2D(), amount = 0.4 + 0.6 * audio.mid;
      for (let i = 0; i < 900; i++) {
        const depth = Math.pow(hash01(i, 11), 0.7), y = rimY + (h * 0.95 - rimY) * depth, x = hash01(i, 12) * (w + unit * 0.1) - unit * 0.05, near = 0.4 + 1.6 * depth;
        const sway = Math.sin(beat * Math.PI / 2 + x / unit * 0.6) * amount, px = x + sway * unit * 0.012 * near, py = y - Math.abs(sway) * unit * 0.004 * near, r = unit * 0.0028 * near * (0.8 + 0.4 * hash01(i, 13));
        const p = hash01(i, 14) < 0.12 ? warm : cool; p.moveTo(px + r, py); p.arc(px, py, r, 0, Math.PI * 2);
      }
      const b = 0.55 + 0.25 * e + 0.2 * pulse;
      // A wide faint stroke stands in for the blur pass.
      ctx.lineWidth = unit * 0.006; ctx.strokeStyle = rgba(hex(0xBFD8FF), b * 0.25); ctx.stroke(cool); ctx.strokeStyle = rgba(T.amber, b * 0.25); ctx.stroke(warm);
      ctx.fillStyle = `rgba(255,255,255,${b})`; ctx.fill(cool); ctx.fillStyle = rgba(hex(0xFFE6B0), b); ctx.fill(warm);
      over(ctx);
      const hands = crowd(ctx, w, unit, h * 1.04, 0.26, Math.floor(w / unit * 6) + 2, 90, rgba(T.crowd), audio, beat, 0.55 + 0.35 * e, 0.1 + 0.4 * e);
      for (const [x, y] of hands) {
        rrect(ctx, x - unit * 0.012, y - unit * 0.04, unit * 0.024, unit * 0.042, unit * 0.004); ctx.fillStyle = '#16141C'; ctx.fill();
        add(ctx); glow(ctx, x, y - unit * 0.034, unit * 0.05, T.white, 0.5 * b); over(ctx);
      }
      ctx.restore();
    },
  };
}

// ---------------------------------------------------------------- Laser Rave
function makeLaserRave() {
  const hype = new HypeMeter(), spin = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      hype.update(time, audio);
      const unit = Math.min(w, h), beat = beatProgress(audio, time), bar = Math.floor(beat / 4), e = hype.energy, pulse = audio.beatPulse, bl = beatLength(audio);
      const rot = spin.advance(time, 0.2 + 0.8 * e + 2 * hype.dropPulse), bx = w / 2, by = h * 0.56;
      const primary = bar % 2 === 0 ? T.laserGreen : T.magenta, secondary = bar % 2 === 0 ? T.ice : T.laserGreen;
      ctx.save();
      fill(ctx, '#040308', 0, 0, w, h);
      const bays = Math.max(4, Math.floor(w / (unit * 0.3)));
      for (let i = 0; i < bays; i++) fill(ctx, '#0C0A18', w * i / bays + unit * 0.04, h * 0.12, w / bays - unit * 0.08, h * 0.25);
      for (let i = 0; i <= bays; i++) fill(ctx, '#0E0C16', w * i / bays - unit * 0.008, 0, unit * 0.016, by);
      fill(ctx, '#0E0C16', 0, h * 0.07, w, unit * 0.014);
      add(ctx);
      haze(ctx, 0, h * 0.05, w, h * 0.85, primary, 0.04 + 0.08 * e + 0.12 * hype.build);
      glow(ctx, bx, by, unit * (0.4 + 0.3 * hype.build), primary, 0.15 + 0.25 * e);
      laserShow(ctx, w, h, bx, by, beat, rot, bl, hype, pulse, primary, secondary, false);
      over(ctx);
      const dark = '#030206', bob = pulse * unit * 0.006, raise = Math.max(hype.dropPulse, hype.build * 0.6);
      for (const side of [-1, 1]) {
        const sx = bx + side * unit * 0.035, sy = by - unit * 0.04 + bob;
        ctx.lineCap = 'round'; stroke(ctx, [[sx, sy], [lerp(bx + side * unit * 0.06, bx + side * unit * 0.07, raise), lerp(by + unit * 0.005, by - unit * 0.14, raise)]], dark, unit * 0.014);
      }
      dot(ctx, bx, by - unit * 0.075 + bob, unit * 0.022, dark);
      rrect(ctx, bx - unit * 0.045, by - unit * 0.05 + bob, unit * 0.09, unit * 0.07, unit * 0.02); ctx.fillStyle = dark; ctx.fill();
      fill(ctx, '#0B0912', bx - unit * 0.12, by, unit * 0.24, unit * 0.08);
      add(ctx); stroke(ctx, [[bx - unit * 0.12, by], [bx + unit * 0.12, by]], rgba(primary, 0.5 + 0.5 * pulse), unit * 0.003); over(ctx);
      [[0.8, 0.14, 24, rgb(0x0A0812)], [0.92, 0.2, 16, rgb(0x06050B)], [1.05, 0.28, 10, rgba(T.crowd)]].forEach(([base, scale, n, c], i) => {
        crowd(ctx, w, unit, h * base, scale, Math.floor(n * (w / unit) * 0.6 + 2), 120 + i * 10, c, audio, beat, 0.2 + 0.4 * e + 0.4 * hype.dropPulse, 0.3 + 0.7 * e);
      });
      const eighth = (beat * 2) % 1;
      strobe(ctx, w, h, Math.max(hype.secondsSinceDrop < bl * 8 && eighth < 0.1 ? 0.9 : 0, e > 0.75 && audio.secondsSinceBeat < 0.04 ? 0.4 : 0));
      ctx.restore();
    },
  };
}

export const concert = {
  id: 'concert', name: 'Concert', accent: T.magenta,
  wallpapers: [
    { id: 'concert.main-stage', name: 'Main Stage', summary: 'A festival stage with sweeping moving heads and an LED wall. Confetti and CO2 on the drop.', make: makeMainStage },
    { id: 'concert.headliner', name: 'Headliner', summary: 'A rock band backlit in smoke, with flame columns on the big hits.', make: makeHeadliner },
    { id: 'concert.lights-up', name: 'Lights Up', summary: 'A stadium full of phone lights swaying, with fireworks over the rim.', make: makeLightsUp },
    { id: 'concert.laser-rave', name: 'Laser Rave', summary: 'Lasers cut through warehouse fog and change shape every bar.', make: makeLaserRave },
  ],
};

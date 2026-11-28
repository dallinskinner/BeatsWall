// The rest of the BeatsWall collection: Beat B, Ripple Grid, BeatsWall Terminal, Spark Field.
import { C, rgba, mix, clamp, PhaseClock, BeatEdge, brandGradient, beatProgress } from '../kit.js';
import { lin, rad, rrect, circle, dot, glow, ell } from './draw.js';

function backdrop(ctx, w, h) { ctx.fillStyle = lin(ctx, 0, 0, w * 0.3, h, [rgba(C.navy), rgba(C.plum)]); ctx.fillRect(0, 0, w, h); }

// ---------------------------------------------------------------- Beat B
const LOGO = [[[0, 5.2]], [[0, 1.9], [4.2, 6]], [[0, 1.9], [4.4, 6.1]], [[0, 5.6]], [[0, 1.9], [4.6, 6.5]], [[0, 1.9], [4.8, 6.6]], [[0, 6]]];
function makeBeatB() {
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), pulse = audio.beatPulse, bass = audio.bass, cx = w / 2, cy = h / 2;
      backdrop(ctx, w, h);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      glow(ctx, cx, cy, unit * (0.45 + 0.25 * bass), C.magenta, 0.18 + 0.3 * bass);
      const beat = beatProgress(audio, time);
      for (let ring = 0; ring < 4; ring++) {
        const p = (ring + (beat % 1)) / 4;
        ctx.strokeStyle = rgba(brandGradient(p), 0.3 * (1 - p)); ctx.lineWidth = unit * 0.004;
        circle(ctx, cx, cy, unit * (0.3 + 0.55 * p)); ctx.stroke();
      }
      const width = unit * 0.25 * (1 + 0.05 * pulse), s = width / 6.6, rowH = s * 2.2, barH = s * 1.7;
      const ox = cx - width / 2 - s * 0.6, oy = cy - rowH * LOGO.length / 2;
      const reach = row => s * 2.4 * audio.spectrum[Math.min((LOGO.length - 1 - row) * 4 + 1, audio.spectrum.length - 1)];
      const eachBar = fn => LOGO.forEach((segs, row) => segs.forEach(([a, b], i) => fn(a, b + (i === segs.length - 1 ? reach(row) / s : 0), oy + row * rowH)));
      const bars = () => {
        ctx.beginPath();
        eachBar((a, b, y) => { const x = ox + a * s, bw = (b - a) * s, r = barH / 2; ctx.moveTo(x + r, y); ctx.arcTo(x + bw, y, x + bw, y + barH, r); ctx.arcTo(x + bw, y + barH, x, y + barH, r); ctx.arcTo(x, y + barH, x, y, r); ctx.arcTo(x, y, x + bw, y, r); ctx.closePath(); });
      };
      ctx.save(); // echo that expands and fades after each beat
      const k = 1 + 0.5 * (1 - pulse); ctx.translate(cx, cy); ctx.scale(k, k); ctx.translate(-cx, -cy);
      bars(); ctx.strokeStyle = rgba(C.magenta, 0.5 * pulse); ctx.lineWidth = s * 0.15; ctx.stroke(); ctx.restore();
      ctx.globalCompositeOperation = 'source-over';
      ctx.save(); ctx.shadowColor = rgba(C.magenta, 0.5 + 0.4 * bass); ctx.shadowBlur = unit * (0.015 + 0.04 * bass) * 2;
      bars(); ctx.fillStyle = lin(ctx, ox, cy, ox + s * 9, cy, [rgba(C.magenta), rgba(C.orange), rgba(C.yellow)]); ctx.fill(); ctx.restore();
      ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = `rgba(255,255,255,${0.18 + 0.2 * pulse})`;
      eachBar((a, b, y) => { rrect(ctx, ox + (a + 0.2) * s, y + barH * 0.15, Math.max((b - a - 0.4) * s, 0), barH * 0.22, barH * 0.1); ctx.fill(); });
      ctx.restore();
    },
  };
}

// ---------------------------------------------------------------- Ripple Grid
function makeRippleGrid() {
  const clock = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const phase = clock.advance(time, 0.6 + 3.5 * audio.mid), pulse = audio.beatPulse, cx = w / 2, cy = h / 2, maxD = Math.hypot(w, h) / 2;
      backdrop(ctx, w, h);
      const sp = Math.max(w, h) / 34, ringR = (1 - pulse) * maxD, cols = Math.floor(w / sp) + 2, rows = Math.floor(h / sp) + 2;
      const offX = (w - (cols - 1) * sp) / 2, offY = (h - (rows - 1) * sp) / 2;
      for (let row = 0; row < rows; row++) for (let col = 0; col < cols; col++) {
        const bx = offX + col * sp, by = offY + row * sp, dx = bx - cx, dy = by - cy, d = Math.max(Math.hypot(dx, dy), 0.001);
        const wave = 0.5 + 0.5 * Math.sin(d / maxD * 14 - phase), ring = Math.exp(-(((d - ringR) / (sp * 1.6)) ** 2)) * pulse;
        const b = Math.min(1, 0.05 + 0.25 * wave * (0.3 + audio.level) + 0.85 * ring), tint = brandGradient(d / maxD * 1.2);
        const push = sp * 0.6 * ring, x = bx + dx / d * push, y = by + dy / d * push, r = sp * 0.07 * (1 + 1.6 * b);
        if (b > 0.12) glow(ctx, x, y, r * 4, tint, b * b * 0.5);
        dot(ctx, x, y, r, rgba(mix(C.glow, tint, b), 0.2 + 0.8 * b));
      }
      const unit = Math.min(w, h);
      for (let i = 0; i < 3; i++) {
        const color = brandGradient(i / 2), seq = 0.5 + 0.5 * Math.sin(phase * 1.2 - i * 0.9);
        const r = unit * 0.022 * (1 + 0.5 * seq + 0.6 * audio.bass), x = cx + (i - 1) * unit * 0.075;
        glow(ctx, x, cy, r * 3.5, color, 0.25 + 0.35 * seq);
        dot(ctx, x, cy, r, rgba(mix(color, C.glow, 0.35 * seq)));
      }
    },
  };
}

// ---------------------------------------------------------------- Terminal
function makeTerminal() {
  const SPIN = '▁▂▃▄▅▆▇█▇▆▅▄▃▂';
  const VERBS = ['Vibing', 'Grooving', 'Syncopating', 'Riffing', 'Harmonizing', 'Pondering', 'Jamming', 'Noodling', 'Swaying', 'Composing'];
  return {
    draw(ctx, w, h, { time, audio }) {
      const fs = Math.min(w / 70, h / 30), dim = rgba(C.glow, 0.45);
      ctx.fillStyle = rad(ctx, w / 2, h / 2, 0, Math.max(w, h) * 0.7, [rgba(C.plum), rgba(C.navy), rgba(C.ink)]); ctx.fillRect(0, 0, w, h);
      const bw = fs * 46, bh = fs * 27.5, x = (w - bw) / 2, y = (h - bh) / 2, left = x + fs * 1.2, inner = bw - fs * 2.4;
      ctx.save(); ctx.shadowColor = rgba(C.magenta, 0.25 + 0.3 * audio.beatPulse); ctx.shadowBlur = fs * 1.6;
      rrect(ctx, x, y, bw, bh, fs * 0.8); ctx.fillStyle = rgba(C.ink, 0.85); ctx.fill(); ctx.restore();
      ctx.strokeStyle = rgba(C.glow, 0.12); ctx.lineWidth = 1; ctx.stroke();
      ctx.save(); ctx.textBaseline = 'middle'; ctx.textAlign = 'left';
      ctx.font = `${fs}px ui-monospace, Menlo, monospace`;
      const text = (parts, tx, ty) => { for (const [str, color, bold] of parts) { ctx.font = `${bold ? 'bold ' : ''}${fs}px ui-monospace, Menlo, monospace`; ctx.fillStyle = color; ctx.fillText(str, tx, ty); tx += ctx.measureText(str).width || 0; } };
      let ty = y + fs * 1.9;
      for (let i = 0; i < 3; i++) dot(ctx, left + fs * 0.35 + i * fs * 1.1, ty, fs * 0.35, rgba(C.glow, 0.18));
      ctx.textAlign = 'center'; ctx.fillStyle = dim; ctx.fillText('beatswall — ~/Music — 80×24', x + bw / 2, ty); ctx.textAlign = 'left';
      ty += fs * 1.5;
      rrect(ctx, left, ty, inner, fs * 5.6, fs * 0.4);
      ctx.strokeStyle = lin(ctx, left, ty, left + inner, ty, [rgba(C.magenta), rgba(C.orange), rgba(C.yellow)]); ctx.lineWidth = Math.max(1, fs * 0.08); ctx.stroke();
      text([['▌▌ ', rgba(C.magenta)], ['Welcome to BeatsWall!', rgba(C.glow), true]], left + fs * 0.7, ty + fs * 1.4);
      text([['   /help for help, /drop to wait for the drop', dim]], left + fs * 0.7, ty + fs * 2.9);
      text([['   cwd: ~/Music', dim]], left + fs * 0.7, ty + fs * 4.3);
      ty += fs * 7.2; text([['> play something loud', rgba(C.glow)]], left, ty);
      ty += fs * 1.4;
      const ROWS = 10, cell = inner * 0.97 / audio.spectrum.length, rowH = fs * 1.05;
      for (let row = 0; row < ROWS; row++) {
        ctx.fillStyle = rgba(brandGradient(1 - row / (ROWS - 1)));
        audio.spectrum.forEach((v, i) => {
          const fill = Math.round(clamp(v * ROWS - (ROWS - 1 - row)) * 8) / 8;
          if (fill > 0) ctx.fillRect(left + i * cell, ty + rowH * (row + 1 - fill), cell + 0.5, rowH * fill + 0.5);
        });
      }
      ty += rowH * ROWS + fs * 1.3;
      const meter = v => { const f = Math.round(v * 8); return ' ▕' + '█'.repeat(f) + '░'.repeat(8 - f) + '▏'; };
      text([['level', dim], [meter(audio.level), rgba(C.orange)], ['  bass', dim], [meter(audio.bass), rgba(C.orange)], ['  treble', dim], [meter(audio.treble), rgba(C.orange)]], left, ty);
      ty += fs * 1.8;
      const spin = SPIN[(audio.beatCount + Math.floor(time * 4)) % SPIN.length], verb = VERBS[Math.floor(audio.beatCount / 8) % VERBS.length];
      text([[`${spin} ${verb}…`, rgba(C.magenta)], [` (${Math.round(audio.bpm)} bpm · esc to interrupt)`, dim]], left, ty);
      ty += fs * 1.2;
      rrect(ctx, left, ty, inner, fs * 2, fs * 0.4); ctx.strokeStyle = rgba(C.glow, 0.25); ctx.lineWidth = Math.max(1, fs * 0.06); ctx.stroke();
      const cursor = time % 1 < 0.55 || audio.beatPulse > 0.5;
      text([['> ', dim], [cursor ? '█' : ' ', rgba(C.glow)]], left + fs * 0.6, ty + fs);
      ctx.restore();
      const period = Math.max(2, fs / 6) * 2; ctx.fillStyle = 'rgba(0,0,0,0.16)'; // scanlines
      for (let sy = (time * 12) % period; sy < h; sy += period) ctx.fillRect(0, sy, w, period / 2);
    },
  };
}

// ---------------------------------------------------------------- Spark Field
function makeSparkField() {
  const P = Array.from({ length: 700 }, () => ({ x: Math.random() * 1.8, y: Math.random(), vx: 0, vy: 0, bx: 0, by: 0, bvx: 0, bvy: 0, size: Math.random() ** 2, seed: Math.random() }));
  const clock = new PhaseClock(), edge = new BeatEdge();
  return {
    draw(ctx, w, h, { time: t, audio }) {
      const aspect = w / Math.max(h, 1);
      clock.advance(t);
      const dt = Math.min(clock.deltaTime, 1 / 20), isBeat = edge.isNewBeat(audio);
      const speed = 0.015 + 0.12 * audio.treble + 0.05 * audio.mid, burst = 0.25 + 0.6 * audio.bass;
      backdrop(ctx, w, h);
      glow(ctx, w / 2, h / 2, h * (0.35 + 0.25 * audio.bass), C.magenta, 0.1 + 0.25 * audio.bass);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (const p of P) {
        const diag = 0.6 * 1.3 * Math.cos((p.x + p.y) * 1.3 + t * 0.11);
        const dX = 0.8 * 2.1 * Math.cos(p.x * 2.1 + t * 0.07) + diag, dY = -0.7 * 2.7 * Math.sin(p.y * 2.7 - t * 0.05) + diag;
        const ease = Math.min(1, dt * 1.5);
        p.vx += (dY / 3 * speed - p.vx) * ease; p.vy += (-dX / 3 * speed - p.vy) * ease;
        if (isBeat) {
          const dx = p.x - aspect / 2, dy = p.y - 0.5, d = Math.max(Math.hypot(dx, dy), 0.05), imp = 0.6 * burst * (0.5 + p.seed) / (0.5 + d * 2);
          p.bvx += dx / d * imp; p.bvy += dy / d * imp;
        }
        p.bvx += (-18 * p.bx - 6 * p.bvx) * dt; p.bvy += (-18 * p.by - 6 * p.bvy) * dt;
        p.bx += p.bvx * dt; p.by += p.bvy * dt; p.x += p.vx * dt; p.y += p.vy * dt;
        if (p.x < -0.05) p.x += aspect + 0.1; if (p.x > aspect + 0.05) p.x -= aspect + 0.1;
        if (p.y < -0.05) p.y += 1.1; if (p.y > 1.05) p.y -= 1.1;
        const x = (p.x + p.bx) * h, y = (p.y + p.by) * h, heat = Math.min(1, Math.hypot(p.vx + p.bvx, p.vy + p.bvy) / 0.35);
        const tw = 0.7 + 0.3 * Math.sin(t * 3 + p.seed * 40), r = h * (0.002 + 0.004 * p.size) * (1 + 0.7 * audio.beatPulse);
        ctx.fillStyle = rgba(mix(brandGradient(p.seed), C.glow, heat * 0.7), (0.6 + 0.4 * heat) * tw);
        if (p.size > 0.65) {
          const s = r * 2.6, k = s * 0.22;
          ctx.beginPath(); ctx.moveTo(x, y - s);
          ctx.quadraticCurveTo(x + k, y - k, x + s, y); ctx.quadraticCurveTo(x + k, y + k, x, y + s);
          ctx.quadraticCurveTo(x - k, y + k, x - s, y); ctx.quadraticCurveTo(x - k, y - k, x, y - s); ctx.fill();
        } else { circle(ctx, x, y, r); ctx.fill(); }
      }
      ctx.restore();
    },
  };
}

export const beatB = { id: 'beatswall.beat-b', name: 'Beat B', summary: 'The BeatsWall B, built from equalizer bars that stretch with the spectrum and flare on every kick.', make: makeBeatB };
export const rippleGrid = { id: 'beatswall.ripple-grid', name: 'Ripple Grid', summary: 'A field of glowing dots. Ripples follow the melody and rings bloom out on the beat.', make: makeRippleGrid };
export const terminal = { id: 'beatswall.terminal', name: 'BeatsWall Terminal', summary: 'A late-night terminal with a block-character spectrum analyzer and a spinner that keeps time.', make: makeTerminal };
export const sparkField = { id: 'beatswall.spark-field', name: 'Spark Field', summary: 'Hundreds of tiny sparks drifting on the hi-hats and bursting outward on the kick.', make: makeSparkField };

// Deep Sea collection, ported from BeatsWall/Collections/DeepSea/*.swift. Film grain is omitted.
import { PhaseClock, BeatEdge, hash01, hex, rgba, mix, beatProgress } from '../kit.js';
import { lin, rad, circle, lines } from './draw.js';

const T = {
  abyss: hex(0x02060F), deep: hex(0x04142A), midwater: hex(0x0A2A4A), shallow: hex(0x14506E),
  cyan: hex(0x5CF2FF), pink: hex(0xFF6FD8), violet: hex(0x8B6BFF), lure: hex(0xB8FFEC),
};
const c = rgba, H = hex, WHITE = [255, 255, 255];

function glow(ctx, x, y, radius, color, opacity) {
  ctx.fillStyle = rad(ctx, x, y, 0, radius, [c(color, opacity), c(color, 0)]);
  circle(ctx, x, y, radius); ctx.fill();
}

/** Slanted shafts of light from the surface, slowly wavering. */
function drawGodRays(ctx, w, h, time, intensity) {
  const unit = Math.min(w, h);
  ctx.save(); ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 6; i++) {
    const x = w * (0.1 + 0.16 * i) + unit * 0.05 * Math.sin(time * 0.15 + i);
    const width = unit * (0.05 + 0.08 * hash01(i, 3)), length = h * (0.6 + 0.4 * hash01(i, 4));
    const shimmer = 0.6 + 0.4 * Math.sin(time * (0.3 + 0.2 * hash01(i, 5)) + i * 2), ray = H(0x9FE8FF);
    ctx.fillStyle = lin(ctx, x, 0, x + length * 0.25, length, [c(ray, 0.12 * intensity * shimmer), c(ray, 0)]);
    lines(ctx, [[x, 0], [x + width, 0], [x + width * 2.5 + length * 0.25, length], [x + length * 0.25, length]], true); ctx.fill();
  }
  ctx.restore();
}

/** Drifting specks of marine snow. */
function drawMarineSnow(ctx, w, h, time, count, brightness = 0.5) {
  const unit = Math.min(w, h);
  ctx.fillStyle = c(H(0xCFE8FF), brightness); ctx.beginPath();
  for (let i = 0; i < count; i++) {
    const fall = (hash01(i, 21) + time * (0.004 + 0.01 * hash01(i, 22))) % 1;
    const x = hash01(i, 23) * w + unit * 0.02 * Math.sin(time * 0.3 + i), r = unit * 0.0012 * (0.5 + hash01(i, 24));
    ctx.moveTo(x + r, fall * h); ctx.arc(x, fall * h, r, 0, Math.PI * 2);
  }
  ctx.fill();
}

// ---------------------------------------------------------------- Jellyfish Bloom
function makeJellyfishBloom() {
  const COLORS = [T.cyan, T.pink, T.violet];
  const count = 8, clock = new PhaseClock(), edge = new BeatEdge();
  const jellies = Array.from({ length: count }, (_, i) => ({
    x: 0.08 + Math.random() * 0.84, y: 0.2 + Math.random() * 0.8, vy: 0, contract: 0,
    depth: i / Math.max(count - 1, 1), seed: Math.random(), colorIndex: i % 3,
  }));
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h);
      // Jellies drift slowly down and push upward on the beat.
      clock.advance(time);
      const dt = clock.deltaTime, beat = edge.isNewBeat(audio);
      jellies.forEach((j, i) => {
        if (beat && hash01(i, audio.beatCount) > 0.35) { j.contract = 1; j.vy -= 0.05 + 0.08 * audio.bass; }
        j.contract *= Math.exp(-dt * 4);
        j.vy += (0.008 - j.vy) * Math.min(1, dt * 1.5);
        j.y += j.vy * dt;
        j.x += Math.sin(time * 0.2 + j.seed * 20) * 0.004 * dt;
        if (j.y < -0.25) { j.y = 1.15; j.x = 0.08 + Math.random() * 0.84; }
        if (j.y > 1.3) j.y = -0.2;
      });

      ctx.fillStyle = lin(ctx, 0, 0, 0, h, [c(T.midwater), c(T.deep), c(T.abyss)]); ctx.fillRect(0, 0, w, h);
      drawGodRays(ctx, w, h, time, 0.7);
      drawMarineSnow(ctx, w, h, time, 160);

      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (const j of [...jellies].sort((a, b) => a.depth - b.depth)) { // far jellies first
        const cx = j.x * w, cy = j.y * h, width = unit * (0.06 + 0.1 * j.depth), contract = j.contract;
        const bw = width * (1 - 0.22 * contract), bh = width * 0.75 * (1 + 0.18 * contract);
        const color = COLORS[j.colorIndex], opacity = 0.35 + 0.45 * j.depth;

        ctx.strokeStyle = c(color, 0.25 * opacity); ctx.lineWidth = Math.max(1, width * 0.02); ctx.lineCap = 'butt'; ctx.beginPath(); // tentacles
        for (let s = 0; s < 7; s++) {
          const sx = cx - bw * 0.42 + bw * 0.84 * s / 6;
          ctx.moveTo(sx, cy);
          for (let k = 1; k <= 16; k++) { const t = k / 16; ctx.lineTo(sx + Math.sin(time * 1.6 - t * 5 + s + j.seed * 10) * width * 0.12 * t, cy + width * 2.2 * t); }
        }
        ctx.stroke();
        ctx.strokeStyle = c(color, 0.4 * opacity); ctx.lineWidth = width * 0.06; ctx.lineCap = 'round'; ctx.beginPath(); // oral arms
        for (const side of [-1, 1]) {
          const ax = cx + side * bw * 0.1; ctx.moveTo(ax, cy);
          for (let k = 1; k <= 12; k++) { const t = k / 12; ctx.lineTo(ax + Math.sin(time * 1.2 - t * 4 + side + j.seed * 5) * width * 0.1, cy + width * 1.2 * t); }
        }
        ctx.stroke();

        const bell = () => { // a dome with a scalloped rim
          ctx.beginPath(); ctx.moveTo(cx - bw / 2, cy);
          ctx.bezierCurveTo(cx - bw / 2, cy - bh * 1.3, cx + bw / 2, cy - bh * 1.3, cx + bw / 2, cy);
          for (let i = 8; i > 0; i--) {
            const x0 = cx - bw / 2 + bw * (i - 1) / 8, x1 = cx - bw / 2 + bw * i / 8;
            ctx.quadraticCurveTo((x0 + x1) / 2, cy + width * 0.06, x0, cy);
          }
          ctx.closePath();
        };
        glow(ctx, cx, cy - bh * 0.4, width * (1.2 + 0.6 * contract), color, (0.2 + 0.35 * contract) * opacity);
        ctx.fillStyle = rad(ctx, cx, cy - bh * 0.5, 0, bw * 0.6, [c(color, 0.5 * opacity), c(color, 0.12 * opacity)]); bell(); ctx.fill();
        ctx.strokeStyle = c(mix(color, WHITE, 0.4), 0.7 * opacity); ctx.lineWidth = Math.max(1, width * 0.025); bell(); ctx.stroke();
      }
      ctx.restore();
    },
  };
}

// ---------------------------------------------------------------- Whale Song
function makeWhaleSong() {
  const clock = new PhaseClock(), edge = new BeatEdge();
  const rings = []; let swirl = 0, lastRing = -100;
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h);
      clock.advance(time);
      swirl += clock.deltaTime * (0.3 + 1.2 * audio.level);
      if ((edge.isNewBeat(audio) && audio.mid > 0.35) || time - lastRing > 3) { rings.push({ born: time, strength: 0.4 + 0.6 * audio.mid }); lastRing = time; }
      for (let i = rings.length - 1; i >= 0; i--) if (time - rings[i].born > 4) rings.splice(i, 1);

      ctx.fillStyle = lin(ctx, 0, 0, 0, h, [c(T.shallow), c(T.midwater), c(T.deep)]); ctx.fillRect(0, 0, w, h);
      drawGodRays(ctx, w, h, time, 1.2);
      drawMarineSnow(ctx, w, h, time, 120, 0.35);

      // The whale glides across over about a minute, bobbing gently.
      const length = w * 0.62, cycle = (time / 70) % 1;
      const hx = -length * 0.2 + cycle * (w + length * 1.2), hy = h * 0.5 + unit * 0.03 * Math.sin(time * 0.3);

      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.lineWidth = Math.max(1, unit * 0.003); // song rings
      for (const r of rings) {
        const age = time - r.born;
        ctx.strokeStyle = c(T.cyan, 0.35 * Math.max(0, 1 - age / 4) * r.strength);
        circle(ctx, hx + length * 0.02, hy, unit * (0.05 + age * 0.22)); ctx.stroke();
      }
      ctx.restore();

      // The whale.
      const height = length * 0.18;
      const fluke = Math.sin(beatProgress(audio, time) * Math.PI / 2) * height * 0.5; // tail beats once every four beats
      const trx = hx - length * 0.82, try_ = hy - height * 0.05;
      const body = () => {
        ctx.beginPath(); ctx.moveTo(hx, hy);
        ctx.bezierCurveTo(hx - length * 0.02, hy - height * 0.5, hx - length * 0.2, hy - height * 0.62, hx - length * 0.45, hy - height * 0.55);
        ctx.bezierCurveTo(hx - length * 0.62, hy - height * 0.5, hx - length * 0.75, hy - height * 0.2, trx, try_ + fluke * 0.3 - height * 0.08);
        ctx.lineTo(trx, try_ + fluke * 0.3 + height * 0.06);
        ctx.bezierCurveTo(hx - length * 0.7, hy + height * 0.2, hx - length * 0.5, hy + height * 0.48, hx - length * 0.35, hy + height * 0.5);
        ctx.bezierCurveTo(hx - length * 0.15, hy + height * 0.52, hx - length * 0.01, hy + height * 0.3, hx, hy);
        ctx.closePath();
      };
      const tx = trx - length * 0.04, ty = try_ + fluke;
      ctx.fillStyle = c(H(0x0B2236)); ctx.beginPath(); ctx.moveTo(trx, try_ + fluke * 0.3);
      ctx.quadraticCurveTo(tx + length * 0.01, ty - height * 0.3, tx - length * 0.08, ty - height * 0.45);
      ctx.quadraticCurveTo(tx - length * 0.05, ty - height * 0.1, tx, ty);
      ctx.quadraticCurveTo(tx - length * 0.05, ty + height * 0.1, tx - length * 0.08, ty + height * 0.45);
      ctx.quadraticCurveTo(tx + length * 0.01, ty + height * 0.3, trx, try_ + fluke * 0.3);
      ctx.closePath(); ctx.fill();
      ctx.fillStyle = lin(ctx, hx, hy - height * 0.6, hx, hy + height * 0.5, [c(H(0x0A1C2E)), c(H(0x1C3E58))]); body(); ctx.fill();
      ctx.save(); body(); ctx.clip(); // throat grooves and light from above
      ctx.strokeStyle = c(H(0x4F7A96), 0.5); ctx.lineWidth = Math.max(1, length * 0.002); ctx.beginPath();
      for (let g = 0; g < 6; g++) { const y = hy + height * (0.18 + 0.05 * g); ctx.moveTo(hx - length * 0.02, y); ctx.lineTo(hx - length * 0.32, y + height * 0.06); }
      ctx.stroke();
      ctx.fillStyle = lin(ctx, hx, hy - height * 0.6, hx, hy, [c(H(0x9FE8FF), 0.12), c(H(0x9FE8FF), 0)]); body(); ctx.fill();
      ctx.restore();
      const fx = hx - length * 0.22, fy = hy + height * 0.35, swing = Math.sin(time * 0.8) * height * 0.15;
      ctx.fillStyle = c(H(0x14324A)); ctx.beginPath(); ctx.moveTo(fx, fy);
      ctx.quadraticCurveTo(fx - length * 0.05, fy + height * 0.6, fx - length * 0.2, fy + height * 0.75 + swing);
      ctx.quadraticCurveTo(fx - length * 0.12, fy + height * 0.4, fx - length * 0.06, fy); ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,0.8)'; circle(ctx, hx - length * 0.12, hy + height * 0.02, length * 0.006); ctx.fill();

      // A school of small fish swirling around a wandering center.
      const sx = w * (0.5 + 0.3 * Math.sin(time * 0.07)), sy = h * (0.25 + 0.1 * Math.sin(time * 0.11));
      ctx.fillStyle = c(H(0xBFE6F2), 0.55 + 0.3 * audio.treble); ctx.beginPath();
      for (let i = 0; i < 70; i++) {
        const orbit = unit * (0.04 + 0.12 * hash01(i, 1)), angle = swirl * (1.2 - 0.6 * hash01(i, 2)) + hash01(i, 3) * 2 * Math.PI;
        const wobble = unit * 0.015 * Math.sin(time * 2 + i);
        const px = sx + Math.cos(angle) * (orbit + wobble), py = sy + Math.sin(angle) * (orbit + wobble) * 0.45;
        const heading = angle + Math.PI / 2, fl = unit * 0.012, dx = Math.cos(heading), dy = Math.sin(heading) * 0.45, nx = -dy, ny = dx;
        ctx.moveTo(px + dx * fl, py + dy * fl);
        ctx.quadraticCurveTo(px + nx * fl * 0.5, py + ny * fl * 0.5, px - dx * fl, py - dy * fl);
        ctx.lineTo(px - dx * fl * 1.5 + nx * fl * 0.4, py - dy * fl * 1.5 + ny * fl * 0.4);
        ctx.lineTo(px - dx * fl * 1.5 - nx * fl * 0.4, py - dy * fl * 1.5 - ny * fl * 0.4);
        ctx.lineTo(px - dx * fl, py - dy * fl);
        ctx.quadraticCurveTo(px - nx * fl * 0.5, py - ny * fl * 0.5, px + dx * fl, py + dy * fl);
      }
      ctx.fill();
    },
  };
}

// ---------------------------------------------------------------- Abyss Lure
function makeAbyssLure() {
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h);
      ctx.fillStyle = c(H(0x010307)); ctx.fillRect(0, 0, w, h);

      // The fish drifts slowly closer and away.
      const approach = 0.5 + 0.5 * Math.sin(time * 0.06), scale = unit * (0.55 + 0.2 * approach);
      const cx = w * (0.42 + 0.06 * Math.sin(time * 0.09)), cy = h * 0.55 + unit * 0.02 * Math.sin(time * 0.4);
      // Lure: dangles ahead on a curved rod, glowing with the bass.
      const rbx = cx + scale * 0.12, rby = cy - scale * 0.32, sway = Math.sin(time * 0.9) * scale * 0.03;
      const lx = cx + scale * 0.52 + sway, ly = cy - scale * 0.38 + Math.sin(time * 1.3) * scale * 0.02;
      const glowAmt = Math.min(1, (0.35 + 0.65 * audio.bass) * (0.9 + 0.1 * Math.sin(time * 17)));

      ctx.save(); ctx.globalCompositeOperation = 'lighter'; // far-off creatures blinking, then the lure's light
      for (let i = 0; i < 10; i++) {
        const blink = Math.pow(Math.max(0, Math.sin(time * (0.4 + hash01(i, 1)) + i * 3)), 8);
        glow(ctx, hash01(i, 2) * w, hash01(i, 3) * h, unit * 0.012, i % 2 === 0 ? T.cyan : T.pink, 0.6 * blink);
      }
      glow(ctx, lx, ly, unit * (0.35 + 0.25 * glowAmt), T.lure, 0.18 * glowAmt);
      ctx.restore();

      // The angler: big round head, gaping jaw, small tapering body.
      const gape = scale * (0.06 + 0.05 * audio.level);
      ctx.beginPath(); ctx.moveTo(cx + scale * 0.32, cy - scale * 0.12);
      ctx.bezierCurveTo(cx + scale * 0.25, cy - scale * 0.45, cx - scale * 0.25, cy - scale * 0.38, cx - scale * 0.42, cy - scale * 0.05);
      ctx.lineTo(cx - scale * 0.62, cy - scale * 0.16); ctx.lineTo(cx - scale * 0.6, cy + scale * 0.14); ctx.lineTo(cx - scale * 0.42, cy + scale * 0.06);
      ctx.bezierCurveTo(cx - scale * 0.25, cy + scale * 0.32, cx + scale * 0.2, cy + scale * 0.32, cx + scale * 0.36, cy + scale * 0.16);
      ctx.lineTo(cx + scale * 0.18, cy + scale * 0.02 + gape); ctx.lineTo(cx + scale * 0.34, cy - scale * 0.06); ctx.closePath();
      ctx.fillStyle = rad(ctx, cx + (lx - cx) * 0.75, cy + (ly - cy) * 0.75, 0, scale * 0.9, [c(H(0x2C4A52), 0.25 + 0.6 * glowAmt), c(H(0x0A141A)), c(H(0x020509))]);
      ctx.fill();

      ctx.fillStyle = c(H(0xBFD3CF), 0.3 + 0.5 * glowAmt); ctx.beginPath(); // needle teeth along the jaw
      for (let i = 0; i < 7; i++) {
        const t = i / 6, ux = cx + scale * (0.33 - 0.15 * t), uy = cy - scale * (0.06 - 0.08 * t);
        ctx.moveTo(ux - scale * 0.008, uy); ctx.lineTo(ux, uy + scale * 0.05); ctx.lineTo(ux + scale * 0.008, uy);
        const lwx = cx + scale * (0.35 - 0.17 * t), lwy = cy + scale * 0.16 - (scale * 0.14 - gape) * t;
        ctx.moveTo(lwx - scale * 0.008, lwy); ctx.lineTo(lwx, lwy - scale * 0.045); ctx.lineTo(lwx + scale * 0.008, lwy);
      }
      ctx.fill();
      const ex = cx + scale * 0.12, ey = cy - scale * 0.2; // a dim, glassy eye catching the light
      ctx.fillStyle = c(H(0x0F1E24)); circle(ctx, ex, ey, scale * 0.03); ctx.fill();
      ctx.fillStyle = c(T.lure, 0.4 + 0.5 * glowAmt); circle(ctx, ex + scale * 0.008, ey - scale * 0.008, scale * 0.008); ctx.fill();
      const frx = cx - scale * 0.12, fry = cy + scale * 0.12, flap = Math.sin(time * 1.5) * scale * 0.03; // ragged fins
      ctx.fillStyle = c(H(0x0E1B21), 0.9);
      lines(ctx, [[frx, fry], [frx - scale * 0.12, fry + scale * 0.12 + flap], [frx - scale * 0.06, fry + scale * 0.04 + flap], [frx - scale * 0.14, fry + scale * 0.05 + flap]], true); ctx.fill();

      ctx.strokeStyle = c(H(0x1C2A33)); ctx.lineWidth = scale * 0.012; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(rbx, rby); ctx.quadraticCurveTo(rbx + scale * 0.15, rby - scale * 0.28, lx, ly); ctx.stroke();
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      glow(ctx, lx, ly, scale * 0.08, T.lure, 0.8 * glowAmt);
      ctx.fillStyle = c(mix(T.lure, WHITE, 0.5), 0.5 + 0.5 * glowAmt); circle(ctx, lx, ly, scale * 0.022); ctx.fill();

      // Plankton glinting in the light, more with the hi-hats.
      ctx.fillStyle = c(T.lure, 0.8); ctx.beginPath();
      for (let i = 0; i < 220; i++) {
        const x = ((hash01(i, 32) + time * (0.01 + 0.02 * hash01(i, 31))) % 1) * w, y = hash01(i, 33) * h;
        const lit = Math.max(0, 1 - (Math.hypot(x - lx, y - ly) / unit) / 0.5);
        const twinkle = hash01(i, Math.trunc(time * 5)) < 0.2 + 0.6 * audio.treble ? 1 : 0.3;
        if (lit * twinkle > 0.08) { const r = unit * 0.0018 * (0.6 + lit); ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, Math.PI * 2); }
      }
      ctx.fill();
      ctx.restore();
    },
  };
}

export const deepsea = {
  id: 'deepsea', name: 'Deep Sea', accent: T.cyan,
  wallpapers: [
    { id: 'deepsea.jellyfish-bloom', name: 'Jellyfish Bloom', summary: 'Glowing jellyfish pulse their bells and swim upward on the beat, trailing waving tentacles.', make: makeJellyfishBloom },
    { id: 'deepsea.whale-song', name: 'Whale Song', summary: 'A humpback glides through shafts of light, singing rings into the water with the melody.', make: makeWhaleSong },
    { id: 'deepsea.abyss-lure', name: 'Abyss Lure', summary: 'An anglerfish drifts out of the dark, its lure glowing with the bass while plankton glint around it.', make: makeAbyssLure },
  ],
};

// Space collection, ported from BeatsWall/Collections/Space/*.swift.
// The nebula's Metal shader is rendered per pixel at low resolution and scaled up. Film grain is omitted.
import { PhaseClock, hash01, hex, rgba, mix, smoothstep, beatLength, fbm, clamp } from '../kit.js';

const T = { void: hex(0x05060F), deep: hex(0x1A1035), violet: hex(0x5B2A86), pink: hex(0xE0479E), teal: hex(0x2EC4B6), ice: hex(0xBFE6FF) };
const WHITE = [255, 255, 255];

/** A fixed starfield: twinkles with the treble, with four-point flares on some beats (SpaceTheme.drawStars). */
function drawStars(ctx, w, h, count, audio, time, drift = 0) {
  const unit = Math.min(w, h), dim = [], bright = [], flares = [];
  for (let i = 0; i < count; i++) {
    const depth = 0.3 + 0.7 * hash01(i, 203);
    const rawX = hash01(i, 201) * w - drift * depth;
    const x = rawX - Math.floor(rawX / w) * w, y = hash01(i, 202) * h;
    const shimmer = 0.5 + 0.5 * Math.sin(time * (0.7 + 2.5 * hash01(i, 204)) + i);
    const r = unit * 0.0016 * depth * (0.6 + shimmer * (0.4 + audio.treble));
    (shimmer > 0.6 ? bright : dim).push(x, y, r);
    if (hash01(i, audio.beatCount) > 0.96) flares.push(x, y, unit * 0.012 * audio.beatPulse * depth);
  }
  const dots = (list, color) => {
    ctx.fillStyle = color; ctx.beginPath();
    for (let i = 0; i < list.length; i += 3) { ctx.moveTo(list[i] + list[i + 2], list[i + 1]); ctx.arc(list[i], list[i + 1], list[i + 2], 0, Math.PI * 2); }
    ctx.fill();
  };
  dots(dim, 'rgba(255,255,255,0.5)'); dots(bright, 'rgba(255,255,255,0.95)');
  ctx.strokeStyle = rgba(T.ice, 0.9); ctx.lineWidth = Math.max(1, unit * 0.0012); ctx.lineCap = 'round';
  ctx.beginPath();
  for (let i = 0; i < flares.length; i += 3) {
    const [x, y, f] = [flares[i], flares[i + 1], flares[i + 2]];
    ctx.moveTo(x - f, y); ctx.lineTo(x + f, y); ctx.moveTo(x, y - f); ctx.lineTo(x, y + f);
  }
  ctx.stroke();
}

function radial(ctx, cx, cy, r0, r1, stops) {
  const g = ctx.createRadialGradient(cx, cy, r0, cx, cy, r1);
  stops.forEach(([t, c]) => g.addColorStop(t, c));
  return g;
}

function makeWarpDrive() {
  const spawn = z => {
    const angle = Math.random() * Math.PI * 2, radius = 0.06 + Math.random() * 1.34;
    return { x: Math.cos(angle) * radius, y: Math.sin(angle) * radius, z, tint: Math.random() };
  };
  const stars = Array.from({ length: 650 }, () => spawn(0.05 + Math.random() * 0.95));
  let speed = 0.2;
  const clock = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), cx = w / 2, cy = h / 2, pulse = audio.beatPulse;
      clock.advance(time);
      const target = 0.12 + 0.55 * audio.level + 1.3 * pulse * pulse;
      speed += (target - speed) * Math.min(1, clock.deltaTime * 6);
      for (let i = 0; i < stars.length; i++) {
        stars[i].z -= speed * clock.deltaTime;
        if (stars[i].z < 0.03) stars[i] = spawn(1);
      }

      ctx.fillStyle = radial(ctx, cx, cy, 0, Math.max(w, h) * 0.6, [[0, rgba(T.deep)], [1, rgba(T.void)]]);
      ctx.fillRect(0, 0, w, h);
      const core = unit * (0.12 + 0.12 * audio.bass);
      ctx.fillStyle = radial(ctx, cx, cy, 0, core, [[0, rgba(T.violet, 0.5)], [1, rgba(T.violet, 0)]]);
      ctx.fillRect(cx - core, cy - core, core * 2, core * 2);

      // Each star streaks from where it was a moment ago to where it is now.
      const projection = unit * 0.5, streak = 0.02 + speed * 0.05;
      ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round';
      for (const s of stars) {
        const tail = Math.min(s.z + streak, 1);
        const hx = cx + (s.x / s.z) * projection, hy = cy + (s.y / s.z) * projection;
        const bx = cx + (s.x / tail) * projection, by = cy + (s.y / tail) * projection;
        if (hx < -50 || hx > w + 50 || hy < -50 || hy > h + 50) continue;
        const nearness = 1 - s.z;
        ctx.strokeStyle = rgba(mix(WHITE, s.tint > 0.5 ? T.ice : T.pink, 0.25 + 0.3 * s.tint), Math.min(1, nearness * 1.6));
        ctx.lineWidth = Math.max(0.7, unit * 0.004 * nearness);
        ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(hx, hy); ctx.stroke();
      }
      ctx.globalCompositeOperation = 'source-over';
      if (pulse > 0.05) { ctx.fillStyle = `rgba(255,255,255,${0.14 * Math.pow(pulse, 3) * audio.bass})`; ctx.fillRect(0, 0, w, h); }
    },
  };
}

function makeNebula() {
  const flow = new PhaseClock();
  let off = null, octx = null, img = null;
  return {
    draw(ctx, w, h, { time, audio }) {
      const phase = flow.advance(time, 0.4 + 2.2 * audio.mid);
      const gh = 72, gw = Math.max(2, Math.round(gh * w / h));
      if (typeof document !== 'undefined') {
        if (!off || off.width !== gw || off.height !== gh) {
          off = document.createElement('canvas'); off.width = gw; off.height = gh;
          octx = off.getContext('2d'); img = octx.createImageData(gw, gh);
        }
        const [A, B, C, V] = [T.violet, T.pink, T.teal, T.void], energy = audio.bass, d = img.data;
        for (let j = 0; j < gh; j++) {
          for (let i = 0; i < gw; i++) {
            const ux = ((i + 0.5) / gw * w) / h, uy = ((j + 0.5) / gh * h) / h;
            const qx = fbm(ux * 1.6 + phase * 0.05, uy * 1.6 + phase * 0.05);
            const qy = fbm(ux * 1.6 + 5.2 - phase * 0.04, uy * 1.6 + 1.3 - phase * 0.04);
            const n = fbm(ux * 2.2 + qx * 1.8 + phase * 0.02, uy * 2.2 + qy * 1.8 + phase * 0.02);
            const gas = mix(mix(A, B, smoothstep(0.3, 0.75, n)), C, smoothstep(0.5, 0.95, qx * n * 1.7));
            const density = smoothstep(0.28, 0.8, n), bright = (0.4 + 0.9 * n * n) * (0.75 + 0.6 * energy);
            const o = (j * gw + i) * 4;
            for (let k = 0; k < 3; k++) d[o + k] = clamp(V[k] + (gas[k] * bright - V[k]) * density, 0, 255);
            d[o + 3] = 255;
          }
        }
        octx.putImageData(img, 0, 0);
        ctx.imageSmoothingEnabled = true; ctx.drawImage(off, 0, 0, w, h);
      } else { ctx.fillStyle = rgba(T.void); ctx.fillRect(0, 0, w, h); }
      ctx.globalCompositeOperation = 'lighter';
      drawStars(ctx, w, h, 260, audio, time, phase * Math.min(w, h) * 0.004);
      ctx.globalCompositeOperation = 'source-over';
    },
  };
}

function makeRingedPlanet() {
  const TILT = -0.32, FLATTEN = 0.28, RING_COUNT = 26;
  const RING_COLORS = [0xE8C9A0, 0xC9A27E, 0xF2E3C6, 0xB08968].map(hex);
  const MOONS = [{ distance: 2.7, size: 0.13, offset: 0, color: hex(0xBFC6D1) }, { distance: 3.4, size: 0.08, offset: 2.4, color: hex(0xD9A27E) }];
  const BANDS = [[-0.85, 0.2, 0xE8C9A0], [-0.55, 0.12, 0xB86F45], [-0.3, 0.18, 0xF2D2A9], [0, 0.1, 0xA65A3A], [0.2, 0.22, 0xE5B585], [0.5, 0.1, 0xB86F45], [0.72, 0.18, 0xEED3B0]];
  const orbit = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), cx = w / 2, cy = h / 2, radius = unit * 0.17;
      const angle = orbit.advance(time, 2 * Math.PI / (16 * beatLength(audio))); // moons orbit every 16 beats

      ctx.fillStyle = radial(ctx, cx, cy, 0, Math.max(w, h) * 0.7, [[0, rgba(T.deep)], [1, rgba(T.void)]]);
      ctx.fillRect(0, 0, w, h);
      drawStars(ctx, w, h, 200, audio, time);

      const moons = far => {
        for (const m of MOONS) {
          const theta = angle * (m.distance < 3 ? 1 : 0.7) + m.offset;
          if ((Math.sin(theta) < 0) !== far) continue;
          const lx = Math.cos(theta) * m.distance * radius, ly = Math.sin(theta) * m.distance * radius * FLATTEN;
          const px = cx + lx * Math.cos(TILT) - ly * Math.sin(TILT), py = cy + lx * Math.sin(TILT) + ly * Math.cos(TILT);
          const r = radius * m.size;
          ctx.fillStyle = rgba(m.color); ctx.beginPath(); ctx.arc(px, py, r, 0, Math.PI * 2); ctx.fill();
          ctx.fillStyle = radial(ctx, px - r * 0.5, py - r * 0.5, r * 0.3, r * 2, [[0, 'rgba(0,0,0,0)'], [1, 'rgba(0,0,0,0.75)']]);
          ctx.beginPath(); ctx.arc(px, py, r, 0, Math.PI * 2); ctx.fill();
        }
      };
      const rings = front => {
        ctx.save(); ctx.translate(cx, cy); ctx.rotate(TILT);
        ctx.beginPath(); ctx.rect(-unit * 2, front ? 0 : -unit * 2, unit * 4, unit * 2); ctx.clip();
        ctx.scale(1, FLATTEN);
        const wave = 1 - audio.beatPulse;
        for (let i = 0; i < RING_COUNT; i++) {
          const t = i / (RING_COUNT - 1), energy = audio.spectrum[Math.min(3 + i, audio.spectrum.length - 1)];
          const r = radius * (1.35 + t) + unit * 0.01 * energy;
          const shimmer = Math.exp(-Math.pow((t - wave) / 0.08, 2)) * audio.beatPulse;
          const opacity = Math.min(1, 0.18 + 0.45 * energy + 0.5 * shimmer) * (i % 7 === 4 ? 0.25 : 1);
          ctx.strokeStyle = rgba(RING_COLORS[i % 4], opacity); ctx.lineWidth = radius * 0.035;
          ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.stroke();
        }
        ctx.restore();
      };
      const planet = () => {
        const glow = radius * 1.25;
        ctx.fillStyle = radial(ctx, cx, cy, radius * 0.95, glow, [[0, 'rgba(242,184,128,0.25)'], [1, 'rgba(242,184,128,0)']]);
        ctx.fillRect(cx - glow, cy - glow, glow * 2, glow * 2);
        ctx.save();
        ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2); ctx.clip();
        ctx.fillStyle = rgba(hex(0xD9A066)); ctx.fillRect(cx - radius, cy - radius, radius * 2, radius * 2);
        ctx.translate(cx, cy); ctx.rotate(TILT);
        BANDS.forEach(([y, bh, color], index) => {
          const top = y * radius;
          ctx.fillStyle = rgba(hex(color)); ctx.beginPath(); ctx.moveTo(-radius * 1.2, top);
          for (let s = 0; s <= 24; s++) ctx.lineTo(-radius * 1.2 + radius * 2.4 * s / 24, top + radius * 0.025 * Math.sin(s * 0.8 + time * 0.3 + index));
          ctx.lineTo(radius * 1.2, top + bh * radius); ctx.lineTo(-radius * 1.2, top + bh * radius); ctx.closePath(); ctx.fill();
        });
        ctx.restore();
        // Light from the upper left.
        ctx.fillStyle = radial(ctx, cx - radius * 0.45, cy - radius * 0.45, 0, radius * 2.1,
          [[0, 'rgba(255,255,255,0.12)'], [0.5, 'rgba(0,0,0,0)'], [1, 'rgba(0,0,0,0.75)']]);
        ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2); ctx.fill();
      };
      moons(true); rings(false); planet(); rings(true); moons(false);
    },
  };
}

export const space = {
  id: 'space', name: 'Space', accent: T.teal,
  wallpapers: [
    { id: 'space.warp-drive', name: 'Warp Drive', summary: 'Stars streak past faster as the music gets louder, jumping to warp on the big beats.', make: makeWarpDrive },
    { id: 'space.nebula', name: 'Nebula', summary: 'Glowing gas clouds that swirl with the melody and brighten with the bass, under twinkling stars.', make: makeNebula },
    { id: 'space.ringed-planet', name: 'Ringed Planet', summary: 'Rings ripple with the spectrum and shimmer on each beat while moons orbit in time.', make: makeRingedPlanet },
  ],
};

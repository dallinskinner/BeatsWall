// Light Show collection, ported from BeatsWall/Collections/LightShow/*.swift. Film grain is omitted.
import { hex, rgba, mix, smoothstep, hash01, PhaseClock, beatProgress, beatLength } from '../kit.js';
import { lin, dot } from './draw.js';
import { T, RIG, LIGHT, rigColor, motion, glow, haze, beam, strobe, laserShow, HypeMeter } from './stagekit.js';

function makeLaserShow() {
  const hype = new HypeMeter(), spin = new PhaseClock();
  return {
    draw(ctx, w, h, { time, audio }) {
      hype.update(time, audio);
      const unit = Math.min(w, h), beat = beatProgress(audio, time), bar = Math.floor(beat / 4), pulse = audio.beatPulse, e = hype.energy, bl = beatLength(audio);
      const rot = spin.advance(time, (0.2 + 0.8 * e + 2 * hype.dropPulse) * LIGHT.speed);
      const primary = bar % 2 === 0 ? T.laserGreen : T.ice, secondary = bar % 2 === 0 ? T.magenta : T.laserGreen, floorY = h * 0.72;
      ctx.fillStyle = '#020205'; ctx.fillRect(0, 0, w, h);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      haze(ctx, 0, 0, w, floorY, primary, 0.05 + 0.1 * e + 0.12 * hype.build);
      const sky = Math.min(1, hype.dropPulse * 1.4 + hype.build * 0.6);
      if (sky > 0.02) {
        const width = Math.max(1, unit * 0.002);
        for (let line = 0; line < 9; line++) {
          ctx.beginPath();
          for (let x = 0; x <= w + 8; x += 8) { const y = h * (0.08 + 0.025 * line) + unit * 0.03 * Math.sin(x / unit * 5 + time * 2.2 + line * 0.5); x === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y); }
          const color = line % 2 === 0 ? primary : secondary;
          ctx.strokeStyle = rgba(color, 0.15 * sky); ctx.lineWidth = width * 5; ctx.stroke();
          ctx.strokeStyle = rgba(mix(color, T.white, 0.4), 0.8 * sky); ctx.lineWidth = width; ctx.stroke();
        }
      }
      laserShow(ctx, w, h, w / 2, floorY, beat, rot, bl, hype, pulse, primary, secondary, false);
      ctx.globalCompositeOperation = 'source-over';
      ctx.fillStyle = lin(ctx, 0, floorY, 0, h, ['#0A0A14', '#020205']); ctx.fillRect(0, floorY, w, h - floorY);
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.beginPath(); ctx.rect(0, floorY, w, h - floorY); ctx.clip();
      ctx.translate(0, floorY * 2); ctx.scale(1, -1); ctx.globalAlpha = 0.22;
      laserShow(ctx, w, h, w / 2, floorY, beat, rot, bl, hype, pulse, primary, secondary, true);
      ctx.restore();
      ctx.globalCompositeOperation = 'lighter';
      ctx.strokeStyle = rgba(primary, 0.25 + 0.4 * pulse); ctx.lineWidth = Math.max(1, unit * 0.002); ctx.beginPath(); ctx.moveTo(0, floorY); ctx.lineTo(w, floorY); ctx.stroke();
      glow(ctx, w / 2, floorY, unit * (0.06 + 0.06 * pulse), T.white, 0.6 + 0.4 * pulse);
      ctx.restore();
      const eighth = (beat * 2) % 1;
      strobe(ctx, w, h, hype.secondsSinceDrop < bl * 4 && eighth < 0.1 ? 0.8 : 0);
    },
  };
}

function makeSpotlightRig() {
  const hype = new HypeMeter();
  return {
    draw(ctx, w, h, { time, audio }) {
      hype.update(time, audio);
      const unit = Math.min(w, h), beat = beatProgress(audio, time), bar = Math.floor(beat / 4), pulse = audio.beatPulse, e = hype.energy, floorY = h * 0.84;
      ctx.fillStyle = lin(ctx, 0, 0, 0, floorY, ['#05040A', '#0B0814']); ctx.fillRect(0, 0, w, h);
      ctx.fillStyle = '#08060E'; ctx.fillRect(0, floorY, w, h - floorY);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      haze(ctx, 0, h * 0.1, w, floorY, rigColor(bar), 0.04 + 0.08 * e);
      const cols = w > h ? 5 : 3, rows = 3, count = cols * rows, gw = Math.min(w * 0.86, unit * 1.6), left = (w - gw) / 2;
      for (let row = 0; row < rows; row++) for (let col = 0; col < cols; col++) {
        const i = row * cols + col, hx = left + gw * (col + 0.5) / cols, hy = h * (0.1 + 0.11 * row);
        const angle = (hx - w / 2) / Math.max(w, 1) * -0.6 + motion(i, count, beat) * 0.9;
        const color = mix(rigColor(bar, col + row), T.white, 0.7 * hype.dropPulse);
        const fires = (i + audio.beatCount) % 2 === 0 || e > 0.6;
        const intensity = (0.25 + 0.6 * e + 0.3 * hype.dropPulse) * (fires ? 1 : 0.35) * (1 - 0.18 * row);
        const length = (floorY - hy) / Math.max(Math.cos(angle), 0.3);
        beam(ctx, hx, hy, angle, length, 0.07 - 0.03 * hype.build, color, intensity);
        const sx = hx + Math.sin(angle) * length, sy = hy + Math.cos(angle) * length;
        if (!(sy > floorY - unit * 0.02)) continue;
        ctx.save(); ctx.translate(sx, sy); ctx.scale(1, 0.28);
        const r = unit * (0.05 + 0.03 * pulse);
        glow(ctx, 0, 0, r, color, 0.7 * intensity);
        for (let p = 0; p < 6; p++) { const s = p / 6 * Math.PI * 2 + beat * 0.5; dot(ctx, Math.cos(s) * r * 0.6, Math.sin(s) * r * 0.6, r * 0.16, rgba(mix(color, T.white, 0.5), 0.8 * intensity)); }
        ctx.restore();
        ctx.globalCompositeOperation = 'source-over'; dot(ctx, hx, hy, unit * 0.012, '#1C1828'); ctx.globalCompositeOperation = 'lighter';
        glow(ctx, hx, hy, unit * 0.025, color, intensity);
      }
      ctx.restore();
      strobe(ctx, w, h, e > 0.7 && audio.secondsSinceBeat < 0.05 ? 0.4 : (hype.secondsSinceDrop < 0.3 ? 0.7 : 0));
    },
  };
}

function makeLightTunnel() {
  const hype = new HypeMeter();
  return {
    draw(ctx, w, h, { time, audio }) {
      hype.update(time, audio);
      const unit = Math.min(w, h), beat = beatProgress(audio, time) * LIGHT.speed, pulse = audio.beatPulse, vx = w / 2, vy = h * 0.5;
      ctx.fillStyle = '#020106'; ctx.fillRect(0, 0, w, h);
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round';
      glow(ctx, vx, vy, unit * 0.35, rigColor(Math.floor(beat / 4)), 0.25 + 0.3 * hype.energy);
      const N = 16, step = Math.floor(beat), travel = beat - step;
      for (let slot = N - 1; slot >= 0; slot--) {
        const depth = (slot + 1 - smoothstep(0, 0.6, travel)) / N, scale = 0.06 / (depth * depth + 0.012);
        if (!(scale < 30)) continue;
        const hw = unit * 0.25 * scale, ah = unit * 0.375 * scale;
        ctx.beginPath(); ctx.moveTo(vx - hw, vy + ah * 0.5); ctx.lineTo(vx - hw, vy - ah * 0.2);
        ctx.quadraticCurveTo(vx, vy - ah * 0.95, vx + hw, vy - ah * 0.2); ctx.lineTo(vx + hw, vy + ah * 0.5);
        const color = mix(rigColor(step + N - slot), T.white, 0.8 * hype.dropPulse);
        const b = (0.15 + 0.85 * (1 - depth)) * (0.55 + 0.45 * hype.energy) * (slot === N - 1 ? 0.4 + 0.6 * pulse : 1);
        const width = Math.max(1, unit * 0.006 * scale * 0.4);
        ctx.setLineDash([]); ctx.strokeStyle = rgba(color, 0.18 * b); ctx.lineWidth = width * 6; ctx.stroke();
        ctx.setLineDash([width * 1.2, width * 1.4]); ctx.lineDashOffset = beat * 8 * width; ctx.strokeStyle = rgba(mix(color, T.white, 0.3), b); ctx.lineWidth = width; ctx.stroke();
      }
      ctx.setLineDash([]); ctx.beginPath();
      for (let lane = -4; lane <= 4; lane++) { ctx.moveTo(vx + lane * unit * 0.01, vy + unit * 0.02); ctx.lineTo(vx + lane * w * 0.35, h); }
      ctx.strokeStyle = rgba(rigColor(Math.floor(beat / 4), 2), 0.12 + 0.2 * pulse); ctx.lineWidth = Math.max(1, unit * 0.002); ctx.stroke();
      ctx.restore();
      strobe(ctx, w, h, hype.secondsSinceDrop < 0.35 ? 1 - hype.secondsSinceDrop * 2 : 0);
    },
  };
}

function makeFogRoom() {
  const hype = new HypeMeter(), drift = new PhaseClock();
  const FIXTURES = [[0.02, 0.05], [0.3, -0.02], [0.7, -0.02], [0.98, 0.05], [0, 0.95], [1, 0.95]];
  return {
    draw(ctx, w, h, { time, audio }) {
      hype.update(time, audio);
      const unit = Math.min(w, h), beat = beatProgress(audio, time), bar = Math.floor(beat / 4), pulse = audio.beatPulse, e = hype.energy;
      const roll = drift.advance(time, 0.3 + 0.5 * e), fog = LIGHT.fog * 2;
      ctx.fillStyle = '#040308'; ctx.fillRect(0, 0, w, h);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 12; i++) {
        const x = (((roll * 0.03 * (0.5 + hash01(i, 1)) + hash01(i, 2)) % 1.4) - 0.2) * w, y = h * (0.25 + 0.65 * hash01(i, 3)) + unit * 0.04 * Math.sin(roll * 0.4 + i);
        ctx.save(); ctx.translate(x, y); ctx.scale(2.2, 0.8);
        glow(ctx, 0, 0, unit * 0.22, mix(rigColor(bar, i), T.white, 0.7), (0.05 + 0.06 * e) * fog); ctx.restore();
      }
      const spread = hype.dropPulse > 0.3 ? 0.015 : 0.04 + 0.08 * hype.build;
      FIXTURES.forEach(([fx, fy], i) => {
        const ox = w * fx, oy = h * fy, aim = Math.atan2(w / 2 - ox, h * 0.55 - oy) + motion(i, 6, beat) * 0.6;
        const color = mix(rigColor(bar, i % 3), T.white, 0.5 * hype.dropPulse);
        beam(ctx, ox, oy, aim, Math.hypot(w, h) * 0.9, spread, color, (0.3 + 0.5 * e + 0.4 * hype.dropPulse) * (0.75 + 0.25 * pulse) * (0.6 + 0.4 * fog));
      });
      ctx.fillStyle = `rgba(255,255,255,${0.25 + 0.3 * e})`; ctx.beginPath();
      for (let i = 0; i < 160; i++) {
        const x = ((hash01(i, 7) + roll * 0.004 * hash01(i, 8)) % 1) * w, y = ((((hash01(i, 9) - roll * 0.003 * hash01(i, 10)) % 1) + 1) % 1) * h, r = unit * 0.0015;
        ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, Math.PI * 2);
      }
      ctx.fill(); ctx.restore();
      strobe(ctx, w, h, hype.secondsSinceDrop < 0.25 ? 0.6 : 0);
    },
  };
}

export const lightshow = {
  id: 'lightshow', name: 'Light Show', accent: T.laserGreen,
  wallpapers: [
    { id: 'lightshow.laser-show', name: 'Laser Show', summary: 'Lasers in black fog over a mirror floor, with a laser sky when the song drops.', make: makeLaserShow },
    { id: 'lightshow.spotlight-rig', name: 'Spotlight Rig', summary: 'A wall of moving heads throwing pools of light that sweep to the beat.', make: makeSpotlightRig },
    { id: 'lightshow.light-tunnel', name: 'Light Tunnel', summary: 'A rush through arches of LED light. A new arch arrives on every beat.', make: makeLightTunnel },
    { id: 'lightshow.fog-room', name: 'Fog Room', summary: 'Beams from six angles cut through rolling fog.', make: makeFogRoom },
  ],
};

// Woofie the speaker, ported from BeatsWall/Collections/Brand/WoofieWallpaper.swift.
import { C, rgba, mix } from './kit.js';

const CAB_W = 14, CAB_H = 18, SPR_H = 20;
const ARMS_DOWN = [[-1, 9], [-2, 10], [-3, 11], [14, 9], [15, 10], [16, 11]];
const ARMS_UP = [[-1, 9], [-2, 8], [-3, 7], [-3, 6], [14, 9], [15, 8], [16, 7], [16, 6]];
const LEGS = [[3, 4, 9, 10], [2, 3, 10, 11]];
const CABINET = '#2B1D5C';

/**
 * Draws Woofie with his feet at (x, y). `pixel` is the size of one sprite pixel.
 * `armsUp` forces the arms (true/false); leave undefined to follow the music.
 */
export function drawWoofie(ctx, { x, y, pixel, audio, time, armsUp }) {
  const pulse = audio.beatPulse, bass = audio.bass;
  // Hop off the floor on each beat, snapped to half pixels for a retro feel.
  const hopCurve = 4 * pulse * (1 - pulse);
  const hop = Math.round((hopCurve * pixel * (1.5 + 3 * bass)) / (pixel * 0.5)) * pixel * 0.5;
  const beatProgress = audio.beatCount + (1 - pulse);
  const sway = Math.sin(Math.PI * beatProgress) * pixel * 0.8;
  const squash = Math.pow(pulse, 3);
  const scaleY = 1 - 0.12 * squash + 0.05 * hopCurve;
  const scaleX = 1 + 0.08 * squash;

  ctx.save();
  // Shadow shrinks as Woofie leaves the floor.
  const sw = pixel * 15 * (1 - 0.25 * hopCurve);
  ctx.fillStyle = 'rgba(0,0,0,0.4)';
  ctx.beginPath();
  ctx.ellipse(x + sway, y + pixel * 0.2, sw / 2, pixel * 0.7, 0, 0, Math.PI * 2);
  ctx.fill();

  const fx = x + sway, fy = y - hop;
  const cw = pixel * scaleX, ch = pixel * scaleY;
  const cell = (col, row) => [fx + (col - CAB_W / 2) * cw, fy + (row - SPR_H) * ch, cw + 0.5, ch + 0.5];
  const rect = (col, row) => ctx.fillRect(...cell(col, row));

  // Cabinet, arms and legs, with a magenta glow that swells with the bass.
  ctx.shadowColor = rgba(C.magenta, 0.45 + 0.35 * bass);
  ctx.shadowBlur = pixel * (1 + 2.5 * bass) * 2;
  ctx.fillStyle = CABINET;
  for (let row = 0; row < CAB_H; row++) {
    for (let col = 0; col < CAB_W; col++) {
      const corner = (row === 0 || row === CAB_H - 1) && (col === 0 || col === CAB_W - 1);
      if (!corner) rect(col, row);
    }
  }
  const up = armsUp === undefined ? (Math.floor(audio.beatCount / 2) % 2 === 1 && audio.level > 0.45) : armsUp;
  for (const [col, row] of up ? ARMS_UP : ARMS_DOWN) rect(col, row);
  for (const col of LEGS[audio.beatCount % 2]) { rect(col, 18); rect(col, 19); }
  ctx.shadowBlur = 0;

  // The woofer: surround, cone and dust cap, pumping out with the bass.
  const pump = 1 + 0.14 * bass + 0.08 * pulse;
  const cone = rgba(mix(C.magenta, C.plum, 0.35 - 0.3 * pulse));
  for (let row = 6; row < CAB_H - 1; row++) {
    for (let col = 1; col < CAB_W - 1; col++) {
      const d = Math.hypot(col - 6.5, row - 11.5) / pump;
      if (d <= 1.6) ctx.fillStyle = rgba(C.yellow);
      else if (d <= 4.1) ctx.fillStyle = cone;
      else if (d <= 5.1) ctx.fillStyle = rgba(C.orange);
      else continue;
      rect(col, row);
    }
  }

  // Eyes that look toward each other, with a blink every few seconds.
  const blinking = time % 3.7 < 0.13;
  ctx.fillStyle = rgba(C.glow);
  for (const col of [3, 9]) {
    for (const row of blinking ? [3] : [2, 3]) { rect(col, row); rect(col + 1, row); }
  }
  if (!blinking) {
    // pupils sit on the inner side, so the eyes look toward each other
    ctx.fillStyle = rgba(C.ink);
    rect(4, 3); rect(9, 3);
  }
  ctx.restore();
}

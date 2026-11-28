// BeatsWall collection. Woofie is ported from WoofieWallpaper.swift; the others are in brandmore.js.
import { C, rgba, mix, hash01, BeatEdge, brandGradient, pixelSprite } from '../kit.js';
import { drawWoofie } from '../sprite.js';
import { beatB, rippleGrid, terminal, sparkField } from './brandmore.js';

const NOTE = ['..###', '..#.#', '..#..', '..#..', '###..', '###..'];
const NOTE_LIFETIME = 2.6;

function backdrop(ctx, w, h) {
  const g = ctx.createLinearGradient(0, 0, w * 0.3, h);
  g.addColorStop(0, rgba(C.navy)); g.addColorStop(1, rgba(C.plum));
  ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
}

function makeWoofie() {
  const notes = [];
  const edge = new BeatEdge();
  return {
    draw(ctx, w, h, { time, audio }) {
      const pulse = audio.beatPulse, bass = audio.bass;
      const unit = Math.min(w, h), pixel = unit * 0.018, floorY = h * 0.72;

      if (edge.isNewBeat(audio) && audio.beatCount % 2 === 0) {
        notes.push({ born: time, side: Math.random() < 0.5 ? -1 : 1, seed: Math.random() });
      }
      for (let i = notes.length - 1; i >= 0; i--) {
        if (time - notes[i].born > NOTE_LIFETIME || time < notes[i].born) notes.splice(i, 1);
      }

      backdrop(ctx, w, h);
      const glow = ctx.createRadialGradient(w / 2, floorY - unit * 0.15, 0, w / 2, floorY - unit * 0.15, unit * 0.6);
      glow.addColorStop(0, rgba(C.magenta, 0.12 + 0.12 * bass)); glow.addColorStop(1, rgba(C.magenta, 0));
      ctx.fillStyle = glow; ctx.fillRect(0, 0, w, h);

      // Spectrum skyline: faint stacked blocks behind Woofie.
      const count = audio.spectrum.length, colW = w / count, blockH = pixel * 1.6;
      const maxBlocks = Math.floor((floorY - h * 0.1) / blockH);
      audio.spectrum.forEach((v, i) => {
        const filled = Math.floor(v * maxBlocks);
        const col = brandGradient(i / (count - 1));
        for (let b = 0; b < filled; b++) {
          ctx.fillStyle = rgba(col, b === filled - 1 ? 0.25 : 0.08);
          ctx.fillRect(i * colW + pixel * 0.4, floorY - (b + 1) * blockH, colW - pixel * 0.8, blockH - pixel * 0.4);
        }
      });

      // Dance floor: tiles that light in a new pattern on every beat.
      const tile = pixel * 3.4, gap = pixel * 0.45, cols = Math.floor(w / tile) + 1;
      const offX = (w - cols * tile) / 2;
      for (let row = 0; row < 3; row++) {
        for (let col = 0; col < cols; col++) {
          const roll = hash01(col + row * 997, audio.beatCount);
          ctx.fillStyle = roll < 0.25
            ? rgba(brandGradient(Math.floor(roll * 12) / 2), 0.1 + 0.5 * pulse)
            : rgba(C.glow, 0.03);
          ctx.fillRect(offX + col * tile + gap / 2, floorY + pixel * 1.6 + row * tile, tile - gap, tile - gap);
        }
      }

      // Notes float up on the beat.
      const notePx = pixel * 0.9;
      for (const n of notes) {
        const age = time - n.born, fade = Math.max(0, 1 - age / NOTE_LIFETIME);
        ctx.fillStyle = rgba(brandGradient(n.seed), 0.8 * fade);
        pixelSprite(ctx, NOTE,
          w / 2 + n.side * unit * (0.2 + 0.05 * n.seed) + Math.sin(age * 3 + n.seed * 6) * pixel,
          h * 0.5 - age * unit * 0.12, notePx);
      }

      drawWoofie(ctx, { x: w / 2, y: floorY, pixel, audio, time });
    },
  };
}

export const brand = {
  id: 'beatswall', name: 'BeatsWall', accent: C.magenta,
  wallpapers: [
    beatB, rippleGrid, terminal, sparkField,
    { id: 'beatswall.woofie', name: 'Woofie', summary: 'Woofie the speaker pumps his woofer with the bass and hops on the kick.', make: makeWoofie },
  ],
};

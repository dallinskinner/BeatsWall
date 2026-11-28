// The wallpaper catalog and the Stage that plays one (or shuffles through many).
// To add a ported collection: create <name>.js exporting { id, name, accent, wallpapers }, then list it here.
import { readAudio } from '../audio.js';
import { brand } from './brand.js';
import { synthwave } from './synthwave.js';
import { space } from './space.js';
import { tokyo } from './tokyo.js';
import { deepsea } from './deepsea.js';
import { desert } from './desert.js';
import { concert } from './concert.js';
import { lightshow } from './lightshow.js';
import { nature } from './nature.js';
import { minimal } from './minimal.js';
import { cyber } from './cyber.js';
import { jungle } from './jungle.js';
import { skate } from './skate.js';
import { lofi } from './lofi.js';
import { halloween } from './halloween.js';
import { arcade } from './arcade.js';
import { winter } from './winter.js';

// Ports of the Mac app's wallpapers, in the app's order.
export const COLLECTIONS = [brand, concert, lightshow, skate, synthwave, space, nature, lofi, halloween, arcade, tokyo, winter, deepsea, minimal, cyber, jungle, desert];
export const DEFAULT_ID = 'beatswall.woofie';

export const allWallpapers = () => COLLECTIONS.flatMap(c => c.wallpapers.map(w => ({ ...w, collection: c })));
export const findWallpaper = id => allWallpapers().find(w => w.id === id);
export const findCollection = id => COLLECTIONS.find(c => c.id === id);

/**
 * A singer's pick: { mode: 'single', wallpaperId } or { mode: 'shuffle', scope: 'all' | collectionId }.
 * Returns the wallpapers that pick can play.
 */
export function poolFor(pick) {
  if (pick && pick.mode === 'shuffle') {
    const all = allWallpapers();
    return pick.scope && pick.scope !== 'all' ? all.filter(w => w.collection.id === pick.scope) : all;
  }
  return [findWallpaper(pick && pick.wallpaperId) || findWallpaper(DEFAULT_ID)];
}

/** Draws one still frame of a wallpaper onto a small canvas (for pickers and the gallery). */
export function renderThumb(canvas, wallpaper) {
  const ctx = canvas.getContext('2d');
  const inst = wallpaper.make();
  for (let t = 3.2; t <= 4.06; t += 0.1) inst.draw(ctx, canvas.width, canvas.height, { time: t, audio: readAudio(t) });
}

export class Stage {
  constructor(canvas, { onChange } = {}) {
    this.canvas = canvas; this.ctx = canvas.getContext('2d');
    this.onChange = onChange; this.bpm = 120; this.pool = []; this.shuffle = false;
    this.current = null; this.lastBar = null;
    this.audioSource = t => readAudio(t, this.bpm);
    this.resize = this.resize.bind(this); this.loop = this.loop.bind(this);
    addEventListener('resize', this.resize); this.resize();
    this.setPick({ mode: 'single', wallpaperId: DEFAULT_ID });
    requestAnimationFrame(this.loop);
  }
  resize() {
    const dpr = Math.min(devicePixelRatio || 1, 2);
    this.w = innerWidth; this.h = innerHeight;
    this.canvas.width = this.w * dpr; this.canvas.height = this.h * dpr;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  setPick(pick) {
    this.pool = poolFor(pick);
    this.shuffle = !!pick && pick.mode === 'shuffle' && this.pool.length > 1;
    this.lastBar = null;
    this._use(this.pool[Math.floor(Math.random() * this.pool.length)]);
  }
  _use(w) {
    this.current = { wallpaper: w, inst: w.make() };
    if (this.onChange) this.onChange(w);
  }
  loop(now) {
    const t = now / 1000, audio = this.audioSource(t);
    if (this.shuffle) {
      const bar = Math.floor(audio.beatCount / 4); // a new wallpaper every bar
      if (this.lastBar !== null && bar !== this.lastBar) {
        const others = this.pool.filter(w => w !== this.current.wallpaper);
        this._use(others[Math.floor(Math.random() * others.length)]);
      }
      this.lastBar = bar;
    }
    this.current.inst.draw(this.ctx, this.w, this.h, { time: t, audio });
    requestAnimationFrame(this.loop);
  }
}

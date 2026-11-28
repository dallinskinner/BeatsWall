// Canvas helpers that stand in for SwiftUI's GraphicsContext conveniences.
import { rgba } from '../kit.js';

/** Linear gradient with evenly spaced stops, like SwiftUI's Gradient(colors:). `colors` are CSS color strings. */
export function lin(ctx, x0, y0, x1, y1, colors) {
  const g = ctx.createLinearGradient(x0, y0, x1, y1);
  colors.forEach((c, i) => g.addColorStop(colors.length === 1 ? 0 : i / (colors.length - 1), c));
  return g;
}

/** Radial gradient with evenly spaced stops. */
export function rad(ctx, cx, cy, r0, r1, colors) {
  const g = ctx.createRadialGradient(cx, cy, r0, cx, cy, r1);
  colors.forEach((c, i) => g.addColorStop(colors.length === 1 ? 0 : i / (colors.length - 1), c));
  return g;
}

/** Rounded-rect path (does not fill). */
export function rrect(ctx, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}

export function circle(ctx, x, y, r) { ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); }

/** Polyline path from [x, y] points. */
export function lines(ctx, pts, close = false) {
  ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]);
  for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
  if (close) ctx.closePath();
}

/** Strokes a path as a neon tube: a soft wide glow under a bright core. `build()` must create the path. */
export function neon(ctx, build, color, width, brightness = 1) {
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  const core = [color[0] + (255 - color[0]) * 0.35, color[1] + (255 - color[1]) * 0.35, color[2] + (255 - color[2]) * 0.35];
  [[6, 0.18, color], [2.5, 0.35, color], [1, 1, core]].forEach(([k, a, c]) => {
    ctx.strokeStyle = rgba(c, a * brightness); ctx.lineWidth = width * k; build(); ctx.stroke();
  });
}

const layers = new Map();
/** A scratch canvas to draw a "layer" on (needed for destination-out). Returns null where there is no DOM. */
export function scratch(key, w, h) {
  if (typeof document === 'undefined') return null;
  let s = layers.get(key);
  if (!s || s.canvas.width !== w || s.canvas.height !== h) {
    const canvas = document.createElement('canvas'); canvas.width = w; canvas.height = h;
    s = { canvas, ctx: canvas.getContext('2d') }; layers.set(key, s);
  }
  s.ctx.clearRect(0, 0, w, h);
  return s;
}

/** Ellipse inscribed in the rect (x, y, w, h); begins a new path. */
export function ell(ctx, x, y, w, h) { ctx.beginPath(); ctx.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, Math.PI * 2); }

/** Runs fn with a CSS blur filter where the browser supports it (otherwise draws unblurred). */
export function withBlur(ctx, px, fn) {
  const had = 'filter' in ctx;
  if (had) ctx.filter = `blur(${px}px)`;
  fn();
  if (had) ctx.filter = 'none';
}

/** Filled circle in a CSS color or gradient. */
export function dot(ctx, x, y, r, fill) { ctx.fillStyle = fill; circle(ctx, x, y, Math.max(r, 0)); ctx.fill(); }

/** Soft radial glow fading from `color` at `alpha` to nothing. */
export function glow(ctx, x, y, r, color, alpha) {
  if (r <= 0) return;
  dot(ctx, x, y, r, rad(ctx, x, y, 0, r, [rgba(color, alpha), rgba(color, 0)]));
}

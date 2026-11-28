// Woofie the helper: a small dancing mascot with a speech bubble.
import { readAudio } from './audio.js';
import { drawWoofie } from './sprite.js';

/**
 * Mounts Woofie into `host`. Returns { say(text, ms), cheer(ms), destroy() }.
 * say() shows a speech bubble (stays until replaced, or hides after `ms` if given).
 */
export function mountWoofie(host, { size = 140 } = {}) {
  host.classList.add('woofie');
  const bubble = document.createElement('div');
  bubble.className = 'bubble'; bubble.hidden = true; bubble.setAttribute('role', 'status');
  const canvas = document.createElement('canvas');
  const W = Math.round(size * 1.3), H = Math.round(size * 1.15), dpr = Math.min(devicePixelRatio || 1, 2);
  canvas.width = W * dpr; canvas.height = H * dpr;
  canvas.style.width = W + 'px'; canvas.style.height = H + 'px';
  canvas.setAttribute('aria-label', 'Woofie, the helper');
  host.append(bubble, canvas);
  const ctx = canvas.getContext('2d');
  let cheerUntil = 0, hideTimer = null, raf = 0, dead = false;

  function frame(now) {
    if (dead) return;
    const t = now / 1000;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);
    drawWoofie(ctx, {
      x: W / 2, y: H * 0.93, pixel: W / 24, audio: readAudio(t), time: t,
      armsUp: t < cheerUntil ? true : undefined,
    });
    raf = requestAnimationFrame(frame);
  }
  raf = requestAnimationFrame(frame);

  return {
    say(text, ms = 0) {
      clearTimeout(hideTimer);
      bubble.textContent = text; bubble.hidden = !text;
      if (text && ms) hideTimer = setTimeout(() => { bubble.hidden = true; }, ms);
    },
    cheer(ms = 2500) { cheerUntil = performance.now() / 1000 + ms / 1000; },
    destroy() { dead = true; cancelAnimationFrame(raf); host.replaceChildren(); },
  };
}

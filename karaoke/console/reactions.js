// Emoji from the audience, floating up the TV.
import { REACTIONS } from '../shared/backend.js';

const MAX_ON_SCREEN = 40;

/** Returns a function that floats one reaction up `layer`. Extra ones are dropped when the screen is full. */
export function reactionLayer(layer) {
  return key => {
    if (layer.childElementCount >= MAX_ON_SCREEN) return;
    const s = document.createElement('span');
    s.textContent = REACTIONS[key];
    s.style.left = 8 + Math.random() * 84 + '%';
    s.style.fontSize = 2.4 + Math.random() * 2 + 'rem';
    s.style.animationDuration = 3 + Math.random() * 1.5 + 's';
    s.style.setProperty('--drift', (Math.random() - 0.5) * 160 + 'px');
    s.addEventListener('animationend', () => s.remove());
    layer.append(s);
  };
}

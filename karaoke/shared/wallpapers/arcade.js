// Retro Arcade collection, ported from BeatsWall/Collections/Arcade/*.swift. The CRT shader becomes scanline stripes.
import { hex, rgba, mix, hash01, PhaseClock, BeatEdge, beatProgress, beatLength, pixelSprite } from '../kit.js';
import { circle, dot } from './draw.js';

const T = { black: hex(0x0B0B1A), blue: hex(0x2E5BFF), fill: hex(0x111A4A), yellow: hex(0xFFE14D), red: hex(0xFF4D6D), pink: hex(0xFF8AD8), cyan: hex(0x4DF3FF), orange: hex(0xFFA24D), green: hex(0x6BFF8A), white: hex(0xF4F4FF), dot: hex(0xFFD9B3), pure: [255, 255, 255] };
const BUG_A = [['...##...', '..####..', '.##..##.', '########', '#.####.#', '..#..#..', '.#.##.#.', '#......#'], ['...##...', '..####..', '.##..##.', '########', '#.####.#', '..#..#..', '.#....#.', '..#..#..']];
const BUG_B = [['..#..#..', '...##...', '.######.', '##.##.##', '########', '.#.##.#.', '#......#', '.#....#.'], ['..#..#..', '#..##..#', '#######.', '##.##.##', '########', '..####..', '.#.##.#.', '#.#..#.#']];
const pixelFor = (w, h, across) => Math.max(2, Math.floor(Math.min(w, h) / across));
const snap = (v, p) => Math.round(v / p) * p;
const box = (ctx, color, x, y, w, h) => { ctx.fillStyle = color; ctx.fillRect(x, y, w, h); };
function sprite(ctx, rows, palette, x, y, p) {
  rows.forEach((line, r) => { for (let c = 0; c < line.length; c++) { const color = palette[line[c]]; if (color) box(ctx, color, x + c * p, y + r * p, p + 0.5, p + 0.5); } });
}
function crt(ctx, w, h, time, p) {
  const period = Math.max(2, p); ctx.fillStyle = 'rgba(0,0,0,0.22)';
  for (let y = (time * 12) % (period * 2); y < h; y += period * 2) ctx.fillRect(0, y, w, period);
}
function hud(ctx, text, x, y, size, color, align = 'left', base = 'top') {
  ctx.save(); ctx.font = `800 ${size}px ui-monospace, Menlo, monospace`; ctx.textAlign = align; ctx.textBaseline = base; ctx.fillStyle = color; ctx.fillText(text, x, y); ctx.restore();
}
const pad = (n, k) => String(n).padStart(k, '0');

// ---------------------------------------------------------------- Maze Chase
const MAZE = ['###################', '#o.......#.......o#', '#.##.###.#.###.##.#', '#.................#', '#.##.#.#####.#.##.#', '#....#...#...#....#', '####.###.#.###.####', '#....#.......#....#', '#.##.#.#####.#.##.#', '#.................#', '#.##.###.#.###.##.#', '#o.......#.......o#', '###################'];
const wallAt = (c, r) => r < 0 || r >= MAZE.length || c < 0 || c >= MAZE[0].length || MAZE[r][c] === '#';
const ROUTE = (() => { // follow the left-hand wall around the corridors
  const dirs = [[1, 0], [0, 1], [-1, 0], [0, -1]], out = [];
  let c = 1, r = 1, heading = 0;
  do {
    out.push([c, r]);
    for (const turn of [3, 0, 1, 2]) { const k = (heading + turn) % 4, nc = c + dirs[k][0], nr = r + dirs[k][1]; if (!wallAt(nc, nr)) { heading = k; c = nc; r = nr; break; } }
  } while (!(c === 1 && r === 1) && out.length < 2000);
  return out;
})();
const FIRST = new Map(); ROUTE.forEach(([c, r], i) => { if (!FIRST.has(r * 100 + c)) FIRST.set(r * 100 + c, i); });
const wrap = i => ((i % ROUTE.length) + ROUTE.length) % ROUTE.length;
function makeMaze() {
  return {
    draw(ctx, w, h, { time, audio }) {
      const cols = MAZE[0].length, rows = MAZE.length, t = Math.floor(Math.min(w / (cols + 2), h / (rows + 3)));
      const ox = Math.round((w - t * cols) / 2), oy = Math.round((h - t * rows) / 2 + t * 0.5), center = (c, r) => [ox + (c + 0.5) * t, oy + (r + 0.5) * t];
      box(ctx, rgba(T.black), 0, 0, w, h);
      const inset = t * 0.18, edges = new Path2D();
      const seg = (a, b, c, d) => { edges.moveTo(a, b); edges.lineTo(c, d); };
      MAZE.forEach((line, r) => { for (let c = 0; c < cols; c++) {
        if (line[c] !== '#') continue;
        const x = ox + c * t, y = oy + r * t;
        box(ctx, rgba(T.fill), x, y, t + 0.5, t + 0.5);
        if (!wallAt(c, r - 1)) seg(x, y + inset, x + t, y + inset);
        if (!wallAt(c, r + 1)) seg(x, y + t - inset, x + t, y + t - inset);
        if (!wallAt(c - 1, r)) seg(x + inset, y, x + inset, y + t);
        if (!wallAt(c + 1, r)) seg(x + t - inset, y, x + t - inset, y + t);
      } });
      ctx.strokeStyle = rgba(mix(T.blue, T.pure, 0.25 * audio.beatPulse)); ctx.lineWidth = Math.max(2, t * 0.1); ctx.stroke(edges);
      const progress = beatProgress(audio, time) * 2, step = Math.floor(progress), frac = progress - step, lap = wrap(step);
      const position = i => { const a = ROUTE[wrap(i)], b = ROUTE[wrap(i + 1)], s = center(...a), e = center(...b); return [s[0] + (e[0] - s[0]) * frac, s[1] + (e[1] - s[1]) * frac, b[0] - a[0], b[1] - a[1]]; };
      MAZE.forEach((line, r) => { for (let c = 0; c < cols; c++) {
        const ch = line[c];
        if ((ch !== '.' && ch !== 'o') || (FIRST.has(r * 100 + c) && FIRST.get(r * 100 + c) <= lap)) continue;
        const [x, y] = center(c, r);
        if (ch === '.') { const k = Math.ceil(t * 0.09); box(ctx, rgba(T.dot), x - k, y - k, k * 2, k * 2); } else dot(ctx, x, y, t * (0.22 + 0.12 * audio.bass), rgba(T.dot, 0.6 + 0.4 * audio.beatPulse));
      } });
      let scared = false;
      for (let back = 0; back < 14; back++) { const [c, r] = ROUTE[wrap(step - back)]; if (MAZE[r][c] === 'o') scared = true; }
      const bp = Math.max(1, Math.floor(t / 10));
      [8, 13, 18, 23].forEach((off, i) => {
        const [x, y] = position(step - off), rowsA = (i % 2 === 0 ? BUG_A : BUG_B)[audio.beatCount % 2];
        const color = scared ? (Math.floor(time * 6) % 2 === 0 ? T.blue : T.white) : [T.red, T.pink, T.cyan, T.orange][i];
        sprite(ctx, rowsA, { '#': rgba(color) }, Math.round(x - bp * 4), Math.round(y - bp * 4), bp);
      });
      const [hx, hy, dx, dy] = position(step), chomp = Math.abs(Math.sin(Math.PI * progress)) * 0.85, face = Math.atan2(dy, dx), R = t * 0.42;
      ctx.beginPath(); ctx.moveTo(hx, hy); ctx.arc(hx, hy, R, face + chomp * 0.5, face - chomp * 0.5 + Math.PI * 2); ctx.closePath(); ctx.fillStyle = rgba(T.green); ctx.fill();
      box(ctx, rgba(T.black), hx + Math.cos(face - 1.2) * R * 0.5 - bp, hy + Math.sin(face - 1.2) * R * 0.5 - bp, bp * 2, bp * 2);
      hud(ctx, `SCORE ${pad((lap * 10 + audio.beatCount * 50) % 1000000, 6)}`, ox, oy - t * 0.5, t * 0.6, rgba(T.white), 'left', 'bottom');
      hud(ctx, 'HI 999990', ox + t * cols, oy - t * 0.5, t * 0.6, rgba(T.red), 'right', 'bottom');
      crt(ctx, w, h, time, pixelFor(w, h, 160));
    },
  };
}

// ---------------------------------------------------------------- Star Shooter
const SHIP = ['.....#.....', '....###....', '....#C#....', '.#..###..#.', '.#.#####.#.', '###########', '####R#R####', '#..R...R..#'];
const ROW_COLORS = [T.pink, T.cyan, T.green, T.yellow];
function makeShooter() {
  const COLS = 8, ROWS = 4, MARCH = [0, 1, 2, 3, 2, 1, 0, -1, -2, -3, -2, -1];
  const fresh = () => Array.from({ length: ROWS }, () => Array(COLS).fill(true));
  let alive = fresh(), bullets = [], booms = [], shipX = 0, score = 0, wave = 1, travel = 0, waveStart = null, target = 0;
  const clock = new PhaseClock(), edge = new BeatEdge();
  return {
    draw(ctx, w, h, { time, audio }) {
      const p = pixelFor(w, h, 170), sx = p * 14, sy = p * 11, shipY = h - p * 22, beat = audio.beatCount;
      const invader = (c, r, descent) => [w / 2 - sx * (COLS - 1) / 2 + c * sx + MARCH[((beat % 12) + 12) % 12] * p * 3, h * 0.14 + r * sy + descent];
      clock.advance(time);
      const dt = clock.deltaTime;
      travel += dt * (0.4 + 2.5 * audio.level);
      if (waveStart === null) { waveStart = beat; shipX = w / 2; }
      if (edge.isNewBeat(audio)) {
        if (!alive.some(r => r.some(Boolean)) || beat - waveStart > 96) { alive = fresh(); waveStart = beat; wave++; }
        else {
          let best = null;
          for (let c = 0; c < COLS; c++) {
            let row = -1;
            for (let r = ROWS - 1; r >= 0; r--) if (alive[r][c] && !bullets.some(b => b.c === c && b.r === r)) { row = r; break; }
            if (row < 0) continue;
            const d = Math.abs(invader(c, row, 0)[0] - shipX) + hash01(c, beat) * sx * 2;
            if (!best || d < best.d) best = { c, r: row, d };
          }
          if (best) { target = best.c; bullets.push({ x: shipX, y: shipY, c: best.c, r: best.r }); }
        }
      }
      shipX += (invader(target, 0, 0)[0] - shipX) * Math.min(1, dt * 3);
      const descent = Math.min(Math.floor(Math.max(beat - waveStart, 0) / 12), 6) * p * 4;
      bullets = bullets.filter(b => {
        b.y -= dt * h * 1.3;
        const [tx, ty] = invader(b.c, b.r, descent);
        if (alive[b.r][b.c] && b.y <= ty + p * 3) { alive[b.r][b.c] = false; score += (ROWS - b.r) * 100; booms.push({ x: tx, y: ty, t: time, color: ROW_COLORS[b.r] }); return false; }
        return b.y >= -p * 10;
      });
      booms = booms.filter(e => time - e.t <= 0.5);

      box(ctx, rgba(T.black), 0, 0, w, h);
      for (let layer = 0; layer < 3; layer++) {
        ctx.fillStyle = rgba(T.white, 0.3 + 0.25 * layer);
        for (let i = 0; i < 30 + layer * 20; i++) ctx.fillRect(snap(hash01(i, layer + 10) * w, p), snap((hash01(i, layer) * h + travel * (layer + 1) * h * 0.05) % h, p), p * (layer === 2 ? 2 : 1), p * (1 + layer));
      }
      for (let r = 0; r < ROWS; r++) {
        const rows = (r % 2 === 0 ? BUG_A : BUG_B)[beat % 2];
        for (let c = 0; c < COLS; c++) if (alive[r][c]) { const [x, y] = invader(c, r, descent); sprite(ctx, rows, { '#': rgba(ROW_COLORS[r]) }, snap(x - p * 4, p), snap(y - p * 4, p), p); }
      }
      for (const b of bullets) box(ctx, rgba(T.white), snap(b.x, p), snap(b.y, p), p, p * 4);
      for (const e of booms) {
        const age = time - e.t;
        for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; box(ctx, rgba(e.color, Math.max(0, 1 - age / 0.45)), snap(e.x + Math.cos(a) * age * p * 40, p), snap(e.y + Math.sin(a) * age * p * 40, p), p * 2, p * 2); }
      }
      sprite(ctx, SHIP, { '#': rgba(T.white), C: rgba(T.cyan), R: rgba(T.red, 0.4 + 0.6 * audio.bass) }, snap(shipX - p * 5.5, p), snap(shipY, p), p);
      box(ctx, rgba(T.green), 0, h - p * 10, w, p);
      hud(ctx, `SCORE ${pad(score, 6)}`, p * 8, p * 6, p * 6, rgba(T.white));
      hud(ctx, `WAVE ${wave}`, w - p * 8, p * 6, p * 6, rgba(T.yellow), 'right');
      const lp = Math.max(1, p / 2), green = rgba(T.green);
      for (let i = 0; i < 3; i++) sprite(ctx, SHIP, { '#': green, C: green, R: green }, p * (8 + i * 14), h - p * 8.5, lp);
      crt(ctx, w, h, time, p);
    },
  };
}

// ---------------------------------------------------------------- Beat Runner
const ROBOT = [
  ['..WWWWWW..', '.WWWWWWWW.', '.WCCCCCCW.', '.WCKCCKCW.', '.WWWWWWWW.', '..OOOOOO..', '.OOOOOOOO.', 'WOOOOOOOOW', '..OOOOOO..', '..OO..OO..', '.OO....OO.', '.KK....KK.'],
  ['..WWWWWW..', '.WWWWWWWW.', '.WCCCCCCW.', '.WCKCCKCW.', '.WWWWWWWW.', '..OOOOOO..', 'WOOOOOOOOW', '.OOOOOOOO.', '..OOOOOO..', '...OOOO...', '...OO.OO..', '...KK.KK..'],
];
const CLOUD = ['...####...', '.########.', '##########', '.########.'];
function makeRunner() {
  const clock = new PhaseClock(), edge = new BeatEdge();
  let jumpStart = null, jumpDur = 0.5, obstacles = [], coins = 0;
  return {
    draw(ctx, w, h, { time, audio }) {
      const p = pixelFor(w, h, 150), t = p * 8, heroX = snap(w * 0.28, p);
      const speed = t * (4 + 4 * Math.min(Math.max((audio.bpm - 70) / 90, 0), 1));
      const dist = clock.advance(time, speed);
      if (edge.isNewBeat(audio) && audio.beatCount % 2 === 0) {
        const bl = beatLength(audio);
        jumpStart = time; jumpDur = Math.min(0.6, bl * 1.2);
        const arrival = dist + heroX + p * 15 + speed * (bl * 2 + jumpDur / 2);
        if (hash01(audio.beatCount, 5) < 0.75) { const pipe = hash01(audio.beatCount, 6) < 0.6; obstacles.push({ tile: Math.floor(arrival / t) - 1, pipe, height: pipe ? 1 + Math.floor(hash01(audio.beatCount, 7) * 2) : 0 }); }
        coins++;
      }
      obstacles = obstacles.filter(o => o.tile * t >= dist - t * 40);
      const ground = snap(h * 0.78, t);
      ['#4FB3FF', '#6EC6FF', '#8ED4FF', '#B5E8FF'].forEach((c, i) => box(ctx, c, 0, ground * i / 4, w, ground / 4 + 1));
      for (let i = 0; i < 5; i++) {
        const span = w + t * 12, raw = hash01(i, 1) * span - dist * 0.1, x = raw - Math.floor(raw / span) * span - t * 6;
        pixelCloud(ctx, snap(x, p), snap(h * (0.08 + 0.25 * hash01(i, 2)), p), p * 3);
      }
      [[0.2, '#4CAF7A', 0.22], [0.45, '#2E8B57', 0.12]].forEach(([k, color, height], layer) => {
        const step = p * 4;
        for (let x = 0; x < w; x += step) { const world = (x + dist * k) / (t * 6), hh = h * height * (0.5 + 0.35 * Math.sin(world + layer * 2) + 0.15 * Math.sin(world * 2.7)); box(ctx, color, x, snap(ground - hh, step), step + 0.5, hh + step); }
      });
      const first = Math.floor(dist / t);
      for (let i = first; i <= first + Math.floor(w / t) + 2; i++) {
        if (obstacles.some(o => !o.pipe && i >= o.tile && i < o.tile + 2)) continue;
        const x = i * t - dist;
        box(ctx, '#C8742C', x, ground, t + 0.5, h - ground);
        for (let y = ground + p * 2, row = 0; y < h; y += t / 2, row++) { box(ctx, '#8A4A1C', x, y, t, p * 0.6); box(ctx, '#8A4A1C', x + (row % 2 === 0 ? 0 : t / 2), y, p * 0.6, t / 2); }
        box(ctx, '#5BD15B', x, ground, t + 0.5, p * 2);
      }
      for (const o of obstacles) {
        if (!o.pipe) continue;
        const x = o.tile * t - dist, ph = t * o.height;
        box(ctx, '#3CC14A', x + p, ground - ph, t * 2 - p * 2, ph); box(ctx, '#3CC14A', x, ground - ph, t * 2, t * 0.6);
        box(ctx, '#9BF59E', x + p * 3, ground - ph, p * 2, ph);
        ctx.strokeStyle = rgba(T.black); ctx.lineWidth = p; ctx.strokeRect(x + p, ground - ph, t * 2 - p * 2, ph); ctx.strokeRect(x, ground - ph, t * 2, t * 0.6);
      }
      for (const o of obstacles) for (let c = 0; c < 3; c++) {
        const x = o.tile * t - dist + t * c, y = ground - t * (o.height + 2) - t * (c === 1 ? 0.8 : 0), cw = Math.max(p, snap(t * 0.5 * Math.abs(Math.cos(time * 5 + c + o.tile)), p)), cx = x + t / 2 - cw / 2;
        box(ctx, rgba(T.yellow), cx, y, cw, t * 0.7); ctx.strokeStyle = '#B8860B'; ctx.lineWidth = p; ctx.strokeRect(cx, y, cw, t * 0.7);
        if (audio.treble > 0.5 && hash01(c + o.tile, Math.floor(time * 8)) > 0.6) { box(ctx, '#fff', cx + cw, y - p * 2, p, p * 3); box(ctx, '#fff', cx + cw - p, y - p, p * 3, p); }
      }
      const j = jumpStart === null ? -1 : (time - jumpStart) / jumpDur, jump = snap((j >= 0 && j <= 1 ? 3.5 * Math.sin(Math.PI * j) : 0) * t, p);
      const frame = jump > 0 ? 1 : Math.floor(beatProgress(audio, time) * 2) % 2;
      sprite(ctx, ROBOT[frame], { W: rgba(T.white), C: rgba(T.cyan), K: rgba(T.black), O: rgba(T.orange) }, heroX, ground - p * 36 - jump, p * 3);
      hud(ctx, `BEAT ${pad(audio.beatCount % 10000, 4)}   COINS x${pad(coins % 100, 2)}`, p * 8, p * 6, p * 6, '#fff');
      crt(ctx, w, h, time, p);
    },
  };
}
function pixelCloud(ctx, x, y, p) { ctx.fillStyle = rgba(T.white); pixelSprite(ctx, CLOUD, x, y, p); }

export const arcade = {
  id: 'arcade', name: 'Retro Arcade', accent: T.yellow,
  wallpapers: [
    { id: 'arcade.maze-chase', name: 'Maze Chase', summary: 'A hungry chomper clears a maze two tiles per beat with bugs on its tail.', make: makeMaze },
    { id: 'arcade.star-shooter', name: 'Star Shooter', summary: 'Your ship fires on every beat at a marching swarm of pixel bugs.', make: makeShooter },
    { id: 'arcade.beat-runner', name: 'Beat Runner', summary: 'A little robot jumps pipes and pits right on the beat.', make: makeRunner },
  ],
};

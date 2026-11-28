// Skateboarding collection, ported from BeatsWall/Collections/Skateboarding/*.swift.
// Metal shaders are approximated: grip tape as speckles, VHS as shifted slices; grain and barrel bend omitted.
import { hex, rgba, hash01, clamp, smoothstep, PhaseClock, BeatEdge, beatProgress, beatLength, twoBoneJoint } from '../kit.js';
import { lin, rad, rrect, circle, lines, dot, ell } from './draw.js';

const T = { ink: hex(0x161616), off: hex(0xF4EFE6), orange: hex(0xFF5A1F), teal: hex(0x2EC4B6), yellow: hex(0xFFD23F), pink: hex(0xFF6B9A), denim: hex(0x2B3A55), skin: hex(0xF2C29B), wood: hex(0xE8C07D), woodShade: hex(0xC99A55), steel: hex(0xB9C0C9), concrete: hex(0xD9D2C5), concreteShade: hex(0xB8AF9F) };
const INK = rgba(T.ink), c = rgba;
const box = (ctx, color, x, y, w, h) => { ctx.fillStyle = color; ctx.fillRect(x, y, w, h); };
const stroke = (ctx, color, width) => { ctx.strokeStyle = color; ctx.lineWidth = width; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke(); };
/** Fills the current path and outlines it in ink. */
const outlined = (ctx, color, width) => { ctx.fillStyle = color; ctx.fill(); stroke(ctx, INK, width); };
/** A thick colored polyline with an ink border. */
function tube(ctx, pts, color, width, outline) { lines(ctx, pts); stroke(ctx, INK, width + outline * 2); lines(ctx, pts); stroke(ctx, color, width); }

// ---------------------------------------------------------------- The skater rig (units; standing height about 10)
const WHEEL = 1.45;
const basePose = () => ({ crouch: 0.15, lean: 0, armsOut: 0.3, armSwing: 0, boardDrop: 0, boardTilt: 0, flip: 0, spin: 0, grab: 0 });
const PALETTE = { shirt: T.orange, cap: T.yellow, deck: T.pink, shoes: T.off };
const trickFor = (beat, strong) => strong ? ['kickflip', 'shuvit', 'grab', 'kickflip', 'shuvit'][Math.min(Math.floor(hash01(beat, 41) * 5), 4)] : 'ollie';
function trickPose(trick, p, base = basePose()) {
  const q = { ...base }, arc = Math.sin(Math.PI * p);
  q.crouch = base.crouch + (0.7 - base.crouch) * arc; q.armsOut = Math.max(base.armsOut, 0.35 + 0.55 * arc);
  q.boardTilt = 0.4 * Math.sin(Math.PI * Math.min(p * 2.2, 1)) * (1 - p);
  if (trick === 'kickflip') { q.flip = smoothstep(0.12, 0.72, p); q.boardDrop = 1.1 * arc; }
  if (trick === 'shuvit') { q.spin = smoothstep(0.1, 0.78, p); q.boardDrop = 0.7 * arc; }
  if (trick === 'grab') { q.grab = smoothstep(0.08, 0.38, p) * (1 - smoothstep(0.62, 0.9, p)); q.crouch = base.crouch + (0.95 - base.crouch) * arc; }
  return q;
}
function skater(ctx, x, y, unit, rotation, facing, pose, palette = PALETTE) {
  const O = 0.32, face = Math.abs(facing) < 0.06 ? (facing < 0 ? -0.06 : 0.06) : facing;
  ctx.save(); ctx.translate(x, y); ctx.rotate(rotation); ctx.scale(unit * face, unit);
  const lean = pose.lean + pose.crouch * 0.3, px = 0.05, py = -(4.75 - pose.crouch * 2);
  const sx = px + Math.sin(lean) * 3, sy = py - Math.cos(lean) * 3, hx = sx + Math.sin(lean) * 1.55, hy = sy - Math.cos(lean) * 1.55;
  // board
  ctx.save(); ctx.translate(0, pose.boardDrop); ctx.rotate(-pose.boardTilt);
  const roll = Math.cos(2 * Math.PI * pose.flip), turn = Math.cos(2 * Math.PI * pose.spin);
  ctx.translate(0, 0.45); ctx.scale(Math.abs(turn) < 0.08 ? (turn < 0 ? -0.08 : 0.08) : turn, Math.abs(roll) < 0.08 ? (roll < 0 ? -0.08 : 0.08) : roll); ctx.translate(0, -0.45);
  for (const wx of [-2.6, 2.6]) { rrect(ctx, wx - 0.65, 0.15, 1.3, 0.45, 0.12); outlined(ctx, c(T.steel), O * 0.8); circle(ctx, wx, 0.95, 0.5); outlined(ctx, c(T.off), O * 0.8); }
  tube(ctx, [[-4.2, -0.5], [-3.35, 0.05], [3.35, 0.05], [4.2, -0.5]], c(roll < 0 ? palette.deck : T.wood), 0.5, O);
  ctx.restore();
  const arm = (hdx, hdy, bend) => {
    const elbow = twoBoneJoint(sx, sy, hdx, hdy, 1.75, 1.65, bend);
    tube(ctx, [elbow, [hdx, hdy]], c(T.skin), 0.62, O); tube(ctx, [[sx, sy], elbow], c(palette.shirt), 0.85, O);
  };
  const leg = (lx, ly, fx, fy, bend) => {
    tube(ctx, [[lx, ly], twoBoneJoint(lx, ly, fx, fy, 2.55, 2.55, bend), [fx, fy]], c(T.denim), 1.15, O);
    tube(ctx, [[fx - 0.55, fy], [fx + 0.65, fy]], c(palette.shoes), 0.6, O);
  };
  const back = -(0.35 + pose.armsOut * 1.25) + pose.armSwing * 0.35;
  arm(sx + Math.sin(back) * 3.2, sy + Math.cos(back) * 3.2, -1);
  leg(px - 0.35, py, -1.7, -0.32, 1); leg(px + 0.45, py, 1.5, -0.32, -1);
  tube(ctx, [[px, py], [sx, sy]], c(palette.shirt), 2, O);
  circle(ctx, hx, hy, 1); outlined(ctx, c(T.skin), O);
  ctx.beginPath(); for (let i = 0; i <= 12; i++) { const a = Math.PI + Math.PI * i / 12, qx = hx + Math.cos(a) * 1.08, qy = hy + Math.sin(a) * 1.08 - 0.08; i === 0 ? ctx.moveTo(qx, qy) : ctx.lineTo(qx, qy); } ctx.closePath(); outlined(ctx, c(palette.cap), O);
  tube(ctx, [[hx + 0.3, hy - 0.12], [hx + 1.75, hy - 0.02]], c(palette.cap), 0.42, O);
  ell(ctx, hx + 0.42, hy + 0.05, 0.26, 0.3); ctx.fillStyle = INK; ctx.fill();
  const reach = 0.35 + pose.armsOut * 1.25 + pose.armSwing * 0.35, rx = sx + Math.sin(reach) * 3.2, ry = sy + Math.cos(reach) * 3.2;
  arm(rx + (3.3 - rx) * pose.grab, ry + (pose.boardDrop - 0.1 - ry) * pose.grab, 1);
  ctx.restore();
}

// ---------------------------------------------------------------- Halfpipe Session
function makeHalfpipe() {
  const clouds = new PhaseClock(), SWING = 1.25, LIP = 72 * Math.PI / 180;
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), O = unit * 0.006, mid = w / 2, bottom = h * 0.84, R = unit * 0.3, flat = unit * 0.32;
      const lx = mid - flat / 2, rx = mid + flat / 2, cy = bottom - R, arc = R * LIP, total = arc * 2 + flat, ground = bottom + unit * 0.05;
      const left = [lx - Math.sin(LIP) * R, cy + Math.cos(LIP) * R], right = [rx + Math.sin(LIP) * R, cy + Math.cos(LIP) * R];
      const surface = s => {
        const d = (s + 1) / 2 * total;
        if (d < arc) { const p = LIP - d / R; return [lx - Math.sin(p) * R, cy + Math.cos(p) * R, p]; }
        if (d < arc + flat) return [lx + d - arc, bottom, 0];
        const p = (d - arc - flat) / R; return [rx + Math.sin(p) * R, cy + Math.cos(p) * R, -p];
      };
      box(ctx, lin(ctx, 0, 0, 0, h * 0.85, [c(T.teal), '#BDEFE9']), 0, 0, w, h);
      const sx = w * 0.8, sy = h * 0.2, sr = unit * 0.08;
      ctx.beginPath();
      for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2 + time * 0.15, o = sr * (1.75 + 0.35 * audio.beatPulse + 0.25 * audio.bass); ctx.moveTo(sx + Math.cos(a) * sr * 1.3, sy + Math.sin(a) * sr * 1.3); ctx.lineTo(sx + Math.cos(a) * o, sy + Math.sin(a) * o); }
      stroke(ctx, INK, unit * 0.014 + O * 2); stroke(ctx, c(T.yellow), unit * 0.014);
      circle(ctx, sx, sy, sr); outlined(ctx, c(T.yellow), O);
      ctx.beginPath(); ctx.moveTo(0, h); for (let s = 0; s <= 40; s++) ctx.lineTo(w * s / 40, h * 0.62 - unit * 0.06 * (Math.sin(s * 0.45) + 0.5 * Math.sin(s * 1.1 + 1))); ctx.lineTo(w, h); ctx.closePath(); ctx.fillStyle = '#6FD3C7'; ctx.fill();
      const drift = clouds.advance(time, 0.012 + 0.03 * audio.level);
      for (let i = 0; i < 4; i++) {
        const span = w + unit * 0.6, x = (hash01(i, 3) * span + drift * unit) % span - unit * 0.3, y = h * (0.1 + 0.25 * hash01(i, 5)), s = unit * (0.05 + 0.04 * hash01(i, 9));
        ctx.beginPath(); for (const [dx, dy, r] of [[-1.2, 0.2, 0.8], [0, -0.3, 1.1], [1.2, 0.15, 0.85], [0.4, 0.4, 0.8], [-0.5, 0.45, 0.75]]) { ctx.moveTo(x + (dx + r) * s, y + dy * s); ctx.arc(x + dx * s, y + dy * s, r * s, 0, Math.PI * 2); }
        stroke(ctx, INK, O * 2); ctx.fillStyle = c(T.off); ctx.fill();
      }
      box(ctx, c(T.concrete), 0, ground, w, h - ground); lines(ctx, [[0, ground], [w, ground]]); stroke(ctx, INK, O);
      const deck = unit * 0.22, top = [[left[0] - deck, left[1]]];
      for (let s = 0; s <= 60; s++) { const [x, y] = surface(-1 + 2 * s / 60); top.push([x, y]); }
      top.push([right[0] + deck, right[1]]);
      const body = () => { lines(ctx, [...top, [right[0] + deck, ground], [left[0] - deck, ground]], true); };
      body(); ctx.fillStyle = c(T.wood); ctx.fill();
      ctx.save(); body(); ctx.clip(); ctx.beginPath();
      for (let x = left[0] - deck + unit * 0.06; x < right[0] + deck; x += unit * 0.075) { ctx.moveTo(x, ground); ctx.lineTo(x, left[1]); }
      ctx.moveTo(left[0] - deck, ground); ctx.lineTo(left[0], left[1] + unit * 0.02); ctx.moveTo(right[0] + deck, ground); ctx.lineTo(right[0], left[1] + unit * 0.02);
      stroke(ctx, c(T.woodShade), O * 1.4); ctx.restore();
      body(); stroke(ctx, INK, O);
      tube(ctx, top, '#8A93A0', unit * 0.014, O);
      for (const [x, y] of [left, right]) { circle(ctx, x, y, unit * 0.011); outlined(ctx, c(T.steel), O); }
      const u = unit * 0.024, beat = beatProgress(audio, time), s = -SWING * Math.cos(Math.PI * beat);
      if (Math.abs(s) <= 1) {
        const [x, y, a] = surface(s), pose = { ...basePose(), crouch: 0.15 + 0.55 * (1 - Math.abs(s)), armsOut: 0.35 + 0.25 * audio.mid, lean: 0.1 };
        skater(ctx, x + Math.sin(a) * WHEEL * u, y - Math.cos(a) * WHEEL * u, u, a, Math.sin(Math.PI * beat) >= 0 ? 1 : -1, pose);
        return;
      }
      const near = Math.round(beat), edge = Math.acos(1 / SWING), p = clamp((Math.PI * (beat - near) + edge) / (2 * edge)), isRight = s > 0;
      const [cx0, cy0] = isRight ? right : left, a = isRight ? -LIP : LIP, ux = isRight ? Math.cos(LIP) : -Math.cos(LIP), uy = -Math.sin(LIP);
      const height = unit * (0.05 + 0.16 * audio.bass) * Math.sin(Math.PI * p), strong = audio.level > 0.3 && hash01(near, 7) > 0.3, turn = Math.cos(Math.PI * p);
      skater(ctx, cx0 + ux * height + Math.sin(a) * WHEEL * u, cy0 + uy * height - Math.cos(a) * WHEEL * u, u, a, (isRight ? 1 : -1) * (turn < 0 ? -1 : 1) * Math.max(Math.abs(turn), 0.6), trickPose(trickFor(near, strong), p));
    },
  };
}

// ---------------------------------------------------------------- Night Street Line
function makeNightStreet() {
  const clock = new PhaseClock(), edge = new BeatEdge();
  let jump = null, obstacles = [];
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), O = unit * 0.005, ground = h * 0.8, skx = w * 0.3;
      const speed = unit * (0.25 + 0.25 * clamp((audio.bpm - 70) / 90) + 0.1 * audio.level), dist = clock.advance(time, speed);
      if (edge.isNewBeat(audio) && audio.beatCount % 2 === 0) {
        const bl = beatLength(audio), duration = Math.min(0.55, bl * 1.1);
        jump = { start: time, duration, trick: trickFor(audio.beatCount, audio.bass > 0.55 && audio.level > 0.3), height: unit * (0.08 + 0.05 * audio.bass) };
        if (hash01(audio.beatCount, 23) < 0.65) obstacles.push({ x: dist + speed * (bl * 2 + duration / 2), kind: Math.floor(hash01(audio.beatCount, 29) * 3) });
      }
      if (jump && time - jump.start > jump.duration) jump = null;
      obstacles = obstacles.filter(o => dist - o.x <= skx + unit * 0.3);
      box(ctx, lin(ctx, 0, 0, 0, ground, ['#0E1230', '#2B2D5C']), 0, 0, w, h);
      ctx.fillStyle = c(T.off, 0.8); ctx.beginPath(); for (let i = 0; i < 70; i++) { const x = hash01(i, 1) * w, y = hash01(i, 2) * h * 0.5, r = unit * 0.0025 * (0.6 + hash01(i, 3) * (0.6 + audio.treble)); ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, Math.PI * 2); } ctx.fill();
      const mr = unit * 0.06, mx = w * 0.82, my = h * 0.17;
      circle(ctx, mx, my, mr); outlined(ctx, c(T.off), O);
      for (const [dx, dy, r] of [[-0.3, -0.2, 0.22], [0.3, 0.25, 0.16], [0.1, -0.45, 0.1]]) dot(ctx, mx + dx * mr, my + dy * mr, r * mr, c(T.concreteShade));
      const slot = unit * 0.15, off = dist * 0.15, first = Math.floor(off / slot) - 1;
      for (let i = first; i < first + Math.floor(w / slot) + 3; i++) {
        const bw = slot * (0.72 + 0.26 * hash01(i, 11)), bh = h * (0.16 + 0.3 * hash01(i, 12)), x = i * slot - off;
        ctx.beginPath(); ctx.rect(x, ground - bh, bw, bh); outlined(ctx, '#1A1F40', O);
        const bin = Math.min(Math.max(Math.floor((x + bw / 2) / w * 32), 0), 31), win = unit * 0.016, cols = Math.max(Math.floor(bw / (win * 2)), 1), rows = Math.floor((bh - win) / (win * 2)), litRows = Math.floor((0.15 + 0.85 * audio.spectrum[bin]) * rows), inset = (bw - cols * win * 2 + win) / 2;
        for (let r = 0; r < rows; r++) for (let k = 0; k < cols; k++) box(ctx, r < litRows && hash01(i * 31 + k, r) > 0.2 ? c(T.yellow, 0.9) : '#262B50', x + inset + k * win * 2, ground - win * 2 - r * win * 2, win, win * 1.2);
      }
      const sp = unit * 0.6, lh = unit * 0.36;
      for (let x = sp - (dist * 0.6) % sp - sp; x < w + sp; x += sp) {
        const hx = x + unit * 0.05, hy = ground - lh;
        lines(ctx, [[hx, hy], [hx - unit * 0.12, ground], [hx + unit * 0.12, ground]], true); ctx.fillStyle = lin(ctx, hx, hy, hx, ground, [c(T.yellow, 0.18 + 0.2 * audio.level), c(T.yellow, 0)]); ctx.fill();
        tube(ctx, [[x, ground], [x, hy], [hx, hy]], '#4A5070', unit * 0.008, O);
        rrect(ctx, hx - unit * 0.025, hy - unit * 0.008, unit * 0.05, unit * 0.018, unit * 0.006); outlined(ctx, c(T.yellow), O);
      }
      const curb = ground + unit * 0.07;
      box(ctx, '#5A5F7E', 0, ground, w, curb - ground); box(ctx, '#3E4262', 0, curb, w, unit * 0.02); box(ctx, '#24273D', 0, curb + unit * 0.02, w, h);
      ctx.beginPath(); ctx.moveTo(0, ground); ctx.lineTo(w, ground); ctx.moveTo(0, curb); ctx.lineTo(w, curb);
      const joint = unit * 0.16; for (let x = -(dist % joint); x < w; x += joint) { ctx.moveTo(x, ground); ctx.lineTo(x - unit * 0.02, curb); }
      ctx.strokeStyle = INK; ctx.lineWidth = O; ctx.stroke();
      const dash = unit * 0.2; for (let x = -(dist % dash); x < w; x += dash) box(ctx, c(T.yellow, 0.8), x, (curb + h) / 2 + unit * 0.02, dash * 0.5, unit * 0.008);
      for (const o of obstacles) {
        const x = skx + o.x - dist;
        if (!(x > -unit * 0.2 && x < w + unit * 0.2)) continue;
        if (o.kind === 0) {
          const s = unit * 0.06; lines(ctx, [[x - s * 0.35, ground], [x - s * 0.08, ground - s], [x + s * 0.08, ground - s], [x + s * 0.35, ground]], true); outlined(ctx, c(T.orange), O);
          box(ctx, c(T.off), x - s * 0.22, ground - s * 0.6, s * 0.44, s * 0.16); ctx.beginPath(); ctx.rect(x - s * 0.45, ground - s * 0.08, s * 0.9, s * 0.1); outlined(ctx, c(T.orange), O);
        } else if (o.kind === 1) {
          const len = unit * 0.16, s = unit * 0.04;
          for (const pts of [[[x - len / 2 + s * 0.3, ground], [x - len / 2 + s * 0.3, ground - s]], [[x + len / 2 - s * 0.3, ground], [x + len / 2 - s * 0.3, ground - s]], [[x - len / 2, ground - s], [x + len / 2, ground - s]]]) tube(ctx, pts, c(T.teal), unit * 0.008, O);
        } else {
          const s = unit * 0.05; ctx.beginPath(); ctx.rect(x - s / 2, ground - s, s, s); outlined(ctx, c(T.wood), O); lines(ctx, [[x - s / 2, ground - s], [x + s / 2, ground]]); stroke(ctx, INK, O);
        }
      }
      const u = unit * 0.022;
      let pose = { ...basePose(), crouch: 0.15 + 0.2 * audio.bass, armSwing: Math.sin(time * 1.7) * 0.25, lean: 0.12 }, height = 0;
      if (jump) { const p = clamp((time - jump.start) / jump.duration); pose = trickPose(jump.trick, p, pose); height = jump.height * Math.sin(Math.PI * p); }
      const sw = u * 9 * (1 - 0.4 * height / (unit * 0.15));
      ell(ctx, skx - sw / 2, ground - u * 0.3, sw, u * 0.8); ctx.fillStyle = 'rgba(0,0,0,0.35)'; ctx.fill();
      skater(ctx, skx, ground - height - WHEEL * u, u, 0, 1, pose, { shirt: T.teal, cap: T.orange, deck: T.yellow, shoes: T.off });
    },
  };
}

// ---------------------------------------------------------------- VHS Skate Tape
function makeVHS() {
  return {
    draw(ctx, w, h, { time, audio }) {
      const unit = Math.min(w, h), O = unit * 0.005, ground = h * 0.74, glitch = 0.12 + 0.88 * audio.beatPulse ** 2 * (0.4 + 0.6 * audio.bass);
      box(ctx, lin(ctx, 0, 0, 0, ground, ['#8FD3E8', '#E9F4EE']), 0, 0, w, h);
      const wall = h * 0.3;
      ctx.beginPath(); ctx.rect(-O, wall, w + O * 2, ground - wall); outlined(ctx, '#C9B8A6', O);
      const bh = unit * 0.035; ctx.beginPath();
      for (let y = wall + bh, r = 0; y < ground; y += bh, r++) { ctx.moveTo(0, y); ctx.lineTo(w, y); for (let x = r % 2 === 0 ? 0 : bh; x < w; x += bh * 2) { ctx.moveTo(x, y - bh); ctx.lineTo(x, y); } }
      stroke(ctx, '#A8937F', O * 0.7);
      for (const [bx, by, br, color] of [[0.3, 0.47, 0.11, T.pink], [0.48, 0.44, 0.13, T.yellow], [0.67, 0.48, 0.1, T.teal]]) { const r = unit * br * (1 + 0.05 * audio.bass); rrect(ctx, w * bx - r * 1.3, h * by - r, r * 2.6, r * 2, r * 0.9); outlined(ctx, c(color), O * 1.5); }
      ctx.save(); ctx.font = `italic 900 ${unit * 0.1}px ui-rounded, system-ui, sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillStyle = INK; ctx.fillText('BEATS', w * 0.49 + unit * 0.006, h * 0.455 + unit * 0.006); ctx.fillStyle = c(T.off); ctx.fillText('BEATS', w * 0.49, h * 0.455); ctx.restore();
      ctx.beginPath(); ctx.rect(-O, ground, w + O * 2, h); outlined(ctx, c(T.concrete), O);
      const start = w * 0.36, end = w * 0.7, lh = unit * 0.07, depth = unit * 0.03, ty = ground - lh;
      ctx.beginPath(); ctx.rect(start + depth, ty + depth, end - start, lh - depth + unit * 0.01); outlined(ctx, c(T.concreteShade), O);
      lines(ctx, [[start, ty], [end, ty], [end + depth, ty + depth], [start + depth, ty + depth]], true); outlined(ctx, c(T.concrete), O);
      lines(ctx, [[start + depth, ty + depth], [end + depth, ty + depth]]); stroke(ctx, c(T.steel), unit * 0.006);
      const line = beatProgress(audio, time) / 8, x = (-0.1 + 1.2 * (line - Math.floor(line))) * w;
      const takeoff = start - unit * 0.14, landOn = start + unit * 0.06, popOff = end + depth, landOff = popOff + unit * 0.22, grindY = lh - depth * 0.5;
      let height = 0, grinding = false, pose = { ...basePose(), crouch: 0.2, lean: 0.1 };
      if (x > takeoff && x < landOn) { const p = (x - takeoff) / (landOn - takeoff); height = grindY * p + unit * 0.06 * Math.sin(Math.PI * p); pose = trickPose('ollie', p, pose); }
      else if (x >= landOn && x <= popOff) { height = grindY; grinding = true; pose.crouch = 0.4; pose.armsOut = 0.85; pose.armSwing = Math.sin(time * 3) * 0.2; }
      else if (x > popOff && x < landOff) { const p = (x - popOff) / (landOff - popOff); height = grindY * (1 - p) + unit * 0.08 * Math.sin(Math.PI * p); pose = trickPose('kickflip', p, pose); }
      const u = unit * 0.02, wy = ground - height;
      if (grinding) {
        ctx.beginPath(); const tick = Math.floor(time * 20), sx = x - u * 2.6;
        for (let i = 0; i < 4 + Math.floor(8 * audio.beatPulse); i++) { const a = Math.PI * (0.85 + 0.25 * hash01(i, tick)), len = unit * 0.03 * (0.4 + hash01(i, tick + 1)); ctx.moveTo(sx, wy); ctx.lineTo(sx + Math.cos(a) * len, wy + Math.sin(a) * len * 0.5); }
        stroke(ctx, c(T.yellow), unit * 0.003);
      }
      skater(ctx, x, wy - WHEEL * u, u, 0, 1, pose, { shirt: T.pink, cap: T.teal, deck: T.orange, shoes: T.off });
      const m = unit * 0.07, secs = Math.floor(time) % 3600;
      ctx.save(); ctx.font = `bold ${unit * 0.04}px ui-monospace, Menlo, monospace`;
      const label = (text, px, py, align, base) => { ctx.textAlign = align; ctx.textBaseline = base; ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillText(text, px + unit * 0.004, py + unit * 0.004); ctx.fillStyle = '#fff'; ctx.fillText(text, px, py); };
      label('PLAY ▶', m, m, 'left', 'top'); label('SP', w - m, m, 'right', 'top'); label('JUN 14 1996', m, h - m, 'left', 'bottom');
      label(`0:${String(Math.floor(secs / 60)).padStart(2, '0')}:${String(secs % 60).padStart(2, '0')}`, w - m, h - m, 'right', 'bottom');
      if (glitch > 0.6) label('TRACKING', w / 2, h - m, 'center', 'bottom');
      ctx.restore();
      // Tape tracking: bands slide sideways, harder on the beat.
      const cv = ctx.canvas;
      if (cv && cv.width) {
        const kx = cv.width / w, ky = cv.height / h, tick = Math.floor(time * 14);
        for (let i = 0; i < 7; i++) {
          if (hash01(i, tick) > glitch) continue;
          const y = hash01(i + 20, tick) * h, band = unit * (0.006 + 0.025 * hash01(i + 40, tick));
          ctx.drawImage(cv, 0, y * ky, cv.width, Math.max(1, band * ky), (hash01(i + 60, tick) - 0.5) * 70 * glitch, y, cv.width / kx, band);
        }
      }
      ctx.fillStyle = 'rgba(0,0,0,0.08)'; for (let y = (time * 20) % 6; y < h; y += 6) ctx.fillRect(0, y, w, 2);
      ctx.fillStyle = rad(ctx, w / 2, h / 2, 0, Math.max(w, h) * 0.62, ['rgba(0,0,0,0)', 'rgba(0,0,0,0)', 'rgba(0,0,0,0.75)']); ctx.fillRect(0, 0, w, h);
    },
  };
}

// ---------------------------------------------------------------- Grip & Stickers
const STICKERS = [['smiley', -0.4, -0.05, -0.2, 0.3], ['bolt', -0.19, 0.18, 0.35, 0.3], ['label', -0.04, -0.17, -0.08, 0.26], ['star', 0.1, 0.17, 0.2, 0.3], ['eye', 0.19, -0.12, 0.1, 0.24], ['flame', 0.41, 0.06, -0.3, 0.3], ['heart', -0.07, 0.22, 0.25, 0.18]];
/** Sticker outlines in a -1...1 box. */
function stickerPath(ctx, kind) {
  ctx.beginPath();
  if (kind === 'star') { for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2 - Math.PI / 2, r = i % 2 === 0 ? 1 : 0.45; i === 0 ? ctx.moveTo(Math.cos(a) * r, Math.sin(a) * r) : ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r); } ctx.closePath(); }
  else if (kind === 'bolt') lines(ctx, [[0.15, -1], [-0.55, 0.12], [-0.02, 0.12], [-0.2, 1], [0.6, -0.2], [0.06, -0.2], [0.3, -1]], true);
  else if (kind === 'smiley' || kind === 'eye') ctx.arc(0, 0, 1, 0, Math.PI * 2);
  else if (kind === 'label') rrect(ctx, -1.9, -0.5, 3.8, 1, 0.25);
  else if (kind === 'flame') { ctx.moveTo(0, 1); ctx.quadraticCurveTo(-0.85, 0.9, -0.75, 0.15); ctx.quadraticCurveTo(-0.65, -0.35, -0.3, -0.6); ctx.quadraticCurveTo(-0.05, -0.75, 0.1, -1); ctx.quadraticCurveTo(0.8, -0.5, 0.75, 0.1); ctx.quadraticCurveTo(0.85, 0.85, 0, 1); ctx.closePath(); }
  else { ctx.moveTo(0, 0.95); ctx.bezierCurveTo(-1.4, 0.05, -0.6, -1.2, 0, -0.45); ctx.bezierCurveTo(0.6, -1.2, 1.4, 0.05, 0, 0.95); ctx.closePath(); }
}
function stickerFace(ctx, kind, time, audio) {
  const fill = color => { ctx.fillStyle = color; ctx.fill(); };
  const oval = (x, y, ow, oh, color) => { ell(ctx, x, y, ow, oh); fill(color); };
  stickerPath(ctx, kind);
  fill({ star: c(T.yellow), bolt: c(T.orange), smiley: c(T.yellow), label: INK, eye: c(T.off), flame: c(T.orange), heart: c(T.pink) }[kind]);
  if (kind === 'smiley') { for (const x of [-0.35, 0.35]) oval(x - 0.11, -0.45, 0.22, 0.36, INK); ctx.beginPath(); ctx.moveTo(-0.55, 0.2); ctx.quadraticCurveTo(0, 0.85, 0.55, 0.2); stroke(ctx, INK, 0.12); }
  if (kind === 'label') { ctx.save(); ctx.scale(0.01, 0.01); ctx.font = '900 56px ui-rounded, system-ui, sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = c(T.yellow); ctx.fillText('BEATSWALL', 0, 3, 340); ctx.restore(); }
  if (kind === 'eye') { const a = time * 0.9 + Math.sin(time * 2.3) * 1.5, k = 0.5 + 0.5 * audio.mid, x = Math.cos(a) * 0.3 * k, y = Math.sin(a) * 0.25 * k; oval(x - 0.5, y - 0.5, 1, 1, c(T.teal)); oval(x - 0.22, y - 0.22, 0.44, 0.44, INK); oval(x - 0.05, y - 0.32, 0.16, 0.16, '#fff'); }
  if (kind === 'flame') { ctx.beginPath(); ctx.moveTo(0, 0.8); ctx.quadraticCurveTo(-0.65, 0.3, 0, -0.25); ctx.quadraticCurveTo(0.6, 0.35, 0, 0.8); fill(c(T.yellow)); }
  stickerPath(ctx, kind); stroke(ctx, INK, 0.09);
}
function makeGrip() {
  const grit = Array.from({ length: 2600 }, (_, i) => [hash01(i, 81), hash01(i, 82), hash01(i, 83)]);
  return {
    draw(ctx, w, h, { time, audio }) {
      const length = Math.min(w * 0.94, h * 2.7), width = length * 0.27, unit = Math.min(w, h);
      box(ctx, c(T.off), 0, 0, w, h);
      const sp = unit * 0.05; ctx.beginPath(); for (let x = -h; x < w; x += sp) { ctx.moveTo(x, h); ctx.lineTo(x + h, 0); } ctx.strokeStyle = c(T.teal, 0.12); ctx.lineWidth = sp * 0.35; ctx.stroke();
      ctx.save(); ctx.translate(w / 2, h / 2); ctx.rotate(-8 * Math.PI / 180);
      const e = unit * 0.014;
      ctx.save(); ctx.shadowColor = 'rgba(0,0,0,0.35)'; ctx.shadowBlur = unit * 0.04; ctx.shadowOffsetY = unit * 0.015; rrect(ctx, -(length + e) / 2, -(width + e) / 2, length + e, width + e, (width + e) / 2); ctx.fillStyle = INK; ctx.fill(); ctx.restore();
      ctx.save(); rrect(ctx, -length / 2, -width / 2, length, width, width / 2); ctx.fillStyle = '#242424'; ctx.fill(); ctx.clip();
      const g = Math.max(1.2, unit * 0.0022), tick = Math.floor(time * 8);
      grit.forEach(([gx, gy, k], i) => {
        const glint = hash01(i, tick) < 0.004 + 0.05 * audio.treble;
        box(ctx, glint ? '#fff' : `rgba(255,255,255,${0.04 + 0.14 * k})`, (gx - 0.5) * length, (gy - 0.5) * width, glint ? g * 1.4 : g, glint ? g * 1.4 : g);
      });
      ctx.restore();
      for (const truck of [-0.3, 0.3]) for (const [du, dv] of [[-0.035, -0.17], [0.035, -0.17], [-0.035, 0.17], [0.035, 0.17]]) {
        const x = (truck + du) * length, y = dv * width, r = width * 0.032, gl = r * (2.5 + 2.5 * audio.bass);
        dot(ctx, x, y, gl, rad(ctx, x, y, 0, gl, [c(T.orange, 0.55 * audio.bass), c(T.orange, 0)]));
        circle(ctx, x, y, r); outlined(ctx, c(T.steel), r * 0.25);
        ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.strokeStyle = INK; ctx.lineWidth = r * 0.22; ctx.stroke();
      }
      const bar = beatProgress(audio, time) / 4, lifted = Math.floor(bar) % STICKERS.length, lift = Math.sin(Math.PI * (bar - Math.floor(bar)));
      STICKERS.forEach(([kind, u, v, rot, size], i) => {
        const raise = i === lifted ? lift : 0, bounce = 1 + 0.16 * audio.beatPulse * (hash01(i, audio.beatCount) > 0.5 ? 1 : 0.3), s = width * size * (bounce + 0.08 * raise) / 2;
        ctx.save(); ctx.translate(u * length, v * width); ctx.rotate(rot + 0.12 * raise * Math.sin(time * 2)); ctx.scale(s, s);
        const off = 0.06 + 0.2 * raise, a = `rgba(0,0,0,${0.35 + 0.15 * raise})`;
        ctx.save(); ctx.translate(off, off); stickerPath(ctx, kind); ctx.fillStyle = a; ctx.fill(); stroke(ctx, a, 0.2); ctx.restore();
        stickerPath(ctx, kind); stroke(ctx, INK, 0.28); stroke(ctx, '#fff', 0.2);
        stickerFace(ctx, kind, time, audio);
        ctx.restore();
      });
      ctx.restore();
    },
  };
}

export const skate = {
  id: 'skate', name: 'Skateboarding', accent: T.orange,
  wallpapers: [
    { id: 'skate.halfpipe', name: 'Halfpipe Session', summary: 'A skater pumps a halfpipe in time, launching higher airs on bigger bass.', make: makeHalfpipe },
    { id: 'skate.night-street', name: 'Night Street Line', summary: 'Cruising a city at night, ollieing obstacles on the beat.', make: makeNightStreet },
    { id: 'skate.vhs-tape', name: 'VHS Skate Tape', summary: 'A ledge line off a worn 90s tape that glitches on every beat.', make: makeVHS },
    { id: 'skate.grip-stickers', name: 'Grip & Stickers', summary: 'Grip tape glinting, stickers bouncing and bolts glowing with the bass.', make: makeGrip },
  ],
};

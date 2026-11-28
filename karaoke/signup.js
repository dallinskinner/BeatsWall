import { connect } from './shared/backend.js';
import { mountWoofie } from './shared/woofie.js';
import { COLLECTIONS, allWallpapers, renderThumb } from './shared/wallpapers/index.js';
import { parseVideoId, lookup, search } from './shared/youtube.js';

const $ = id => document.getElementById(id);
const cfg = window.KARAOKE_CONFIG || {};
const state = { room: '', name: '', song: null, mode: 'single', wallpaperId: allWallpapers()[0].id, scope: 'all', collection: COLLECTIONS[0].id };
let backend, stopWatching = null, step = 0;

const woofie = mountWoofie($('woofie'), { size: 130 });
const HINTS = [
  "Hi, I'm Woofie! Type the 4-letter code from the big screen.",
  "What should I call you when it's your turn?",
  'Find your song! Search, or paste a YouTube link.',
  'Now the fun part: one wallpaper, or shuffle?',
  "You're in! I'll shout your name when you're up.",
];

function show(n) {
  step = n;
  document.querySelectorAll('.step').forEach(s => s.classList.toggle('on', Number(s.dataset.step) === n));
  woofie.say(HINTS[n]);
  const focus = [$('room'), $('name'), $('q').closest('form').hidden ? $('link') : $('q')][n];
  if (focus) focus.focus({ preventScroll: true });
}
document.querySelectorAll('[data-back]').forEach(b => b.addEventListener('click', () => show(step - 1)));
$('helpBtn').addEventListener('click', () => $('faq').showModal());

// ---- Step 0: room
$('room').addEventListener('input', e => { e.target.value = e.target.value.toUpperCase().replace(/[^A-Z]/g, ''); });
$('room').addEventListener('keydown', e => { if (e.key === 'Enter') $('next0').click(); });
$('next0').addEventListener('click', async () => {
  const code = $('room').value.trim();
  $('err0').textContent = '';
  if (code.length !== 4) { $('err0').textContent = 'The code has 4 letters.'; return; }
  try {
    if (!(await backend.roomExists(code))) { $('err0').textContent = "I can't find that room. Check the code on the big screen."; return; }
  } catch { $('err0').textContent = "Couldn't reach the party. Check your connection."; return; }
  state.room = code; show(1);
});

// ---- Step 1: name
$('name').addEventListener('keydown', e => { if (e.key === 'Enter') $('next1').click(); });
$('next1').addEventListener('click', () => {
  const name = $('name').value.trim();
  if (!name) { $('err1').textContent = 'I need a name to shout!'; return; }
  $('err1').textContent = ''; state.name = name; show(2);
});

// ---- Step 2: song
function pickSong(song) {
  state.song = song;
  $('picked').hidden = false;
  $('picked').textContent = '';
  const b = document.createElement('b'); b.textContent = song.title;
  const s = document.createElement('div'); s.className = 'hint'; s.textContent = song.channel || '';
  $('picked').append(b, s);
  $('next2').disabled = false; $('err2').textContent = '';
  woofie.say('Great pick! Ready when you are.', 3000);
}
if (cfg.youtubeKey) $('searchForm').hidden = false;
$('searchForm').addEventListener('submit', async e => {
  e.preventDefault();
  const q = $('q').value.trim(); if (!q) return;
  $('err2').textContent = ''; $('results').replaceChildren();
  try {
    const items = await search(q + ' karaoke', cfg.youtubeKey);
    if (!items.length) $('err2').textContent = 'Nothing found. Try different words.';
    for (const it of items) {
      const li = document.createElement('li'), b = document.createElement('button'), sm = document.createElement('small');
      b.type = 'button'; b.textContent = it.title; sm.textContent = it.channel; b.append(sm);
      b.addEventListener('click', () => pickSong(it));
      li.append(b); $('results').append(li);
    }
  } catch (err) { $('err2').textContent = err.message; }
});
$('link').addEventListener('change', async () => {
  const id = parseVideoId($('link').value);
  if (!id) { if ($('link').value.trim()) $('err2').textContent = "That doesn't look like a YouTube link."; return; }
  $('err2').textContent = 'Checking the video…';
  try { pickSong(await lookup(id)); } catch (err) { $('err2').textContent = err.message; }
});
$('next2').addEventListener('click', () => { if (state.song) { buildPicker(); show(3); } });

// ---- Step 3: wallpaper
function setMode(mode) {
  state.mode = mode;
  $('modeSingle').classList.toggle('on', mode === 'single'); $('modeShuffle').classList.toggle('on', mode === 'shuffle');
  $('singlePane').hidden = mode !== 'single'; $('shufflePane').hidden = mode !== 'shuffle';
  woofie.say(mode === 'single' ? 'Pick the one you like best.' : 'Shuffle changes the wallpaper on every bar. All of them, or one collection?');
}
$('modeSingle').addEventListener('click', () => setMode('single'));
$('modeShuffle').addEventListener('click', () => setMode('shuffle'));

function chip(label, on, onClick) {
  const b = document.createElement('button');
  b.type = 'button'; b.className = 'chip' + (on ? ' on' : ''); b.textContent = label; b.addEventListener('click', onClick);
  return b;
}
let built = false;
function buildPicker() {
  if (built) return; built = true;
  const drawTabs = () => {
    $('collTabs').replaceChildren(...COLLECTIONS.map(c => chip(c.name, c.id === state.collection, () => { state.collection = c.id; drawTabs(); drawThumbs(); })));
  };
  const drawThumbs = () => {
    const coll = COLLECTIONS.find(c => c.id === state.collection);
    $('thumbs').replaceChildren(...coll.wallpapers.map(w => {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'thumb' + (w.id === state.wallpaperId ? ' on' : '');
      const cv = document.createElement('canvas'); cv.width = 320; cv.height = 200; renderThumb(cv, w);
      const sp = document.createElement('span'); sp.textContent = w.name;
      b.append(cv, sp);
      b.addEventListener('click', () => { state.wallpaperId = w.id; drawThumbs(); woofie.say(w.name + '! Nice.', 2500); });
      return b;
    }));
  };
  const drawScope = () => {
    const all = allWallpapers().length;
    $('scopeChips').replaceChildren(
      chip(`All wallpapers (${all})`, state.scope === 'all', () => { state.scope = 'all'; drawScope(); }),
      ...COLLECTIONS.map(c => chip(`${c.name} (${c.wallpapers.length})`, state.scope === c.id, () => { state.scope = c.id; drawScope(); })),
    );
  };
  drawTabs(); drawThumbs(); drawScope();
}

$('submit').addEventListener('click', async () => {
  $('err3').textContent = ''; $('submit').disabled = true;
  const pick = state.mode === 'single' ? { mode: 'single', wallpaperId: state.wallpaperId } : { mode: 'shuffle', scope: state.scope };
  try {
    const id = await backend.addEntry(state.room, {
      name: state.name, pick, song: { videoId: state.song.videoId, title: state.song.title.slice(0, 120) },
    });
    watchQueue(id); show(4); woofie.cheer(3000);
    $('doneTitle').textContent = `${state.name}, you're in!`;
  } catch { $('err3').textContent = "That didn't go through. Try again."; }
  $('submit').disabled = false;
});

// ---- Step 4: live queue
function watchQueue(myId) {
  if (stopWatching) stopWatching();
  stopWatching = backend.watch(state.room, list => {
    const live = list.filter(e => e.status !== 'done');
    const mine = live.findIndex(e => e.id === myId);
    $('doneSub').textContent = mine === -1 ? 'Your song has played. Thanks for singing!'
      : live[mine].status === 'playing' ? "It's your turn. Go sing!" : `${mine} ${mine === 1 ? 'song' : 'songs'} before yours.`;
    $('queue').replaceChildren(...live.map(e => {
      const li = document.createElement('li');
      li.className = (e.id === myId ? 'me ' : '') + (e.status === 'playing' ? 'playing' : '');
      const a = document.createElement('span'), b = document.createElement('span');
      a.textContent = e.name; b.className = 'hint'; b.textContent = e.status === 'playing' ? 'Now singing' : e.song.title.slice(0, 40);
      li.append(a, b); return li;
    }));
  });
}
$('again').addEventListener('click', () => { state.song = null; $('picked').hidden = true; $('next2').disabled = true; $('link').value = ''; show(2); });

// ---- start
(async function init() {
  try {
    backend = await connect();
    $('demo').hidden = backend.kind !== 'local';
  } catch { woofie.say("I couldn't connect. Reload the page and try again."); return; }
  const fromUrl = (new URLSearchParams(location.search).get('room') || '').toUpperCase().replace(/[^A-Z]/g, '').slice(0, 4);
  if (fromUrl) { $('room').value = fromUrl; $('next0').click(); } else show(0);
})();

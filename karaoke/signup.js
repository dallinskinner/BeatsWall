import { connect, REACTIONS } from './shared/backend.js';
import { mountWoofie } from './shared/woofie.js';
import { COLLECTIONS, allWallpapers, findWallpaper, renderThumb } from './shared/wallpapers/index.js';
import { readAudio } from './shared/audio.js';
import { parseVideoId, lookup, search } from './shared/youtube.js';
import { orderQueue, displayName } from './shared/order.js';
import { renderRecap } from './shared/recap.js';

const $ = id => document.getElementById(id);
const cfg = window.KARAOKE_CONFIG || {};
const ME_KEY = 'karaoke:me';
const REACT_GAP_MS = 800;
const state = { room: '', name: '', partner: '', dedication: '', song: null, mode: 'single', wallpaperId: allWallpapers()[0].id, scope: 'all', collection: COLLECTIONS[0].id };
let backend, step = 0;
let entries = [], now = null;   // the room's queue and what the TV is doing
let myIds = new Set();          // the songs signed up from this phone
let editing = null;             // id of the song being changed
let stopWatching = [];
const alerted = new Set();      // alerts already shown

const woofie = mountWoofie($('woofie'), { size: 130 });
const HINTS = [
  "Hi, I'm Woofie! Type the 4-letter code from the big screen.",
  "What should I call you when it's your turn?",
  'Find your song! Search, or paste a YouTube link.',
  'Now the fun part: one wallpaper, or shuffle?',
];

// ---- remembering this phone across reloads
const loadMe = () => { try { return JSON.parse(localStorage.getItem(ME_KEY)) || null; } catch { return null; } };
const saveMe = () => { try { localStorage.setItem(ME_KEY, JSON.stringify({ room: state.room, name: state.name, ids: [...myIds] })); } catch { /* private mode */ } };

function show(n) {
  step = n;
  document.querySelectorAll('.step').forEach(s => s.classList.toggle('on', Number(s.dataset.step) === n));
  if (n < HINTS.length) woofie.say(HINTS[n]);
  const editLabel = editing ? 'Changing your song' : null;
  $('eyebrow2').textContent = editLabel || 'Step 3'; $('eyebrow3').textContent = editLabel || 'Step 4';
  $('submit').textContent = editing ? 'Save changes' : 'Put me in the queue';
  if (n === 3) startPreview(); else stopPreview();
  if (n === 4) renderLive();
  const focus = [$('room'), $('name'), $('searchForm').hidden ? $('link') : $('q')][n];
  if (focus) focus.focus({ preventScroll: true });
}
const showLive = message => { editing = null; show(4); if (message) woofie.say(message, 4000); };
document.querySelectorAll('[data-back]').forEach(b => b.addEventListener('click', () => {
  if (editing && step === 2) showLive(); else show(step - 1);
}));
$('helpBtn').addEventListener('click', () => $('faq').showModal());

// ---- Step 0: room
async function joinRoom() {
  const code = $('room').value.trim();
  $('err0').textContent = '';
  if (code.length !== 4) { $('err0').textContent = 'The code has 4 letters.'; return false; }
  try {
    if (!(await backend.roomExists(code))) { $('err0').textContent = "I can't find that room. Check the code on the big screen."; return false; }
  } catch { $('err0').textContent = "Couldn't reach the party. Check your connection."; return false; }
  const saved = loadMe();
  state.room = code;
  myIds = new Set(saved && saved.room === code ? saved.ids : []);
  watchRoom();
  return true;
}
$('room').addEventListener('input', e => { e.target.value = e.target.value.toUpperCase().replace(/[^A-Z]/g, ''); });
$('room').addEventListener('keydown', e => { if (e.key === 'Enter') $('next0').click(); });
$('next0').addEventListener('click', async () => { if (await joinRoom()) show(1); });
$('watchBtn').addEventListener('click', async () => { if (await joinRoom()) showLive('Cheer them on! Send reactions during songs.'); });

// ---- Step 1: names
['name', 'partner', 'dedication'].forEach(id => $(id).addEventListener('keydown', e => { if (e.key === 'Enter') $('next1').click(); }));
$('next1').addEventListener('click', () => {
  const name = $('name').value.trim();
  if (!name) { $('err1').textContent = 'I need a name to shout!'; return; }
  $('err1').textContent = ''; state.name = name;
  state.partner = $('partner').value.trim(); state.dedication = $('dedication').value.trim();
  show(2);
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
function clearSong() {
  state.song = null; $('picked').hidden = true; $('next2').disabled = true;
  $('link').value = ''; $('q').value = ''; $('results').replaceChildren(); $('err2').textContent = '';
}
if (cfg.youtubeKey) $('searchForm').hidden = false;
$('searchForm').addEventListener('submit', async e => {
  e.preventDefault();
  const q = $('q').value.trim(); if (!q) return;
  $('err2').textContent = ''; $('results').replaceChildren(); $('searchBtn').disabled = true;
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
  $('searchBtn').disabled = false;
});
$('link').addEventListener('change', async () => {
  const id = parseVideoId($('link').value);
  if (!id) { if ($('link').value.trim()) $('err2').textContent = "That doesn't look like a YouTube link."; return; }
  $('err2').textContent = 'Checking the video…';
  try { pickSong(await lookup(id)); } catch (err) { $('err2').textContent = err.message; }
});
$('next2').addEventListener('click', () => { if (state.song) { buildPicker(); show(3); } });

// ---- Step 3: wallpaper
let preview = null, previewRaf = 0;
function stopPreview() { cancelAnimationFrame(previewRaf); previewRaf = 0; }
/** Plays the chosen wallpaper in the large preview while step 3 is showing. */
function startPreview() {
  stopPreview();
  if (state.mode !== 'single') return;
  const w = findWallpaper(state.wallpaperId);
  if (!preview || preview.id !== w.id) preview = { id: w.id, inst: w.make() };
  $('previewName').textContent = w.name;
  const cv = $('preview'), ctx = cv.getContext('2d');
  const frame = ms => {
    const t = ms / 1000;
    preview.inst.draw(ctx, cv.width, cv.height, { time: t, audio: readAudio(t) });
    previewRaf = requestAnimationFrame(frame);
  };
  previewRaf = requestAnimationFrame(frame);
}
function setMode(mode) {
  state.mode = mode;
  $('modeSingle').classList.toggle('on', mode === 'single'); $('modeShuffle').classList.toggle('on', mode === 'shuffle');
  $('singlePane').hidden = mode !== 'single'; $('shufflePane').hidden = mode !== 'shuffle';
  if (step === 3) startPreview();
}
const modeHint = mode => woofie.say(mode === 'single' ? 'Tap a wallpaper to watch it move.' : 'Shuffle changes the wallpaper on every bar. All of them, or one collection?');
$('modeSingle').addEventListener('click', () => { setMode('single'); modeHint('single'); });
$('modeShuffle').addEventListener('click', () => { setMode('shuffle'); modeHint('shuffle'); });

function chip(label, on, onClick) {
  const b = document.createElement('button');
  b.type = 'button'; b.className = 'chip' + (on ? ' on' : ''); b.textContent = label; b.addEventListener('click', onClick);
  return b;
}
function drawTabs() {
  $('collTabs').replaceChildren(...COLLECTIONS.map(c => chip(c.name, c.id === state.collection, () => { state.collection = c.id; drawTabs(); drawThumbs(); })));
}
function drawThumbs() {
  const coll = COLLECTIONS.find(c => c.id === state.collection);
  $('thumbs').replaceChildren(...coll.wallpapers.map(w => {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'thumb' + (w.id === state.wallpaperId ? ' on' : ''); b.dataset.id = w.id;
    const cv = document.createElement('canvas'); cv.width = 320; cv.height = 200; renderThumb(cv, w);
    const sp = document.createElement('span'); sp.textContent = w.name;
    b.append(cv, sp);
    b.addEventListener('click', () => {
      state.wallpaperId = w.id;
      for (const t of $('thumbs').children) t.classList.toggle('on', t.dataset.id === w.id);
      startPreview(); woofie.say(w.name + '! Nice.', 2500);
    });
    return b;
  }));
}
function drawScope() {
  const all = allWallpapers().length;
  $('scopeChips').replaceChildren(
    chip(`All wallpapers (${all})`, state.scope === 'all', () => { state.scope = 'all'; drawScope(); }),
    ...COLLECTIONS.map(c => chip(`${c.name} (${c.wallpapers.length})`, state.scope === c.id, () => { state.scope = c.id; drawScope(); })),
  );
}
let built = false;
function buildPicker() {
  if (built) return; built = true;
  drawTabs(); drawThumbs(); drawScope();
}

$('submit').addEventListener('click', async () => {
  $('err3').textContent = ''; $('submit').disabled = true;
  const pick = state.mode === 'single' ? { mode: 'single', wallpaperId: state.wallpaperId } : { mode: 'shuffle', scope: state.scope };
  const song = { videoId: state.song.videoId, title: state.song.title.slice(0, 120) };
  if (editing) {
    try {
      await backend.updateEntry(state.room, editing, { song, pick });
      showLive('Changed! You kept your spot.');
    } catch { $('err3').textContent = "I couldn't change it. Your song may have started."; }
  } else {
    const entry = { name: state.name, song, pick };
    if (state.partner) entry.partner = state.partner;
    if (state.dedication) entry.dedication = state.dedication;
    try {
      const id = await backend.addEntry(state.room, entry);
      myIds.add(id); saveMe(); alertCheck();
      showLive(); woofie.say("You're in! I'll tell you when you're nearly up.", 4000); woofie.cheer(3000);
    } catch { $('err3').textContent = "That didn't go through. Try again."; }
  }
  $('submit').disabled = false;
});

// ---- Step 4: the live view (my songs, reactions, ratings, queue, recap)
function watchRoom() {
  stopWatching.forEach(stop => stop());
  entries = []; now = null;
  stopWatching = [
    backend.watch(state.room, list => {
      entries = list;
      if (editing && !entries.some(e => e.id === editing && e.status === 'queued')) showLive('That song has started, so it stays as it is.');
      alertCheck(); renderLive();
    }),
    backend.watchNow(state.room, value => { now = value; renderLive(); }),
  ];
}

const button = (label, onClick) => {
  const b = document.createElement('button');
  b.type = 'button'; b.className = 'chip'; b.textContent = label; b.addEventListener('click', onClick);
  return b;
};

function startEdit(entry) {
  editing = entry.id; clearSong(); buildPicker();
  const pick = entry.pick || {};
  if (pick.mode === 'shuffle') { state.scope = pick.scope || 'all'; drawScope(); setMode('shuffle'); }
  else {
    const w = findWallpaper(pick.wallpaperId);
    if (w) { state.wallpaperId = w.id; state.collection = w.collection.id; drawTabs(); drawThumbs(); }
    setMode('single');
  }
  pickSong({ videoId: entry.song.videoId, title: entry.song.title });
  show(2); woofie.say('Pick a new song, or keep this one and change the wallpaper.');
}
async function cancelSong(entry) {
  if (!confirm(`Take "${entry.song.title}" out of the queue?`)) return;
  try { await backend.remove(state.room, entry.id); woofie.say('Removed.', 2500); }
  catch { woofie.say("I couldn't remove it. It may have started.", 4000); }
}

function queueRow(e) {
  const mine = myIds.has(e.id);
  const li = document.createElement('li');
  li.className = (mine ? 'me ' : '') + (e.status === 'playing' ? 'playing' : '');
  const row = document.createElement('div'); row.className = 'who';
  const a = document.createElement('span'), b = document.createElement('span');
  a.textContent = displayName(e); b.className = 'hint'; b.textContent = e.status === 'playing' ? 'Now singing' : e.song.title.slice(0, 40);
  row.append(a, b); li.append(row);
  if (mine && e.status === 'queued') {
    const actions = document.createElement('div'); actions.className = 'actions';
    actions.append(button('Change song', () => startEdit(e)), button('Cancel', () => cancelSong(e)));
    li.append(actions);
  }
  return li;
}

function renderLive() {
  if (step !== 4) return;
  const queue = orderQueue(entries);
  const recap = !!now && now.phase === 'recap';
  const singing = queue.findIndex(e => myIds.has(e.id));
  const mine = queue[singing];

  $('liveEyebrow').textContent = recap ? "That's a wrap" : myIds.size ? "You're in!" : 'Audience';
  $('doneTitle').textContent = recap ? "Tonight's show" : !myIds.size ? "You're watching" : state.name ? `${state.name}, you're in!` : "You're in!";
  $('doneSub').textContent = recap ? ''
    : mine ? (mine.status === 'playing' ? "It's your turn. Go sing!" : singing === 0 ? "You're next!" : `${singing} ${singing === 1 ? 'song' : 'songs'} before yours.`)
    : myIds.size ? 'Your songs are done. Thanks for singing!' : 'React and rate while others sing.';
  $('again').textContent = myIds.size ? 'Add another song' : 'Sing a song';
  $('queue').replaceChildren(...(recap ? [] : queue.map(queueRow)));

  $('recap').hidden = !recap;
  if (recap) renderRecap($('recap'), entries);

  $('reactions').hidden = !now || (now.phase !== 'playing' && now.phase !== 'rating');
  const rated = now && now.phase === 'rating' ? entries.find(e => e.id === now.id) : null;
  $('rateCard').hidden = !rated || myIds.has(rated.id);
  if (!$('rateCard').hidden && $('rateCard').dataset.id !== rated.id) {
    $('rateCard').dataset.id = rated.id;
    $('rateName').textContent = `How was ${displayName(rated)}?`;
    $('rateNote').textContent = ''; paintStars(0);
  }
}

// reactions
let lastReact = 0;
$('reactions').replaceChildren(...Object.entries(REACTIONS).map(([key, emoji]) => {
  const b = document.createElement('button');
  b.type = 'button'; b.textContent = emoji; b.setAttribute('aria-label', 'Send ' + key);
  b.addEventListener('click', () => {
    if (performance.now() - lastReact < REACT_GAP_MS) return;
    lastReact = performance.now();
    b.classList.remove('sent'); void b.offsetWidth; b.classList.add('sent');
    backend.sendReaction(state.room, key).catch(() => {});
  });
  return b;
}));

// ratings
const paintStars = n => [...$('stars').children].forEach((b, i) => { b.classList.toggle('on', i < n); b.setAttribute('aria-pressed', String(i < n)); });
$('stars').replaceChildren(...[1, 2, 3, 4, 5].map(n => {
  const b = document.createElement('button');
  b.type = 'button'; b.textContent = '★'; b.setAttribute('aria-label', `${n} ${n === 1 ? 'star' : 'stars'}`);
  b.addEventListener('click', async () => {
    const id = $('rateCard').dataset.id;
    try { await backend.rate(state.room, id, n); paintStars(n); $('rateNote').textContent = 'Vote sent. You can change it until time is up.'; }
    catch { $('rateNote').textContent = "That vote didn't count. Time may be up."; }
  });
  return b;
}));

// "you're nearly up" alerts
function alertCheck() {
  const queue = orderQueue(entries);
  const i = queue.findIndex(e => myIds.has(e.id));
  const e = queue[i];
  const kind = !e ? null : e.status === 'playing' ? 'turn' : i <= 1 ? 'next' : null;
  document.title = kind === 'turn' ? '🎤 Your turn!' : kind === 'next' ? "🎤 You're up next" : 'BeatsWall Karaoke: sign up to sing';
  if (!kind || alerted.has(e.id + kind)) return;
  alerted.add(e.id + kind);
  const message = kind === 'turn' ? "It's your turn. Go sing!" : "You're up next. Get ready!";
  $('flashText').textContent = message; $('flash').hidden = false;
  clearTimeout(alertCheck.timer); alertCheck.timer = setTimeout(() => { $('flash').hidden = true; }, 4000);
  woofie.say(message, 6000); woofie.cheer(5000);
  if (navigator.vibrate) navigator.vibrate([200, 100, 200]);
}
$('flash').addEventListener('click', () => { $('flash').hidden = true; });

$('again').addEventListener('click', () => {
  editing = null; clearSong();
  $('name').value = state.name; $('partner').value = ''; $('dedication').value = '';
  show(1);
});

// ---- start
(async function init() {
  try {
    backend = await connect();
    $('demo').hidden = backend.kind !== 'local';
  } catch { woofie.say("I couldn't connect. Reload the page and try again."); return; }
  const fromUrl = (new URLSearchParams(location.search).get('room') || '').toUpperCase().replace(/[^A-Z]/g, '').slice(0, 4);
  const saved = loadMe();
  if (saved) { state.name = saved.name || ''; $('name').value = state.name; }
  // Came back with a song still waiting? Go straight to the live view.
  if (saved && saved.ids.length && (!fromUrl || fromUrl === saved.room)) {
    $('room').value = saved.room;
    if (await joinRoom()) {
      const stop = backend.watch(state.room, list => {
        queueMicrotask(() => stop());
        if (list.some(e => myIds.has(e.id) && e.status !== 'done')) showLive('Welcome back!'); else show(1);
      });
      return;
    }
    $('err0').textContent = '';
  }
  if (fromUrl) { $('room').value = fromUrl; $('next0').click(); } else show(0);
})();

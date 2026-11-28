import { connect } from '../shared/backend.js';
import { mountWoofie } from '../shared/woofie.js';
import { Stage, DEFAULT_ID } from '../shared/wallpapers/index.js';
import { loadIframeApi } from '../shared/youtube.js';
import { findLyrics, lineIndexAt } from '../shared/lyrics.js';

const $ = id => document.getElementById(id);
const INTERLUDE_MS = 5000;

let backend, code, queue = [], started = false, state = 'idle'; // idle | interlude | playing
let current = null, player = null, lyrics = null, lyricIdx = -2, lyricOffset = 0, shuffling = false, timer = null;

const stage = new Stage($('stage'), {
  onChange: w => { if (shuffling) toast(w.collection ? `${w.collection.name} · ${w.name}` : w.name); },
});
const woofie = mountWoofie($('hostWoofie'), { size: 170 });
function toast(msg) { $('toast').textContent = msg; clearTimeout(toast.t); toast.t = setTimeout(() => { $('toast').textContent = ''; }, 3500); }
const setStage = pick => { shuffling = !!pick && pick.mode === 'shuffle'; stage.setPick(pick || { mode: 'single', wallpaperId: DEFAULT_ID }); };

// ---- queue panel
function renderQueue() {
  const live = queue.filter(e => e.status !== 'done');
  $('qempty').hidden = live.length > 0;
  $('qlist').replaceChildren(...live.map(e => {
    const li = document.createElement('li'); li.className = e.status;
    const t = document.createElement('span'), name = document.createElement('b'), song = document.createElement('small');
    name.textContent = e.name; song.textContent = e.song.title; t.append(name, song);
    li.append(t);
    if (e.status === 'queued') {
      const x = document.createElement('button');
      x.textContent = '✕'; x.title = 'Remove'; x.setAttribute('aria-label', 'Remove ' + e.name);
      x.addEventListener('click', () => backend.remove(code, e.id));
      li.append(x);
    }
    return li;
  }));
}

// ---- the show
function nextQueued() { return queue.find(e => e.status === 'queued'); }

function maybeAdvance() {
  if (!started || state !== 'idle') return;
  const next = nextQueued();
  if (!next) { woofie.say('Scan the code to sing!'); setStage(null); return; }
  current = next; state = 'interlude';
  backend.setStatus(code, next.id, 'playing');
  setStage(next.pick);
  woofie.say(`Up next: ${next.name}!`); woofie.cheer(INTERLUDE_MS);
  $('nowTitle').textContent = next.song.title; $('nowName').textContent = 'Sung by ' + next.name; $('nowbar').hidden = false;
  clearTimeout(timer);
  timer = setTimeout(() => play(next), INTERLUDE_MS);
}

async function play(entry) {
  if (current !== entry) return;
  const YT = await loadIframeApi();
  if (current !== entry) return;
  state = 'playing'; lyrics = null; lyricIdx = -2; lyricOffset = 0;
  $('playerWrap').hidden = false; woofie.say('');
  if (!player) {
    player = new YT.Player('player', {
      width: '100%', height: '100%', videoId: entry.song.videoId,
      playerVars: { autoplay: 1, playsinline: 1, rel: 0, modestbranding: 1 },
      events: { onReady: e => (current ? e.target.playVideo() : e.target.stopVideo()), onStateChange: onPlayerState, onError: () => finish('Hmm, that video can\'t be played here. Next singer!') },
    });
  } else {
    player.loadVideoById(entry.song.videoId);
  }
}

async function onPlayerState(e) {
  if (e.data === 1 && current && lyrics === null) { // first time playing: look up lyrics
    const entry = current;
    lyrics = []; // mark as searching
    const found = await findLyrics(entry.song.title, player.getDuration());
    if (current === entry) { lyrics = found || []; lyricIdx = -2; }
  }
  if (e.data === 0) finish('Give it up for ' + (current ? current.name : 'our singer') + '!');
}

function finish(message) {
  if (state === 'idle') return;
  const entry = current;
  state = 'idle'; current = null; lyrics = null;
  clearTimeout(timer);
  if (player && player.stopVideo) player.stopVideo();
  $('playerWrap').hidden = true; $('nowbar').hidden = true; $('lyNow').textContent = ''; $('lyNext').textContent = '';
  if (entry) backend.setStatus(code, entry.id, 'done');
  woofie.say(message, 4000); woofie.cheer(3500);
  setStage(null);
  setTimeout(maybeAdvance, 3500);
}

// ---- lyrics, driven by the player clock
function tickLyrics() {
  if (state === 'playing' && player && player.getCurrentTime && lyrics && lyrics.length) {
    const idx = lineIndexAt(lyrics, player.getCurrentTime() + lyricOffset);
    if (idx !== lyricIdx) {
      lyricIdx = idx;
      $('lyNow').textContent = idx >= 0 ? lyrics[idx].text || '♪' : '';
      $('lyNext').textContent = lyrics[idx + 1] ? lyrics[idx + 1].text : '';
    }
  }
  requestAnimationFrame(tickLyrics);
}
requestAnimationFrame(tickLyrics);

// ---- controls
$('skip').addEventListener('click', () => { if (state !== 'idle') finish('Skipping ahead!'); });
$('fs').addEventListener('click', () => document.documentElement.requestFullscreen && document.documentElement.requestFullscreen());
addEventListener('keydown', e => {
  if (e.key === 'n' || e.key === 'N') $('skip').click();
  else if (e.key === 'f' || e.key === 'F') $('fs').click();
  else if (e.key === '[') { lyricOffset -= 0.5; toast('Lyrics ' + lyricOffset.toFixed(1) + 's'); }
  else if (e.key === ']') { lyricOffset += 0.5; toast('Lyrics +' + lyricOffset.toFixed(1) + 's'); }
});
$('startBtn').addEventListener('click', () => {
  started = true; $('start').hidden = true;
  woofie.say("Let's sing!", 2500); woofie.cheer();
  setTimeout(maybeAdvance, 1500);
});

// ---- init
(async function init() {
  try { backend = await connect(); } catch { $('code').textContent = 'ERR'; woofie.say("I can't reach the server. Reload to try again."); return; }
  $('demo').hidden = backend.kind !== 'local';
  const saved = localStorage.getItem('karaoke:room');
  if (saved && (await backend.hostOf(saved)) === backend.uid) code = saved;
  else { code = await backend.createRoom(); localStorage.setItem('karaoke:room', code); }
  $('code').textContent = code;
  const joinUrl = new URL('../?room=' + code, location.href).href;
  $('joinUrl').textContent = joinUrl.replace(/^https?:\/\//, '');
  if (window.QRCode) new QRCode($('qr'), { text: joinUrl, width: 96, height: 96 });
  woofie.say('Scan the code to sing!');

  let firstLoad = true;
  backend.watch(code, list => {
    if (firstLoad) { // a reload mid-song leaves 'playing' behind; put it back in line
      firstLoad = false;
      list.filter(e => e.status === 'playing').forEach(e => backend.setStatus(code, e.id, 'queued'));
    }
    const hadNone = !nextQueued();
    queue = list; renderQueue();
    if (hadNone && nextQueued() && started && state === 'idle') { woofie.say(`${nextQueued().name} signed up!`, 3000); maybeAdvance(); }
  });
})();

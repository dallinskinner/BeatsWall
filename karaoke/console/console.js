import { connect } from '../shared/backend.js';
import { orderQueue, moveEntry, displayName } from '../shared/order.js';
import { renderRecap } from '../shared/recap.js';
import { startMic } from '../shared/mic.js';
import { readAudio } from '../shared/audio.js';
import { reactionLayer } from './reactions.js';
import { runScoring } from './scoring.js';
import { mountWoofie } from '../shared/woofie.js';
import { Stage, DEFAULT_ID } from '../shared/wallpapers/index.js';
import { loadIframeApi } from '../shared/youtube.js';
import { findLyrics, lineIndexAt } from '../shared/lyrics.js';

const $ = id => document.getElementById(id);
const INTERLUDE_MS = 5000, SCORE_CHEER_MS = 6000;

let backend, code, queue = [], started = false, state = 'idle'; // idle | interlude | playing | scoring | recap
let scoring = null, mic = null, heard = 0; // heard: reactions during the current song
let current = null, player = null, lyrics = null, lyricIdx = -2, lyricOffset = 0, shuffling = false, timer = null;

const stage = new Stage($('stage'), {
  onChange: w => { if (shuffling) toast(w.collection ? `${w.collection.name} · ${w.name}` : w.name); },
});
const woofie = mountWoofie($('hostWoofie'), { size: 170 });
function toast(msg) { $('toast').textContent = msg; clearTimeout(toast.t); toast.t = setTimeout(() => { $('toast').textContent = ''; }, 3500); }
const setStage = pick => { shuffling = !!pick && pick.mode === 'shuffle'; stage.setPick(pick || { mode: 'single', wallpaperId: DEFAULT_ID }); };

// ---- queue panel
function queueButton(text, label, onClick, disabled = false) {
  const b = document.createElement('button');
  b.textContent = text; b.title = label; b.disabled = disabled; b.setAttribute('aria-label', label);
  b.addEventListener('click', onClick);
  return b;
}
function move(id, step) {
  for (const { id: other, order } of moveEntry(queue, id, step)) backend.setEntry(code, other, { order }).catch(() => {});
}
function renderQueue() {
  const live = orderQueue(queue), waiting = live.filter(e => e.status === 'queued');
  $('qempty').hidden = live.length > 0;
  $('qlist').replaceChildren(...live.map(e => {
    const li = document.createElement('li'); li.className = e.status;
    const t = document.createElement('span'), name = document.createElement('b'), song = document.createElement('small');
    name.textContent = displayName(e); song.textContent = e.song.title; t.append(name, song);
    li.append(t);
    if (e.status === 'queued') {
      const i = waiting.indexOf(e), tools = document.createElement('div');
      tools.className = 'tools';
      tools.append(
        queueButton('▲', `Move ${e.name} up`, () => move(e.id, -1), i === 0),
        queueButton('▼', `Move ${e.name} down`, () => move(e.id, 1), i === waiting.length - 1),
        queueButton('✕', `Remove ${e.name}`, () => backend.remove(code, e.id)),
      );
      li.append(tools);
    }
    return li;
  }));
}

// ---- the show
const nextQueued = () => orderQueue(queue).find(e => e.status === 'queued');
const publish = (phase, id) => backend.setNow(code, id ? { phase, id } : { phase }).catch(() => {});

function maybeAdvance() {
  if (!started || state !== 'idle') return;
  const next = nextQueued();
  if (!next) { woofie.say('Scan the code to sing!'); setStage(null); publish('idle'); return; }
  current = next; state = 'interlude'; heard = 0;
  backend.setStatus(code, next.id, 'playing').catch(() => { if (current === next) abandon(); });
  publish('playing', next.id);
  setStage(next.pick);
  const who = displayName(next);
  woofie.say(next.dedication ? `Up next: ${who}! This one's for ${next.dedication}.` : `Up next: ${who}!`, INTERLUDE_MS);
  woofie.cheer(INTERLUDE_MS);
  $('nowTitle').textContent = next.song.title;
  $('nowName').textContent = `Sung by ${who}` + (next.dedication ? ` · for ${next.dedication}` : '');
  $('nowbar').hidden = false;
  clearTimeout(timer);
  timer = setTimeout(() => play(next), INTERLUDE_MS);
}
/** The singer cancelled just as their turn came up. */
function abandon() {
  clearTimeout(timer); state = 'idle'; current = null; $('nowbar').hidden = true;
  maybeAdvance();
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
      events: {
        onReady: e => (current ? e.target.playVideo() : e.target.stopVideo()),
        onStateChange: onPlayerState,
        onError: () => finish('error'),
      },
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
  if (e.data === 0 && state === 'playing') finish('sung');
}

/** Ends the current song. `result`: 'sung', 'skipped' or 'error'. Only finished songs get scored. */
function finish(result) {
  if (state !== 'interlude' && state !== 'playing') return;
  const entry = current;
  current = null; lyrics = null;
  clearTimeout(timer);
  if (player && player.stopVideo) player.stopVideo();
  $('playerWrap').hidden = true; $('nowbar').hidden = true; $('lyNow').textContent = ''; $('lyNext').textContent = '';
  backend.setEntry(code, entry.id, { status: 'done', result, reactions: heard }).catch(() => {});
  setStage(null);
  if (result !== 'sung') {
    pause(result === 'error' ? "Hmm, that video can't be played here. Next singer!" : 'Skipping ahead!');
    return;
  }
  state = 'scoring';
  woofie.cheer(SCORE_CHEER_MS);
  scoring = runScoring({
    backend, code, entry, woofie, entries: () => queue, mic: () => mic,
    done: ({ stars, votes }) => {
      scoring = null;
      pause(votes ? `${stars.toFixed(1)} stars for ${displayName(entry)}!` : `Give it up for ${displayName(entry)}!`);
    },
  });
}
/** A short breather with a message, then the next singer. */
function pause(message) {
  state = 'idle';
  woofie.say(message, 4000); woofie.cheer(3500);
  publish('idle');
  clearTimeout(timer);
  timer = setTimeout(maybeAdvance, 3500);
}
function skip() {
  if (state === 'scoring') scoring.skip();
  else finish('skipped');
}

// ---- end of the night
function endNight() {
  if (state === 'recap' || !confirm('End the night and show the recap? A song that is playing will be stopped.')) return;
  skip();
  clearTimeout(timer); state = 'recap';
  renderRecap($('recapBody'), queue);
  $('recap').hidden = false;
  woofie.say('What a night! Here are your awards.', 8000); woofie.cheer(8000);
  publish('recap');
}
function resume() {
  $('recap').hidden = true; state = 'idle'; publish('idle');
  maybeAdvance();
}

// ---- microphone
async function toggleMic() {
  const button = $('mic');
  if (mic) {
    mic.stop(); mic = null; stage.audioSource = t => readAudio(t, stage.bpm);
    button.textContent = 'Mic off'; button.setAttribute('aria-pressed', 'false');
    toast('Wallpapers use their own beat');
    return;
  }
  button.disabled = true;
  try {
    mic = await startMic();
    stage.audioSource = t => mic.read(t);
    button.textContent = 'Mic on'; button.setAttribute('aria-pressed', 'true');
    toast('Wallpapers follow the room');
  } catch { toast('The browser did not allow the microphone'); }
  button.disabled = false;
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
$('skip').addEventListener('click', skip);
$('mic').addEventListener('click', toggleMic);
$('end').addEventListener('click', endNight);
$('resume').addEventListener('click', resume);
$('fs').addEventListener('click', () => document.documentElement.requestFullscreen && document.documentElement.requestFullscreen());
addEventListener('keydown', e => {
  if (e.key === 'n' || e.key === 'N') $('skip').click();
  else if (e.key === 'f' || e.key === 'F') $('fs').click();
  else if (e.key === 'm' || e.key === 'M') $('mic').click();
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

  publish('idle');
  const float = reactionLayer($('floaters'));
  backend.watchReactions(code, key => {
    float(key);
    if (state === 'playing' || state === 'interlude') heard++;
    else if (state === 'scoring') woofie.cheer(800);
  });

  let firstLoad = true;
  backend.watch(code, list => {
    if (firstLoad) { // a reload mid-song leaves 'playing' behind; put it back in line
      firstLoad = false;
      list.filter(e => e.status === 'playing').forEach(e => backend.setStatus(code, e.id, 'queued'));
    }
    const hadNone = !nextQueued();
    queue = list; renderQueue();
    if (state === 'recap') renderRecap($('recapBody'), queue);
    // The singer playing right now was removed from somewhere else.
    if (state === 'interlude' && current && !list.some(e => e.id === current.id)) abandon();
    if (hadNone && nextQueued() && started && state === 'idle') { woofie.say(`${displayName(nextQueued())} signed up!`, 3000); maybeAdvance(); }
  });
})();

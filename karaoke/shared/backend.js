// Room + queue storage. Firebase Realtime Database when configured, otherwise a local demo mode.
//
// Room: {
//   host: uid, createdAt,
//   queue: { id: { name, partner?, dedication?, song:{videoId,title}, pick, ts, status, owner,
//                  order?, result?, stars?, votes?, applause?, reactions? } },
//   now: { phase: 'idle' | 'playing' | 'rating' | 'recap', id? },
//   reactions: { uid: { e, ts } },          // each person's latest reaction
//   ratings: { entryId: { uid: 1..5 } },
// }
// status: 'queued' | 'playing' | 'done'     result: 'sung' | 'skipped' | 'error'

const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const newCode = () => Array.from({ length: 4 }, () => LETTERS[Math.floor(Math.random() * LETTERS.length)]).join('');
export const REACTIONS = { heart: '❤️', fire: '🔥', clap: '👏', star: '⭐' };
const sorted = obj => Object.entries(obj || {}).map(([id, e]) => ({ id, ...e })).filter(e => e.song).sort((a, b) => a.ts - b.ts);

function loadScript(src) {
  return new Promise((res, rej) => {
    const s = document.createElement('script');
    s.src = src; s.onload = res; s.onerror = () => rej(new Error('Could not load ' + src));
    document.head.appendChild(s);
  });
}

async function firebaseBackend(cfg) {
  const v = '10.12.2', base = `https://www.gstatic.com/firebasejs/${v}/`;
  await loadScript(base + 'firebase-app-compat.js');
  await Promise.all([loadScript(base + 'firebase-auth-compat.js'), loadScript(base + 'firebase-database-compat.js')]);
  firebase.initializeApp(cfg);
  const cred = await firebase.auth().signInAnonymously();
  const uid = cred.user.uid, db = firebase.database();
  const room = c => db.ref('rooms/' + c);
  const on = (ref, cb) => { const h = ref.on('value', s => cb(s.val())); return () => ref.off('value', h); };
  return {
    kind: 'firebase', uid,
    async createRoom() {
      for (let i = 0; i < 8; i++) {
        const code = newCode();
        const r = await room(code).child('host').transaction(cur => (cur === null ? uid : undefined));
        if (r.committed) { await room(code).child('createdAt').set(firebase.database.ServerValue.TIMESTAMP); return code; }
      }
      throw new Error('Could not create a room, try again.');
    },
    async hostOf(code) { return (await room(code).child('host').get()).val(); },
    async roomExists(code) { return (await room(code).child('host').get()).exists(); },
    async addEntry(code, e) {
      const ref = room(code).child('queue').push();
      await ref.set({ ...e, owner: uid, status: 'queued', ts: firebase.database.ServerValue.TIMESTAMP });
      return ref.key;
    },
    watch: (code, cb) => on(room(code).child('queue'), v => cb(sorted(v))),
    setStatus: (code, id, status) => room(code).child('queue/' + id + '/status').set(status),
    setEntry: (code, id, fields) => room(code).child('queue/' + id).update(fields),
    updateEntry: (code, id, fields) => room(code).child('queue/' + id).update(fields),
    remove: (code, id) => room(code).child('queue/' + id).remove(),
    setNow: (code, now) => room(code).child('now').set(now),
    watchNow: (code, cb) => on(room(code).child('now'), cb),
    sendReaction: (code, e) => room(code).child('reactions/' + uid).set({ e, ts: firebase.database.ServerValue.TIMESTAMP }),
    watchReactions: (code, cb) => on(room(code).child('reactions'), freshReactions(cb)),
    rate: (code, id, stars) => room(code).child(`ratings/${id}/${uid}`).set(stars),
    watchRatings: (code, id, cb) => on(room(code).child('ratings/' + id), v => cb(Object.values(v || {}))),
  };
}

/** Turns snapshots of everyone's latest reaction into one callback per new reaction. */
function freshReactions(cb) {
  let seen = null; // uid -> ts; the first snapshot is history, not news
  return all => {
    const first = seen === null;
    if (first) seen = new Map();
    for (const [who, r] of Object.entries(all || {})) {
      if (seen.get(who) === r.ts) continue;
      seen.set(who, r.ts);
      if (!first && REACTIONS[r.e]) cb(r.e);
    }
  };
}

function localBackend() {
  const key = c => 'karaoke:' + c;
  const read = c => { try { return JSON.parse(localStorage.getItem(key(c))); } catch { return null; } };
  const watchers = new Set(); // this tab's own watchers: neither BroadcastChannel nor 'storage' reports a tab's own writes
  const write = (c, d) => {
    localStorage.setItem(key(c), JSON.stringify(d)); chan.postMessage(c);
    Promise.resolve().then(() => watchers.forEach(w => w(c)));
  };
  const chan = new BroadcastChannel('karaoke');
  let uid = localStorage.getItem('karaoke:uid');
  if (!uid) { uid = 'u' + Math.random().toString(36).slice(2, 10); localStorage.setItem('karaoke:uid', uid); }
  // Demo tabs share one uid, so reactions and votes are counted per tab.
  let voter = sessionStorage.getItem('karaoke:voter');
  if (!voter) { voter = 'v' + Math.random().toString(36).slice(2, 10); sessionStorage.setItem('karaoke:voter', voter); }
  /** Calls cb with select(room) now, and again whenever that part of the room changes. */
  const observe = (code, select, cb) => {
    let last;
    const push = () => {
      const value = select(read(code) || {}), json = JSON.stringify(value);
      if (json !== last) { last = json; cb(value); }
    };
    const onMsg = ev => { if (ev.data === code) push(); };
    const onStorage = ev => { if (ev.key === key(code)) push(); };
    const onOwn = c => { if (c === code) push(); };
    watchers.add(onOwn); chan.addEventListener('message', onMsg); addEventListener('storage', onStorage); push();
    return () => { watchers.delete(onOwn); chan.removeEventListener('message', onMsg); removeEventListener('storage', onStorage); };
  };
  const change = (code, fn) => { const r = read(code); if (r) { fn(r); write(code, r); } };
  const merge = async (code, id, fields) => {
    const r = read(code), e = r && r.queue[id];
    if (!e) throw new Error('That song is no longer in the queue.');
    for (const [k, v] of Object.entries(fields)) { if (v === null) delete e[k]; else e[k] = v; }
    write(code, r);
  };
  return {
    kind: 'local', uid,
    async createRoom() {
      let code; do { code = newCode(); } while (read(code));
      write(code, { host: uid, createdAt: Date.now(), queue: {} });
      return code;
    },
    async hostOf(code) { const r = read(code); return r && r.host; },
    async roomExists(code) { return !!read(code); },
    async addEntry(code, e) {
      const r = read(code), id = 'e' + Date.now().toString(36) + Math.random().toString(36).slice(2, 5);
      r.queue[id] = { ...e, owner: uid, status: 'queued', ts: Date.now() };
      write(code, r); return id;
    },
    watch: (code, cb) => observe(code, r => sorted(r.queue), cb),
    async setStatus(code, id, status) { change(code, r => { if (r.queue[id]) r.queue[id].status = status; }); },
    setEntry: merge,
    async updateEntry(code, id, fields) {
      const e = (read(code) || { queue: {} }).queue[id];
      if (!e || e.status !== 'queued') throw new Error('That song has already started.');
      await merge(code, id, fields);
    },
    async remove(code, id) { change(code, r => { delete r.queue[id]; }); },
    async setNow(code, now) { change(code, r => { r.now = now; }); },
    watchNow: (code, cb) => observe(code, r => r.now || null, cb),
    async sendReaction(code, e) { change(code, r => { (r.reactions ||= {})[voter] = { e, ts: Date.now() }; }); },
    watchReactions: (code, cb) => observe(code, r => r.reactions || {}, freshReactions(cb)),
    async rate(code, id, stars) { change(code, r => { ((r.ratings ||= {})[id] ||= {})[voter] = stars; }); },
    watchRatings: (code, id, cb) => observe(code, r => Object.values((r.ratings || {})[id] || {}), cb),
  };
}

export async function connect() {
  const cfg = (window.KARAOKE_CONFIG || {}).firebase;
  return cfg ? firebaseBackend(cfg) : localBackend();
}

// Room + queue storage. Firebase Realtime Database when configured, otherwise a local demo mode.
//
// Room: { host: uid, createdAt, queue: { id: { name, song:{videoId,title}, pick, ts, status, owner } } }
// status: 'queued' | 'playing' | 'done'

const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const newCode = () => Array.from({ length: 4 }, () => LETTERS[Math.floor(Math.random() * LETTERS.length)]).join('');
const sorted = obj => Object.entries(obj || {}).map(([id, e]) => ({ id, ...e })).sort((a, b) => a.ts - b.ts);

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
    watch(code, cb) {
      const ref = room(code).child('queue');
      const h = ref.on('value', s => cb(sorted(s.val())));
      return () => ref.off('value', h);
    },
    setStatus: (code, id, status) => room(code).child('queue/' + id + '/status').set(status),
    remove: (code, id) => room(code).child('queue/' + id).remove(),
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
    watch(code, cb) {
      const push = () => { const r = read(code); cb(sorted(r && r.queue)); };
      const onMsg = ev => { if (ev.data === code) push(); };
      const onStorage = ev => { if (ev.key === key(code)) push(); };
      const onOwn = c => { if (c === code) push(); };
      watchers.add(onOwn); chan.addEventListener('message', onMsg); addEventListener('storage', onStorage); push();
      return () => { watchers.delete(onOwn); chan.removeEventListener('message', onMsg); removeEventListener('storage', onStorage); };
    },
    async setStatus(code, id, status) { const r = read(code); if (r && r.queue[id]) { r.queue[id].status = status; write(code, r); } },
    async remove(code, id) { const r = read(code); if (r) { delete r.queue[id]; write(code, r); } },
  };
}

export async function connect() {
  const cfg = (window.KARAOKE_CONFIG || {}).firebase;
  return cfg ? firebaseBackend(cfg) : localBackend();
}

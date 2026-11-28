// Who sings when. The console and the phones both use this, so they always show the same order.

const nameKey = n => String(n || '').trim().toLowerCase().replace(/\s+/g, ' ');
export const displayName = e => (e.partner ? `${e.name} & ${e.partner}` : e.name);

/**
 * The songs still to be heard, in playing order:
 * 1. the song playing now,
 * 2. songs the host put in order by hand (`order`),
 * 3. everyone else by turn (first songs before second songs), then by sign-up time.
 * Singers are matched by name, because several people may share one phone.
 */
export function orderQueue(entries) {
  const turns = new Map(); // how many songs each singer has before this one
  const turnOf = new Map();
  for (const e of [...entries].sort((a, b) => a.ts - b.ts)) {
    if (e.result === 'error') continue; // a video that never played doesn't use up a turn
    const k = nameKey(e.name), n = turns.get(k) || 0;
    turnOf.set(e, n); turns.set(k, n + 1);
  }
  const rank = e => (e.status === 'playing' ? 0 : typeof e.order === 'number' ? 1 : 2);
  return entries.filter(e => e.status !== 'done').sort((a, b) =>
    rank(a) - rank(b)
    || (rank(a) === 1 ? a.order - b.order : 0)
    || (turnOf.get(a) || 0) - (turnOf.get(b) || 0)
    || a.ts - b.ts);
}

/**
 * Moves a waiting song up (-1) or down (+1). Returns the new hand-set positions as
 * [{ id, order }] for every waiting song, or an empty list if it can't move.
 */
export function moveEntry(entries, id, step) {
  const waiting = orderQueue(entries).filter(e => e.status === 'queued');
  const from = waiting.findIndex(e => e.id === id), to = from + step;
  if (from < 0 || to < 0 || to >= waiting.length) return [];
  [waiting[from], waiting[to]] = [waiting[to], waiting[from]];
  return waiting.map((e, order) => ({ id: e.id, order }));
}

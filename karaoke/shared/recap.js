// The end-of-night summary, shared by the TV and the phones.
import { displayName } from './order.js';

/** The entry with the highest score above zero; ties go to the earlier sign-up. */
const best = (list, score) => list.reduce((top, e) => (score(e) > (top ? score(top) : 0) ? e : top), null);

/**
 * Returns { songs: [{ name, title, stars, votes }], awards: [{ title, name, detail }] }.
 * Only songs that were actually sung (or skipped part way) are listed. Awards without data are left out.
 */
export function buildRecap(entries) {
  const played = entries.filter(e => e.status === 'done' && e.result !== 'error').sort((a, b) => a.ts - b.ts);
  const songs = played.map(e => ({ name: displayName(e), title: e.song.title, stars: e.stars || 0, votes: e.votes || 0 }));
  const awards = [];
  const add = (title, e, detail) => { if (e) awards.push({ title, name: displayName(e), detail: detail(e) }); };

  // Best average; more votes wins a tie.
  add('Crowd Favorite', best(played, e => (e.votes ? e.stars * 1000 + e.votes : 0)),
    e => `${e.stars.toFixed(1)} stars from ${e.votes} ${e.votes === 1 ? 'vote' : 'votes'}`);
  add('Loudest Cheer', best(played, e => e.applause || 0), e => `${e.applause}% on the applause meter`);
  add('Most Reactions', best(played, e => e.reactions || 0), e => `${e.reactions} ${e.reactions === 1 ? 'reaction' : 'reactions'}`);

  const counts = new Map();
  for (const e of played) for (const n of [e.name, e.partner].filter(Boolean)) {
    const k = n.trim().toLowerCase(), c = counts.get(k) || { name: n.trim(), n: 0 };
    c.n++; counts.set(k, c);
  }
  const marathon = [...counts.values()].reduce((top, c) => (!top || c.n > top.n ? c : top), null);
  if (marathon && marathon.n > 1) awards.push({ title: 'Marathon Singer', name: marathon.name, detail: `${marathon.n} songs` });
  return { songs, awards };
}

/** Fills `root` with the recap. */
export function renderRecap(root, entries) {
  const { songs, awards } = buildRecap(entries);
  const el = (tag, text, cls) => { const n = document.createElement(tag); if (text) n.textContent = text; if (cls) n.className = cls; return n; };
  const awardList = el('div', '', 'awards');
  for (const a of awards) {
    const card = el('div', '', 'award');
    card.append(el('p', a.title, 'eyebrow'), el('b', a.name), el('small', a.detail));
    awardList.append(card);
  }
  const list = el('ol', '', 'setlist');
  for (const s of songs) {
    const li = el('li');
    li.append(el('b', s.name), el('small', s.title + (s.votes ? ` · ★ ${s.stars.toFixed(1)}` : '')));
    list.append(li);
  }
  root.replaceChildren(awardList, songs.length ? list : el('p', 'No songs yet.', 'hint'));
}

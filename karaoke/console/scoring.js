// The scoring screen after a song: the applause meter, then the audience's stars.
import { displayName } from '../shared/order.js';

const SCORE_MS = 15000, APPLAUSE_MS = 6000;
const $ = id => document.getElementById(id);

/**
 * Runs scoring for `entry`, then calls done() once. Results are saved on the entry.
 * `entries()` returns the current queue, `mic()` the running microphone or null.
 * Returns { skip() } to end it early.
 */
export function runScoring({ backend, code, entry, entries, mic, woofie, done }) {
  let votes = [], applause = 0, finished = false;
  const started = performance.now(), listening = mic();
  const average = () => (votes.length ? Math.round((votes.reduce((a, b) => a + b, 0) / votes.length) * 10) / 10 : 0);

  $('scoreName').textContent = displayName(entry);
  $('hype').hidden = !listening;
  $('hypeFill').style.width = '0%'; $('hypeValue').textContent = '';
  $('score').hidden = false;
  woofie.say(listening ? 'Make some noise, and rate on your phone!' : 'Rate it on your phone!', 6000);

  backend.setNow(code, { phase: 'rating', id: entry.id });
  const stopRatings = backend.watchRatings(code, entry.id, list => { votes = list; paint(); });

  function paint() {
    $('scoreStars').textContent = votes.length ? `★ ${average().toFixed(1)}` : '★ –';
    $('scoreVotes').textContent = votes.length === 1 ? '1 vote' : `${votes.length} votes`;
    const rated = entries()
      .map(e => (e.id === entry.id ? { ...e, stars: average(), votes: votes.length } : e))
      .filter(e => e.votes > 0)
      .sort((a, b) => b.stars - a.stars || b.votes - a.votes)
      .slice(0, 3);
    $('leaders').replaceChildren(...rated.map(e => {
      const li = document.createElement('li'), name = document.createElement('span'), score = document.createElement('b');
      name.textContent = displayName(e); score.textContent = `★ ${e.stars.toFixed(1)}`; li.append(name, score);
      return li;
    }));
  }
  paint();

  const meter = setInterval(() => {
    const elapsed = performance.now() - started;
    $('scoreTime').textContent = `${Math.max(0, Math.ceil((SCORE_MS - elapsed) / 1000))}s`;
    if (listening && elapsed < APPLAUSE_MS) {
      applause = Math.max(applause, listening.loudness());
      $('hypeFill').style.width = applause + '%'; $('hypeValue').textContent = applause + '%';
    }
  }, 100);
  const end = setTimeout(finish, SCORE_MS);

  function finish() {
    if (finished) return;
    finished = true;
    clearInterval(meter); clearTimeout(end); stopRatings();
    $('score').hidden = true;
    const result = { stars: average(), votes: votes.length };
    if (listening) result.applause = applause;
    backend.setEntry(code, entry.id, result).catch(() => {});
    done(result);
  }
  return { skip: finish };
}

// Synced lyrics from LRCLIB (https://lrclib.net), the same source the BeatsWall app uses.

export function parseLRC(text) {
  const lines = [];
  for (const raw of text.split(/\r?\n/)) {
    const stamps = [...raw.matchAll(/\[(\d+):(\d+(?:\.\d+)?)\]/g)];
    if (!stamps.length) continue;
    const words = raw.replace(/\[[^\]]*\]/g, '').trim();
    for (const m of stamps) lines.push({ time: Number(m[1]) * 60 + Number(m[2]), text: words });
  }
  return lines.sort((a, b) => a.time - b.time);
}

/** Strips "(Official Video)", "[Karaoke]" and similar from a YouTube title. */
export function cleanTitle(t) {
  return t.replace(/\(.*?\)|\[.*?\]/g, ' ')
    .replace(/\b(official|lyrics?|video|audio|karaoke|hd|4k|instrumental|version|with lyrics)\b/gi, ' ')
    .replace(/\s*[-–—|:]\s*/g, ' ').replace(/\s+/g, ' ').trim();
}

/**
 * Finds synced lyrics for a YouTube title. `duration` (seconds) picks the right version;
 * results more than 8 seconds off are ignored so we don't show the wrong song's words.
 */
export async function findLyrics(title, duration) {
  try {
    const r = await fetch('https://lrclib.net/api/search?q=' + encodeURIComponent(cleanTitle(title)));
    if (!r.ok) return null;
    const records = (await r.json()).filter(x => x.syncedLyrics);
    const fit = duration > 0 ? records.filter(x => Math.abs((x.duration || 0) - duration) <= 8) : records.slice(0, 1);
    fit.sort((a, b) => Math.abs((a.duration || 0) - duration) - Math.abs((b.duration || 0) - duration));
    const lines = fit.length ? parseLRC(fit[0].syncedLyrics) : [];
    return lines.length ? lines : null;
  } catch { return null; }
}

/** Index of the line being sung at `t` seconds, or -1 before the first line. */
export function lineIndexAt(lines, t) {
  let lo = 0, hi = lines.length - 1, ans = -1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (lines[mid].time <= t) { ans = mid; lo = mid + 1; } else hi = mid - 1;
  }
  return ans;
}

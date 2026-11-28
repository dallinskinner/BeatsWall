// YouTube helpers: link parsing, title lookup (oEmbed, no key), search (needs an API key), IFrame player API.

export function parseVideoId(input) {
  const s = (input || '').trim();
  if (/^[\w-]{11}$/.test(s)) return s;
  try {
    const u = new URL(s);
    if (u.hostname === 'youtu.be') return u.pathname.slice(1, 12) || null;
    const v = u.searchParams.get('v');
    if (v) return v.slice(0, 11);
    const m = u.pathname.match(/\/(?:embed|shorts|live)\/([\w-]{11})/);
    if (m) return m[1];
  } catch { /* not a URL */ }
  return null;
}

const decode = html => { const t = document.createElement('textarea'); t.innerHTML = html; return t.value; };

/** Title and channel for a video id, without an API key. */
export async function lookup(videoId) {
  const url = 'https://www.youtube.com/watch?v=' + videoId;
  const r = await fetch('https://www.youtube.com/oembed?format=json&url=' + encodeURIComponent(url));
  if (!r.ok) throw new Error('That video can\'t be used. Try another link.');
  const j = await r.json();
  return { videoId, title: j.title, channel: j.author_name };
}

/** Embeddable video search. Costs 100 quota units per call (about 100 searches a day on the free quota). */
export async function search(query, key) {
  const q = new URLSearchParams({ part: 'snippet', type: 'video', videoEmbeddable: 'true', maxResults: '8', q: query, key });
  const r = await fetch('https://www.googleapis.com/youtube/v3/search?' + q);
  if (!r.ok) throw new Error('Search is unavailable right now. You can paste a link instead.');
  const j = await r.json();
  return (j.items || []).map(i => ({ videoId: i.id.videoId, title: decode(i.snippet.title), channel: decode(i.snippet.channelTitle) }));
}

let apiPromise;
export function loadIframeApi() {
  if (window.YT && window.YT.Player) return Promise.resolve(window.YT);
  if (!apiPromise) {
    apiPromise = new Promise(res => {
      window.onYouTubeIframeAPIReady = () => res(window.YT);
      const s = document.createElement('script');
      s.src = 'https://www.youtube.com/iframe_api';
      document.head.appendChild(s);
    });
  }
  return apiPromise;
}

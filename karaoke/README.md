# BeatsWall Karaoke

Two static sites in one folder, no build step:

| Page | What it is |
|---|---|
| `/` (`index.html`) | **Signup.** Singers join with the room code, choose a YouTube song, then pick one wallpaper (with a moving preview) or shuffle (all wallpapers or one collection). Duets and dedications are optional. Afterwards they can change or cancel their song and get an alert when they're nearly up. The audience (**Just watching**) sends emoji reactions and rates each performance. |
| `/console/` | **Console.** Put it on the TV. Shows a QR code and room code, the live queue (reorder or remove songs), the YouTube video, synced lyrics (LRCLIB), and the chosen wallpaper behind it. After each song: an applause meter, star ratings and a leaderboard. **End night** shows the recap and awards. Woofie hosts. |
| `/console/gallery.html` | Dev page that renders every wallpaper so you can check each one. |

## Try it right now (demo mode)
```
cd karaoke && python3 -m http.server 8000
```
To get demo mode, set `firebase: null` in `config.js` (the committed file points at the live project). Open http://localhost:8000/console/ in one tab (click **Start the show**) and http://localhost:8000/ in another tab of the **same browser**. With no Firebase config the queue lives in that browser, so the two tabs work together.

## Go live (phones sign up, TV plays)
1. **Firebase:** create a project, add a Realtime Database, turn on **Authentication › Anonymous**. Paste the web-app config into `config.js`. Publish `database.rules.json` as the database rules.
2. **YouTube search (optional):** create a YouTube Data API v3 key and put it in `config.js` as `youtubeKey`. In Google Cloud, restrict it to **Websites** (your site's address and `http://localhost:8000/*`) and to **YouTube Data API v3**, because visitors can see it. The free quota allows about 100 searches a day. Without a key, singers paste a link instead.
3. **Deploy:** Vercel, Root Directory `karaoke`, Framework Preset *Other*, no build command.

## How the night works
- **Order:** everyone gets a first turn before anyone gets a second (matched by name), then sign-up time. Songs the host moves by hand stay ahead of later sign-ups.
- **Scoring:** a finished song gets 15 seconds of scoring. Skipped and unplayable songs aren't scored. Singers can't rate their own song.
- **Microphone** (**Mic** button, off by default): wallpapers follow the sound in the room and the applause meter works. The audio is analysed in the browser and never recorded or sent. The mic has to be able to hear the room.
- **Alerts** only work while a phone keeps the page open.

## Console keys
`N` skip · `F` full screen · `M` microphone · `[` / `]` nudge lyrics 0.5s earlier / later (karaoke videos often start later than the original song).

## Known limits
- **Without the mic, the wallpaper beat is simulated** (120 BPM), because a web page can't analyze a YouTube player's audio. Mic beat detection is simple and follows loud bass hits.
- **All 57 wallpapers are ported** from the Swift code (`shared/wallpapers/`, one file per collection). Mac-only features are left out: the lighting desk, album-art stage colors, stage images and song names on stage screens.
- Metal shaders are approximated or dropped: film grain and the VHS tape's barrel bend are omitted; scanlines, glitches, grip tape and the nebula are simpler canvas versions. Check looks in `/console/gallery.html`.
- Some YouTube videos block embedding; the console skips them and moves on.
- Lyrics come from LRCLIB and only show when a version matches the video's length (within 8s).
- Room codes are 4 letters and rooms are readable by any signed-in visitor. Fine for a party, not for private data.

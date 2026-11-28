# BeatsWall Karaoke

Two static sites in one folder, no build step:

| Page | What it is |
|---|---|
| `/` (`index.html`) | **Signup.** Singers join with the room code, choose a YouTube song, then pick one wallpaper or shuffle (all wallpapers or one collection). Woofie guides each step and has a help button. |
| `/console/` | **Console.** Put it on the TV. Shows a QR code and room code, the live queue, the YouTube video, synced lyrics (LRCLIB), and the chosen wallpaper behind it. Woofie hosts: announces the next singer and cheers. |
| `/console/gallery.html` | Dev page that renders every wallpaper so you can check each one. |

## Try it right now (demo mode)
```
cd karaoke && python3 -m http.server 8000
```
Open http://localhost:8000/console/ in one tab (click **Start the show**) and http://localhost:8000/ in another tab of the **same browser**. With no Firebase config the queue lives in that browser, so the two tabs work together.

## Go live (phones sign up, TV plays)
1. **Firebase:** create a project, add a Realtime Database, turn on **Authentication › Anonymous**. Paste the web-app config into `config.js`. Publish `database.rules.json` as the database rules.
2. **YouTube search (optional):** create a YouTube Data API v3 key, restrict it to your site's domain, and put it in `config.js` as `youtubeKey`. Search costs ~100 of the 10,000 free daily units, so about 100 searches a day. Without a key, singers paste a link instead.
3. **Deploy:** Vercel, Root Directory `karaoke`, Framework Preset *Other*, no build command.

## Console keys
`N` skip · `F` full screen · `[` / `]` nudge lyrics 0.5s earlier / later (karaoke videos often start later than the original song).

## Known limits
- **The wallpaper beat is simulated** (120 BPM). A YouTube iframe's audio can't be analyzed by a web page, so wallpapers don't react to the actual song yet. A mic mode (listen to the room) is the planned fix.
- **All 57 wallpapers are ported** from the Swift code (`shared/wallpapers/`, one file per collection). Mac-only features are left out: the lighting desk, album-art stage colors, stage images and song names on stage screens.
- Metal shaders are approximated or dropped: film grain and the VHS tape's barrel bend are omitted; scanlines, glitches, grip tape and the nebula are simpler canvas versions. Check looks in `/console/gallery.html`.
- Some YouTube videos block embedding; the console skips them and moves on.
- Lyrics come from LRCLIB and only show when a version matches the video's length (within 8s).
- Room codes are 4 letters and rooms are readable by any signed-in visitor. Fine for a party, not for private data.

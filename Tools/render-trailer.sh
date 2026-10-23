#!/bin/zsh
# Renders the BeatsWall trailer: 45 s, 1920×1080, 30 fps, cut to the most energetic part of a song.
#
# Usage: Tools/render-trailer.sh <audio file> [output.mp4] [song title] [artist]
#   Title and artist (optional) are used to fetch synced lyrics for the lyrics shot.
#   Add FRAMES=90 to render just the first few seconds as a quick test.
set -e
cd "$(dirname "$0")/.."
AUDIO="${1:?usage: Tools/render-trailer.sh <audio> [out.mp4] [title] [artist]}"
OUT="${2:-$HOME/Movies/BeatsWall Trailer.mp4}"
BUILD="${TMPDIR:-/tmp}/beatswall-trailer-build"

# An unsandboxed Debug build, so it can read the song and write the video anywhere.
xcodebuild -project BeatsWall.xcodeproj -scheme BeatsWall -configuration Debug \
  -derivedDataPath "$BUILD" ENABLE_APP_SANDBOX=NO CODE_SIGN_ENTITLEMENTS= build | grep -E "error:|BUILD" || true

ARGS=(-renderTrailer "$AUDIO" "$OUT")
[[ -n "$3" ]] && ARGS+=("$3")
[[ -n "$4" ]] && ARGS+=("$4")
[[ -n "$FRAMES" ]] && ARGS+=(--frames "$FRAMES")
"$BUILD/Build/Products/Debug/BeatsWall.app/Contents/MacOS/BeatsWall" "${ARGS[@]}" 2>&1 | grep "TRAILER"

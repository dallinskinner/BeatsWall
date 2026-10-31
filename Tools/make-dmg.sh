#!/bin/zsh
# Builds a beta DMG to send to testers: ~/Desktop/BeatsWall-<version>-<build>.dmg
#
# Usage: FEEDBACK_EMAIL=juliantheskinner@gmail.com Tools/make-dmg.sh [days until the beta expires, default 60]
#   FEEDBACK_EMAIL (optional) is where the app's Send Feedback button emails to.
#   UPDATE_URL (optional) is where the app looks for newer builds; it defaults to latest.json
#   in the GitHub repo. NOTES (optional) is a line about what's new.
#   The build number is the commit count, so every new commit gets a higher one.
#
# Then, to tell testers' apps about the build:
#   1. Make a release on GitHub (github.com/dallinskinner/BeatsWall/releases/new) and attach the DMG.
#   2. Commit and push the latest.json this writes. Apps check it every few hours.
set -e
cd "$(dirname "$0")/.."
DAYS="${1:-60}"
EXPIRES=$(date -v+"${DAYS}"d +%Y-%m-%d)
BUILD_NUMBER=$(git rev-list --count HEAD)
UPDATE_URL="${UPDATE_URL:-https://raw.githubusercontent.com/dallinskinner/BeatsWall/main/latest.json}"
WORK="${TMPDIR:-/tmp}/beatswall-dmg"
rm -rf "$WORK"

xcodebuild -project BeatsWall.xcodeproj -scheme BeatsWall -configuration Release \
  -derivedDataPath "$WORK/build" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  BEATSWALL_BETA_EXPIRES="$EXPIRES" \
  BEATSWALL_FEEDBACK_EMAIL="${FEEDBACK_EMAIL:-}" \
  BEATSWALL_UPDATE_URL="$UPDATE_URL" \
  build | grep -E "error:|BUILD" || true

APP="$WORK/build/Build/Products/Release/BeatsWall.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
OUT="$HOME/Desktop/BeatsWall-$VERSION-$BUILD_NUMBER.dmg"

mkdir -p "$WORK/stage"
cp -R "$APP" "$WORK/stage/"
ln -s /Applications "$WORK/stage/Applications"
cat > "$WORK/stage/How to open.txt" <<EOF
BeatsWall beta $VERSION ($BUILD_NUMBER). Runs until $EXPIRES. Needs macOS 15 or later.

1. Drag BeatsWall onto Applications.
2. Open BeatsWall from Applications. macOS will say it can't check it for
   malware, because it's a private beta. Click Done.
3. Open System Settings > Privacy & Security, scroll down and click
   "Open Anyway" next to BeatsWall. You only need to do this once.
4. When asked, allow BeatsWall to capture your Mac's audio. It listens on
   your Mac to find the beat and never records or sends anything.

Please don't share this file. Thanks for testing!
EOF

hdiutil create -volname "BeatsWall" -srcfolder "$WORK/stage" -ov -format UDZO "$OUT" >/dev/null 2>&1
echo "Wrote $OUT (expires $EXPIRES)"

# What testers' apps read to find this build.
cat > latest.json <<EOF
{
  "build": $BUILD_NUMBER,
  "version": "$VERSION",
  "expires": "$EXPIRES",
  "notes": "${NOTES:-}",
  "download": "https://github.com/dallinskinner/BeatsWall/releases/latest"
}
EOF
echo "Wrote latest.json (push it after the GitHub release is up)"

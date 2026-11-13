#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Compila OpenTunes in Release e crea dist/OpenTunes-<versione>.dmg (con il collegamento ad Applicazioni).
# L'app è firmata ad-hoc e non notarizzata: vedi il README per `xattr -dr com.apple.quarantine`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/release"
DIST="$ROOT/dist"

cd "$ROOT"
xcodegen generate
# La chiave Last.fm del progetto (se c'è) arriva dalle variabili d'ambiente.
xcodebuild -scheme OpenTunes -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$BUILD/DerivedData" \
  LASTFM_API_KEY="${LASTFM_API_KEY:-}" LASTFM_API_SECRET="${LASTFM_API_SECRET:-}" build

APP="$BUILD/DerivedData/Build/Products/Release/OpenTunes.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
STAGE="$BUILD/dmg"
DMG="$DIST/OpenTunes-$VERSION.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE" "$DIST"
ditto "$APP" "$STAGE/OpenTunes.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "OpenTunes $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "$DMG"

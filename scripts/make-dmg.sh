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
# Le chiavi Last.fm e la chiave pubblica di Sparkle (se ci sono) arrivano dalle variabili d'ambiente.
xcodebuild -scheme OpenTunes -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$BUILD/DerivedData" \
  LASTFM_API_KEY="${LASTFM_API_KEY:-}" LASTFM_API_SECRET="${LASTFM_API_SECRET:-}" \
  SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}" DISCORD_CLIENT_ID="${DISCORD_CLIENT_ID:-}" build

APP="$BUILD/DerivedData/Build/Products/Release/OpenTunes.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
STAGE="$BUILD/dmg"
DMG="$DIST/OpenTunes-$VERSION.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE" "$DIST"
ditto "$APP" "$STAGE/OpenTunes.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "OpenTunes $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
# Solo il nome del file (non il percorso della CI): così `shasum -a 256 -c OpenTunes-x.y.z.dmg.sha256` funziona
# nella cartella in cui l'utente ha scaricato i due file.
(cd "$(dirname "$DMG")" && shasum -a 256 "$(basename "$DMG")") | tee "$DMG.sha256"
echo "$DMG"

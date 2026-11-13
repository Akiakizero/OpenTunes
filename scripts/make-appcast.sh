#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Crea dist/appcast.xml per Sparkle dai .dmg in dist/, firmati con la chiave privata EdDSA.
# La chiave arriva da SPARKLE_PRIVATE_KEY (secret della CI) e non viene mai scritta su disco.
# Uso: SPARKLE_PRIVATE_KEY=… scripts/make-appcast.sh v1.0.0
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:?tag della release, es. v1.0.0}"
: "${SPARKLE_PRIVATE_KEY:?manca SPARKLE_PRIVATE_KEY}"

GENERATE="$(find "$ROOT/build" -path '*/artifacts/sparkle/Sparkle/bin/generate_appcast' -type f -print -quit)"
if [ -z "$GENERATE" ]; then
  echo "generate_appcast non trovato: compila prima con scripts/make-dmg.sh" >&2
  exit 1
fi

# Solo il .dmg della versione: generate_appcast legge tutti gli archivi della cartella.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$ROOT"/dist/*.dmg "$WORK/"
printf '%s' "$SPARKLE_PRIVATE_KEY" | "$GENERATE" --ed-key-file - \
  --download-url-prefix "https://github.com/Akiakizero/OpenTunes/releases/download/$TAG/" \
  --link "https://github.com/Akiakizero/OpenTunes/releases/tag/$TAG" \
  "$WORK"
cp "$WORK/appcast.xml" "$ROOT/dist/appcast.xml"
echo "$ROOT/dist/appcast.xml"

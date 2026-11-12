#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Registra una porzione dello schermo e la converte in GIF per il README.
# Uso: scripts/record-gif.sh <nome> <x,y,larghezza,altezza in punti> [secondi]
# Esempio: OPENTUNES_DEBUG_SHOW=popover apre il popover all'avvio (vedi CLAUDE.md › Debug).
# Richiede ffmpeg e il permesso Registrazione schermo per il terminale.
# Attenzione: la GIF mostra il brano in riproduzione e ciò che c'è dietro il vetro.
set -euo pipefail

NAME="$1"
RECT="$2"
SECONDS_TO_RECORD="${3:-6}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/media"
TMP="$(mktemp -d)"

mkdir -p "$OUT"
# `screencapture -v -R` va in crash su macOS 27: si cattura una sequenza di fotogrammi.
FPS=3
FRAMES=$((SECONDS_TO_RECORD * FPS))
for i in $(seq -f "%03g" 1 "$FRAMES"); do
  screencapture -x -R "$RECT" "$TMP/frame-$i.png"
  sleep "$(echo "scale=3; 1 / $FPS" | bc)"
done
ffmpeg -loglevel error -y -framerate "$FPS" -i "$TMP/frame-%03d.png" \
  -vf "scale=iw/2:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
  "$OUT/$NAME.gif"
rm -rf "$TMP"
echo "$OUT/$NAME.gif"

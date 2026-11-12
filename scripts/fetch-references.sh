#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# scripts/fetch-references.sh — scarica i sorgenti dei progetti di riferimento
# I sorgenti vanno in reference/ (gitignored). Non eseguire nulla al loro interno.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p reference
grep -qxF 'reference/' .gitignore 2>/dev/null || echo 'reference/' >> .gitignore

repos=(
  ungive/mediaremote-adapter
  ejbills/mediaremote-adapter
  TheBoredTeam/boring.notch
  MrKai77/DynamicNotchKit
  jackson-storm/DynamicNotch
  Lakr233/NotchDrop
  kmikiy/SpotMenu
  sakithb/media-controls
  nbolar/playstatus
  niklhut/MusicMenu
  TrevorBurnham/NowPlayingMenuBar
  dimitarnestorov/MusicBar
  abeljohn/spotify-now-playing
  saivittalb/nowspot
  EnjoyBacon7/cbNP
  xxspell/barik
  levarr/Spotbar
  martinfekete10/Tuneful
  dd00031/now-playing
  theli-ua/osx-scrobbler
  heyvito/audioscrobbler
  p-mng/goscrobble
  web-scrobbler/web-scrobbler
  zfoxer/foo_scrobbler_mac
  wimpysworld/sidra
  wxllow/applemusicrp
  sindresorhus/KeyboardShortcuts
  sparkle-project/Sparkle
  # "da trovare" — trovati il 2026-11-12 (vedi docs/analisi/SINTESI.md)
  serban/menubar-ticker
  jonathangarelick/SoundSeer
  shirkeharsh/mooziac
  justinmdickey/goplaying
  tranxuanthang/lrclib
)

for r in "${repos[@]}"; do
  dest="reference/${r//\//__}"
  if [ -d "$dest" ]; then
    echo "già presente: $r"
  else
    GIT_TERMINAL_PROMPT=0 git clone --depth 1 "https://github.com/$r.git" "$dest" || echo "ERRORE: $r" >> reference/_errori.txt
  fi
done

echo "Fatto. Controlla reference/_errori.txt per i repository non scaricati."

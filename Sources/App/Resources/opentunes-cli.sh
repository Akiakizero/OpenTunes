#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
#
# opentunes — controlla OpenTunes dal terminale (anche da Raycast, Alfred, BetterTouchTool, Keyboard Maestro).
# I comandi passano dall'URL opentunes://…; «now» legge lo stato che l'app scrive in Application Support.
# Installazione: Impostazioni › Integrazioni › Riga di comando.

state="$HOME/Library/Application Support/OpenTunes/now-playing.json"

usage() {
  cat <<'USAGE'
uso: opentunes <comando>

  now                 brano in riproduzione («Artista — Titolo»)
  status              brano, player e stato (riproduzione o pausa)
  json                stato completo in JSON
  play-pause | play | pause | next | previous
  love                love su Last.fm (o preferito in Musica)
  copy-link           copia il link universale song.link
  lyrics              mostra il testo nella finestra flottante
  floating            mostra o nasconde la finestra flottante
  discover | stats | settings
  volume <0-100>      volume di sistema
  seek <±secondi>     avanti o indietro nel brano
USAGE
}

field() {
  /usr/bin/plutil -extract "$1" raw -o - "$state" 2>/dev/null
}

require_state() {
  if [[ ! -f "$state" ]]; then
    echo "OpenTunes non è aperto o i comandi da terminale sono spenti nelle impostazioni." >&2
    exit 1
  fi
}

command="${1:-now}"
case "$command" in
  now)
    require_state
    title="$(field title)"
    if [[ -z "$title" ]]; then echo "Niente in riproduzione"; exit 0; fi
    artist="$(field artist)"
    if [[ -n "$artist" ]]; then echo "$artist — $title"; else echo "$title"; fi
    ;;
  status)
    require_state
    title="$(field title)"
    if [[ -z "$title" ]]; then echo "Niente in riproduzione"; exit 0; fi
    playing="$(field isPlaying)"
    echo "$(field artist) — $title"
    album="$(field album)"; [[ -n "$album" ]] && echo "Album: $album"
    echo "Player: $(field player)"
    if [[ "$playing" == "true" ]]; then echo "Stato: in riproduzione"; else echo "Stato: in pausa"; fi
    ;;
  json)
    require_state
    cat "$state"; echo
    ;;
  play-pause|toggle|play|pause|next|previous|love|copy-link|lyrics|floating|discover|stats|settings)
    /usr/bin/open -g "opentunes://$command"
    ;;
  volume)
    [[ "$2" == <-> ]] || { echo "uso: opentunes volume <0-100>" >&2; exit 2; }
    /usr/bin/open -g "opentunes://volume?level=$2"
    ;;
  seek)
    [[ "$2" =~ '^-?[0-9]+$' ]] || { echo "uso: opentunes seek <±secondi>" >&2; exit 2; }
    /usr/bin/open -g "opentunes://seek?by=$2"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

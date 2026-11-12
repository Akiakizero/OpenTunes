# barik (modulo Now Playing)

- **Repository:** https://github.com/xxspell/barik (fork di mocki-toki/barik)
- **Licenza (dal file LICENSE):** MIT (testo MIT, Copyright 2024 Simon Butenko) — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift + SwiftUI (barra sostitutiva della menu bar)
- **Ultimo commit:** 2026-09-29
- **Versione minima di macOS:** non verificata

## Come legge il brano in riproduzione
`Barik/Widgets/NowPlaying/NowPlayingManager.swift`: lancia `/bin/sh -c "<media-control> stream --no-diff"`
(CLI `media-control` installata **dall'utente con brew**); notifiche Music/Spotify; per i comandi
`media-control toggle-play-pause` con fallback `NSAppleScript`.

## Architettura
Manager → widget (`NowPlayingWidget.swift`) e popup (`NowPlayingPopup.swift`).

## Interfaccia
Widget nella barra e popup con copertina.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `NowPlayingPopup.swift` | layout popup compatto | 1 | Studio |
| Fallback comandi verso AppleScript | se il comando MR fallisce | 0 | Studio |

## Cosa evitare
- Dipendenza da un binario esterno installato via brew.
- `/bin/sh -c` con stringa interpolata: rischio injection e problemi di quoting; usare `Process` con array di argomenti.
- `--no-diff` con artwork: ri-emette centinaia di KB a ogni evento.

## Note per il nostro progetto
1. Includere l'adapter nel bundle, nessuna dipendenza esterna.
2. Mai passare per una shell.

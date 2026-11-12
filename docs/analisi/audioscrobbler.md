# Audioscrobbler (heyvito)

- **Repository:** https://github.com/heyvito/audioscrobbler
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift + SwiftUI + OSAKit
- **Ultimo commit:** 2025-12-22
- **Versione minima di macOS:** non verificata

## Come legge il brano in riproduzione
Solo Apple Music. `Audioscrobbler/Watcher.swift` esegue uno script tramite **OSAKit** con
**`Timer` ogni 1 s**; stato in un enum `PlayerState`.

## Architettura
`Watcher` → `WebService.swift` (firma Last.fm, `track.updateNowPlaying`, `track.scrobble`, `track.love`) →
viste del menu.

## Interfaccia
Menu bar con brano corrente, love, profilo.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `WebService.swift` | chiamate firmate Last.fm (api_sig MD5) | 2 | Copia (MIT) |

## Cosa evitare
- Polling ogni secondo.
- In `PlayerState` i casi `playing`/`paused` contengono un **carattere invisibile** (U+200C) nel nome: trappola durante la lettura del codice.

## Note per il nostro progetto
1. Riferimento compatto per l'autenticazione Last.fm della fase 2.

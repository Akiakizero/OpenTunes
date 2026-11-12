# SpotMenu

- **Repository:** https://github.com/kmikiy/SpotMenu
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift + SwiftUI (riscrittura recente)
- **Ultimo commit:** 2026-01-29
- **Versione minima di macOS:** 13.0

## Come legge il brano in riproduzione
`Playback/SpotifyController.swift` e `AppleMusicController.swift` con `NSAppleScript`;
`PlaybackModel.swift` fa **polling con Timer ogni 2 s**. Spotify: script restituisce una stringa
con separatore `|||SEP|||` e `artwork url`; Music: `data of artwork 1 of current track`.
Login opzionale alla Spotify Web API (`SpotifyAuthManager.swift`).

## Architettura
Controller per player → `PlaybackModel` (ObservableObject) → `PlaybackView`.

## Interfaccia
Status item con titolo scorrevole, popover con copertina e slider (`SliderView.swift`).

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Script Spotify con `artwork url` | copertina via URL | 0 — `AppleScriptSource` | Studio |
| `SliderView` | slider di avanzamento | 1 | Studio |

## Cosa evitare
- Polling fisso a 2 s anche a riproduzione ferma.
- Separatori testuali (`|||SEP|||`): si rompono se il titolo contiene il separatore; meglio liste AppleScript.

## Note per il nostro progetto
1. Spotify AppleScript: `duration` in **millisecondi**, `player position` in secondi.
2. Copertina Spotify solo come URL → download asincrono con cache.

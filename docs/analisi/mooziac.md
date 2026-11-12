# Mooziac

- **Repository:** https://github.com/shirkeharsh/mooziac (trovato via API di ricerca GitHub; autore Harsh Shirke)
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì** (attenzione: include uBlock Origin Lite in `Resources/Extensions/`, GPL-3)
- **Linguaggio e framework:** Swift package (SwiftUI/AppKit + WKWebView), molto JavaScript iniettato
- **Ultimo commit:** 2026-11-03
- **Versione minima di macOS:** 13.0

## Come legge il brano in riproduzione
È un **player** YouTube/YouTube Music, non un lettore di altri player: lo stato viene dal proprio
`WKWebView` (`Web/YTMWebView.swift`, `DOMHealthMonitor.swift`) e viene **pubblicato** con
`MPNowPlayingInfoCenter` (`Core/NowPlayingManager/PlayerControls.swift`).

## Architettura
Manager per testi (`LyricsManager` → LRCLIB `/api/get` e `/api/search`), playlist, download, libreria locale,
status item (`Core/StatusItemManager`).

## Interfaccia
Menu bar player, finestra video, gesti trackpad sul bordo.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `Managers/SyncedLyricsParser.swift` (+ test) | parser LRC sincronizzato | 4 | Copia (MIT) |
| `LyricsManager` (strategia get → search) | ricerca testi LRCLIB | 4 | Studio |

## Cosa evitare
- Mescolare blocker GPL nel bundle di un progetto MIT senza chiarirlo.

## Note per il nostro progetto
1. App che pubblicano su `MPNowPlayingInfoCenter` sono visibili dall'adapter: Mooziac è una buona sorgente di test per "altri player".
2. Strategia testi: prima `get` esatto (artista, titolo, album, durata), poi `search`.

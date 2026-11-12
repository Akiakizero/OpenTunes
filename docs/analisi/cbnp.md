# cbNP

- **Repository:** https://github.com/EnjoyBacon7/cbNP
- **Licenza (dal file LICENSE):** **nessun file LICENSE** — si può copiare codice? **no**, solo studio
- **Linguaggio e framework:** Swift + SwiftUI
- **Ultimo commit:** 2026-09-03
- **Versione minima di macOS:** 26.0 (README)

## Come legge il brano in riproduzione
- `cbNP/MediaRemoteService.swift` — adapter ungive (`Resources/mediaremote-adapter.pl`, framework e test client vendorizzati).
- `cbNP/NowPlayingService.swift` — AppleScript per Music e Spotify; in modalità MediaRemote
  **ricade su AppleScript** di Music se l'adapter non risponde; errori tipizzati
  `AppleScriptError.permissionDenied`, `.noTrackPlaying`.

## Architettura
Servizi → `AppViewModel` → menu bar; invia lo stato a un WebSocket (`WebSocketClient.swift`).

## Interfaccia
Menu bar (`LSUIElement`), nessuna icona nel Dock.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `Resources/VENDORING.md` | documenta commit e data della copia dell'adapter | 0 — nostro `Vendor/mediaremote-adapter/VENDORING.md` | Studio (idea) |
| Errori AppleScript tipizzati | messaggi chiari all'utente | 0 | Studio |

## Cosa evitare
- Binari dell'adapter committati nel repo: preferiamo compilarli da sorgente.

## Note per il nostro progetto
1. Registrare commit e data della copia dell'adapter.
2. Target macOS 26 come noi: conferma che l'approccio regge su Tahoe/Golden Gate.

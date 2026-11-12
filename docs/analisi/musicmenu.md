# MusicMenu

- **Repository:** https://github.com/niklhut/MusicMenu
- **Licenza (dal file LICENSE):** GPL-3.0 — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift 5.10 + SwiftUI, generato con **XcodeGen**
- **Ultimo commit:** 2026-03-22
- **Versione minima di macOS:** 14.0

## Come legge il brano in riproduzione
Solo Apple Music. `Managers/NowPlayingManager.swift` osserva `com.apple.Music.playerInfo`
e rilegge lo stato con `NSAppleScript` (`Bridge/MusicBridge.swift`, con gestione di
`NSAppleScript.errorNumber`). `Utilities/AppleMusicLauncher.swift` avvia Music su richiesta.

## Architettura
Bridge (AppleScript) → Manager osservabile → viste menu bar. Dipendenza SPM: HotKey.

## Interfaccia
Menu bar extra con controlli e scorciatoia globale.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `project.yml` | esempio XcodeGen per app macOS con entitlements e Info.plist | 0 — nostro `project.yml` | Studio |
| `MusicBridge` gestione errori AppleScript | mappa i codici d'errore | 0 | Studio |

## Cosa evitare
- `SWIFT_VERSION 5.10`: noi usiamo Swift 6 con concorrenza stretta.
- Solo Apple Music: nessun fallback multi-player.

## Note per il nostro progetto
1. `project.yml` con `INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`, firma ad-hoc `-` per build locali e CI.
2. `generateEmptyDirectories: true` utile per `DesignSystem/` vuoto.
3. Usare `NSAppleEventsUsageDescription` nell'Info.plist.

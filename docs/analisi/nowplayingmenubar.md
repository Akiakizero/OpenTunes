# NowPlayingMenuBar

- **Repository:** https://github.com/TrevorBurnham/NowPlayingMenuBar
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift + SwiftUI (`MenuBarExtra`), Sparkle
- **Ultimo commit:** 2025-04-12
- **Versione minima di macOS:** non indicata

## Come legge il brano in riproduzione
`NowPlayingObserver.swift`: `MRMediaRemoteRegisterForNowPlayingNotifications` +
`MRMediaRemoteGetNowPlayingInfo` caricate **in-process** con `CFBundleCreate`.

## Architettura
Un solo observer (115 righe) → app `MenuBarExtra`. `LaunchAtLogin.swift`, `SparkleDelegate.swift`.

## Interfaccia
Menu bar extra minimo.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `SparkleDelegate.swift` | integrazione Sparkle minima | 4 | Studio |
| `LaunchAtLogin.swift` | avvio al login (`SMAppService`) | 1 | Studio |

## Cosa evitare
- MediaRemote in-process: **non funziona da macOS 15.4** (ultimo commit aprile 2025). Esempio di ciò che non regge su macOS 27.

## Note per il nostro progetto
1. Conferma che serve l'adapter Perl.
2. Struttura `MenuBarExtra` minimale come punto di partenza della fase 1.

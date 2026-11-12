# NotchDrop

- **Repository:** https://github.com/Lakr233/NotchDrop
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift + SwiftUI + AppKit
- **Ultimo commit:** 2026-05-19
- **Versione minima di macOS:** 14.5 (app), 13.0 (altri target)

## Come legge il brano in riproduzione
Non lo legge: è un "tray" per file nel notch.

## Architettura
`NotchWindowController` + `NotchWindow` + `NotchViewModel` (+`Events`) + `EventMonitors`
(monitor globali di mouse per hover/drag).

## Interfaccia
Area di drop nel notch, condivisione (AirDrop), impostazioni.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `NotchWindow.swift`, `NotchWindowController.swift` | finestra sopra il notch, una per schermo | 3 | Copia (MIT) |
| `EventMonitor(s).swift` | hover senza focus | 3 | Copia (MIT) |
| `Ext+NSScreen.swift` | geometria del notch | 3 | Copia (MIT) |

## Cosa evitare
- La tabella del file 00 indicava "da verificare": la licenza è **MIT**.

## Note per il nostro progetto
1. Buon esempio piccolo e leggibile di finestra notch per la fase 3.

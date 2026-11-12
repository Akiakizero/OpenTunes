# DynamicNotchKit

- **Repository:** https://github.com/MrKai77/DynamicNotchKit
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì** (anche come dipendenza SPM)
- **Linguaggio e framework:** Swift package, SwiftUI + AppKit
- **Ultimo commit:** 2026-02-18
- **Versione minima di macOS:** 13 (`Package.swift`)

## Come legge il brano in riproduzione
Non lo legge: è una libreria UI.

## Architettura
`DynamicNotch` (generico sul contenuto SwiftUI) con stati `expanded`/`compact`/`hidden`,
`DynamicNotchHoverBehavior`, `DynamicNotchStyle` (notch / floating per schermi senza notch),
`DynamicNotchPanel` (NSPanel), `NSScreen+Extensions` (`hasNotch` da `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`).

## Interfaccia
Notch espandibile con transizioni configurabili; fallback "floating" su Mac senza notch.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Intero package | superficie notch | 3 | Dipendenza SPM (MIT) |
| `NSScreen+Extensions` | rilevazione e misura del notch | 3 | Copia (MIT) |

## Cosa evitare
- `BlurModifier`/`VisualEffectView` fatti a mano: la nostra regola chiede materiali di sistema (`.glassEffect`).

## Note per il nostro progetto
1. Candidato principale per la fase 3 (più semplice di Boring Notch, licenza permissiva).
2. Verificare compatibilità con Swift 6 strict concurrency prima di adottarlo.

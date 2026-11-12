# KeyboardShortcuts

- **Repository:** https://github.com/sindresorhus/KeyboardShortcuts
- **Licenza (dal file license):** MIT — si può copiare codice? **sì** (si usa come dipendenza SPM)
- **Linguaggio e framework:** Swift package, SwiftUI + AppKit (Carbon `RegisterEventHotKey`)
- **Ultimo commit:** 2026-09-12
- **Versione minima di macOS:** 10.15

## Come legge il brano in riproduzione
n/a (libreria).

## Architettura
`KeyboardShortcuts.Name` → registrazione globale → `Recorder` (vista SwiftUI per registrare la scorciatoia), salvataggio in UserDefaults.

## Interfaccia
`KeyboardShortcuts.Recorder` per le impostazioni.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Intero package | scorciatoie globali play/pausa/successivo/mostra finestra | 1 | Dipendenza SPM |

## Cosa evitare
- Nulla; usata anche da Boring Notch.

## Note per il nostro progetto
1. Aggiungere in fase 1 a `project.yml` come `packages:`.

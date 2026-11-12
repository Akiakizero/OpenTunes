# MusicBar

- **Repository:** https://github.com/dimitarnestorov/MusicBar
- **Licenza (dal file LICENSE):** **EUPL-1.2** (non "da verificare": verificato) — si può copiare codice? **no** (non è tra MIT/BSD/Apache/GPL-3; EUPL è compatibile con GPL ma la nostra regola non la include) → solo studio
- **Linguaggio e framework:** Objective-C / Objective-C++ + AppKit, Carthage, fastlane
- **Ultimo commit:** 2020-04-26
- **Versione minima di macOS:** 10.12

## Come legge il brano in riproduzione
ScriptingBridge (`macos/Spotify.h`, header generato con `sdp`) e notifiche distribuite
iTunes/Spotify (`GlobalState.m`, `Constants.mm`).

## Architettura
`GlobalState` singleton → `AppDelegate` → `PopoverViewController`.

## Interfaccia
Status item con titolo + popover con copertina e controlli, "Welcome Popover".

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Popover di benvenuto al primo avvio | onboarding | 1 | Studio |

## Cosa evitare
- iTunes (non esiste più), progetto fermo dal 2020.
- ScriptingBridge con header generati: fragili tra versioni del player.

## Note per il nostro progetto
1. Licenza EUPL → nessuna copia.
2. Solo idea di onboarding.

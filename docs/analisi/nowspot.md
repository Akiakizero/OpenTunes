# NowSpot

- **Repository:** https://github.com/saivittalb/nowspot
- **Licenza (dal file LICENSE):** Apache-2.0 — si può copiare codice? **sì**
- **Linguaggio e framework:** Objective-C + AppKit
- **Ultimo commit:** 2020-06-28
- **Versione minima di macOS:** non indicata

## Come legge il brano in riproduzione
Quasi identico a Spotify Now Playing (`NowSpot/AppDelegate.m`): notifica
`com.spotify.client.PlaybackStateChanged` + `NSAppleScript`.

## Architettura
Singolo `AppDelegate`.

## Interfaccia
Status item testuale.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| — | niente che non sia già in altri progetti | — | — |

## Cosa evitare
- Progetto fermo dal 2020, solo Spotify, login item via System Events.

## Note per il nostro progetto
1. Nessun riuso; conferma il pattern notifica + AppleScript.

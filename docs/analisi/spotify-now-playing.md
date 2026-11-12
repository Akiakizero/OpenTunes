# Spotify Now Playing

- **Repository:** https://github.com/abeljohn/spotify-now-playing — è il progetto della pagina AlternativeTo (MIT, autore Abel John)
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** Objective-C + AppKit
- **Ultimo commit:** 2021-10-25
- **Versione minima di macOS:** non indicata

## Come legge il brano in riproduzione
`Spotify Now Playing/AppDelegate.m`: notifica `com.spotify.client.PlaybackStateChanged`
(dati da `userInfo`) + `NSAppleScript` per i comandi
(`if application "Spotify" is running then tell application "Spotify" to …`).

## Architettura
Tutto in `AppDelegate.m` (461 righe). `PFMoveApplication` per spostarsi in /Applications.

## Interfaccia
Status item testuale con troncamento manuale del titolo.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Guardia `if application "X" is running` | non avvia il player | 0 | Studio |

## Cosa evitare
- Login item via AppleScript su System Events (obsoleto; usare `SMAppService`).
- Troncamento carattere per carattere del titolo.

## Note per il nostro progetto
1. La guardia "is running" va **dentro** lo script, non solo prima.
2. Il `userInfo` della notifica Spotify basta per titolo/artista/stato.

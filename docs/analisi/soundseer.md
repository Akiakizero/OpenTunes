# SoundSeer

- **Repository:** https://github.com/jonathangarelick/SoundSeer (trovato da AlternativeTo/Product Hunt, autore Jonathan Garelick)
- **Licenza (dal file LICENSE):** **nessun file LICENSE** — si può copiare codice? **no**, solo studio
- **Linguaggio e framework:** Swift + SwiftUI + ScriptingBridge (bridge ObjC)
- **Ultimo commit:** 2024-05-24
- **Versione minima di macOS:** 14.4

## Come legge il brano in riproduzione
`ScriptingBridge/SBApplicationManager.m` crea `SBApplication` per Music e Spotify; modelli
`Models/SpotifyApplication.swift`, `MusicApplication.swift`; `SoundSeerModel.swift` osserva
`com.apple.Music.playerInfo` e `com.spotify.client.PlaybackStateChanged`.
`API/` usa la Spotify Web API per link/info aggiuntive (`Secrets.swift`).

## Architettura
Model → ViewModel → viste; test in `SoundSeerTests`.

## Interfaccia
Titolo in menu bar + menu con azioni (copia link, vai ad artista/album).

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Menu con "copia link brano" e "vai all'album" | azioni rapide | 1, 4 (song.link) | Studio |

## Cosa evitare
- `Secrets.swift` con chiavi nel repo.
- ScriptingBridge richiede header generati e bridging ObjC.

## Note per il nostro progetto
1. Azioni "copia link" e "apri nel player" nel menu della fase 1.

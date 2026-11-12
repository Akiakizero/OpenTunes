# osx-scrobbler

- **Repository:** https://github.com/theli-ua/osx-scrobbler
- **Licenza (dal file LICENSE):** Apache-2.0 — si può copiare codice? **sì** (con NOTICE/attribuzione; Apache-2.0 è compatibile con GPL-3)
- **Linguaggio e framework:** Rust (crate `media-remote` 0.3.6, `rustfm-scrobble-proxy`, `listenbrainz`)
- **Ultimo commit:** 2026-03-24
- **Versione minima di macOS:** non indicata

## Come legge il brano in riproduzione
`src/media_monitor.rs` usa il crate `media-remote` (`NowPlayingInfo`: titolo, artista, album,
`elapsed_time`, `duration`, `bundle_id`, `bundle_name`). Filtra per bundle ID.

## Architettura
Monitor → filtro app (`config.rs`: `allowed_apps`, `ignored_apps`, `scrobble_unknown`) →
`text_cleanup.rs` (regex) → `scrobbler.rs` (Last.fm + ListenBrainz). Alla prima comparsa di un'app
sconosciuta chiede all'utente (`ui/app_dialog.rs`).

## Interfaccia
Menu bar minimale + dialog per le app nuove.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Elenco bundle ID nel README | Spotify `com.spotify.client`, Music `com.apple.Music`, Safari `com.apple.Safari`, Chrome `com.google.Chrome` | 0 — `PlayerApp.known` | Studio |
| Filtro allow/ignore + prompt per app sconosciute | scelta delle sorgenti da scrobblare | 2 | Studio |
| `text_cleanup.rs` | pulizia titoli con regex | 2 | Studio |

## Cosa evitare
- Il crate `media-remote` chiama MediaRemote in-process: dipende dalla versione e dal workaround interno.
- Il README di riferimento indica "elenco dei bundle ID": in realtà è una lista configurabile, non un database.

## Note per il nostro progetto
1. `PlayerApp` deve gestire anche app sconosciute (nome e icona da `NSWorkspace`).
2. Browser: per default **mostrare** ma (in fase 2) non scrobblare.
3. ListenBrainz come seconda destinazione (fase 5).

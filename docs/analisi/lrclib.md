# LRCLIB

- **Repository:** https://github.com/tranxuanthang/lrclib (server di lrclib.net)
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì** (ma è Rust lato server; a noi serve l'API)
- **Linguaggio e framework:** Rust (Axum) + SQLite
- **Ultimo commit:** 2026-11-11
- **Versione minima di macOS:** n/a

## Come legge il brano in riproduzione
n/a (servizio di testi).

## Architettura
`server/src/router.rs`, sotto `/api`: `GET /get` (per metadati: artista, titolo, album, durata),
`GET /get/:track_id`, `GET /search`, `GET /v2/search`, `POST /request-challenge` + `POST /publish`
(proof-of-work), `POST /flag`.

## Interfaccia
n/a.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Contratto `/api/get` e `/api/search` | testi sincronizzati (`syncedLyrics`) e semplici | 4 | Studio |
| `routes/get_lyrics_by_metadata.rs` | come confronta la durata (tolleranza) | 4 | Studio |

## Cosa evitare
- Interrogare `/search` prima di `/get`: `/get` è più preciso e meno costoso.

## Note per il nostro progetto
1. Inviare uno User-Agent con nome app e versione (richiesto dal servizio), senza dati personali.
2. Cache locale dei testi per brano.

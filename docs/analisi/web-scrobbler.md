# Web Scrobbler

- **Repository:** https://github.com/web-scrobbler/web-scrobbler
- **Licenza (dal file LICENSE.md):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** TypeScript, estensione browser (Chrome/Firefox/Safari)
- **Ultimo commit:** 2026-11-10
- **Versione minima di macOS:** n/a

## Come legge il brano in riproduzione
Connettori DOM per sito (`src/connectors/`, ~378 file: YouTube, Spotify, Apple Music web, Deezer, TIDAL…).

## Architettura
Analisi mirata a `src/core/`: `object/song.ts`, `object/pipeline/` (normalize, regex-edits, metadata,
coverartarchive, blocked-tags), `scrobbler/` (Last.fm, Libre.fm, ListenBrainz, Maloja, webhook).
Costanti in `src/util/util.ts`: `DEFAULT_SCROBBLE_TIME = 30`, `MIN_TRACK_DURATION = 30`, `MAX_SCROBBLE_TIME = 240`.

## Interfaccia
Popup dell'estensione con modifica dei metadati e cronologia.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Regole di scrobble (30 s / 50% / 240 s) | quando scrobblare | 2 | Studio |
| Pipeline di normalizzazione (rimozione "(Official Video)", "- Topic", ecc.) | pulizia titoli YouTube | 2 | Copia regex (MIT) |
| Cover Art Archive | copertine mancanti | 1 | Studio |

## Cosa evitare
- La tabella del file 00 diceva "da verificare": è **MIT**.

## Note per il nostro progetto
1. YouTube nel browser arriva con titoli "sporchi": la pipeline normalize serve già per la fase 1 (visualizzazione).

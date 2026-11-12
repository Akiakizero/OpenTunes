# foo_scrobbler_mac

- **Repository:** https://github.com/zfoxer/foo_scrobbler_mac
- **Licenza (dal file LICENSE):** **MIT** (il file 00 indicava GPL-3: corretto) — si può copiare codice? **sì**
- **Linguaggio e framework:** C++ (+ ObjC++ per le preferenze), plugin foobar2000 per macOS
- **Ultimo commit:** 2026-10-19
- **Versione minima di macOS:** 11.5

## Come legge il brano in riproduzione
API ufficiale dei plugin foobar2000 (callback di riproduzione), niente MediaRemote.

## Architettura
`src/lastfm_rules.h` (regole di invio), `lastfm_queue.cpp` (cache offline), `lastfm_auth*.cpp`
(autenticazione), `lastfm_exclusion_filters.cpp`, `lastfm_state.cpp`.

## Interfaccia
Menu e preferenze del plugin.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `lastfm_rules.h` | regole precise di scrobble | 2 | Studio |
| `lastfm_queue.cpp` | coda offline con retry | 2 | Studio |

## Cosa evitare
- Nulla di specifico; è C++ legato all'SDK foobar.

## Note per il nostro progetto
1. Coda persistente degli scrobble offline: requisito della fase 2.

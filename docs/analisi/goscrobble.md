# goscrobble

- **Repository:** https://github.com/p-mng/goscrobble
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** Go, CLI/daemon
- **Ultimo commit:** 2026-08-19
- **Versione minima di macOS:** n/a

## Come legge il brano in riproduzione
Sorgenti intercambiabili (`source.go`): `source_dbus.go` (MPRIS su Linux), `source_mediacontrol.go`
(esegue `/opt/homebrew/bin/media-control` — il CLI basato sull'adapter ungive), `source_tidalhifi.go`,
`source_eddyapi.go`.

## Architettura
`loop.go` interroga la sorgente → `playback.go` (validità, regex replace, blacklist player) →
sink (`sink_lastfm.go`, `sink_csv.go`). Buona copertura di test (`*_test.go`).

## Interfaccia
Nessuna (notifiche di sistema `notify_darwin.go`).

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Interfaccia Source / Sink | separazione sorgente → destinazione | 2, 5 | Studio |
| `IsBlacklisted`, `RegexReplace` | filtri | 2 | Studio |
| Sink CSV | export locale degli ascolti | 5 | Studio |

## Cosa evitare
- Percorso fisso Homebrew del binario.

## Note per il nostro progetto
1. Modello Source/Sink coerente con il nostro `MediaSource`.

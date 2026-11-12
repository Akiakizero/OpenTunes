# GoPlaying

- **Repository:** https://github.com/justinmdickey/goplaying (trovato dall'articolo LinuxLinks)
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** Go (TUI Bubble Tea) + helper Swift per macOS
- **Ultimo commit:** 2026-11-02
- **Versione minima di macOS:** non indicata

## Come legge il brano in riproduzione
- Linux: `playerctl` (`media_linux.go`).
- macOS: `media_darwin.go` + `helpers/nowplaying/NowPlaying.swift` compilato come **dylib** e caricato in
  `/usr/bin/perl` con `DynaLoader::dl_install_xsub` — stessa tecnica dell'adapter ungive, reimplementata in Swift.
  Fallback `osascript` con timeout (`commandTimeout`).

## Architettura
Helper → JSON → modello TUI con copertina e colori estratti.

## Interfaccia
TUI nel terminale, copertina e colori.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `NowPlaying.swift` | helper MR in Swift caricabile da perl | 5 (alternativa all'adapter) | Studio |
| Timeout su ogni chiamata osascript | evita blocchi | 0 | Studio |

## Cosa evitare
- Polling dell'helper.

## Note per il nostro progetto
1. Conferma indipendente che il trucco perl regge su macOS recenti.
2. Ogni Apple Event deve avere un timeout.

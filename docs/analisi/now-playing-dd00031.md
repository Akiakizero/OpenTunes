# Now Playing (dd00031)

- **Repository:** https://github.com/dd00031/now-playing
- **Licenza (dal file LICENSE):** GPL-3.0 — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift + SwiftUI
- **Ultimo commit:** 2026-02-05
- **Versione minima di macOS:** non indicata

## Come legge il brano in riproduzione
`Now Playing/MediaController.swift` (801 righe), due modalità:
- "Music Player": AppleScript per Spotify e Music + componente foobar2000.
- "All Media": adapter ungive con **`get` in polling** via `Timer`, posizione calcolata da `elapsedTime` + `timestamp`.

## Architettura
Un `MediaController` monolitico → `ContentView`. Colori estratti dalla copertina (righe ~737).

## Interfaccia
Mini player con sfondo dai colori della copertina.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Estrazione colori dalla copertina | palette | 1 | Studio/copia (GPL-3) |
| `Resources/Acknowledgements.txt` | crediti dell'adapter | 0 | Studio |

## Cosa evitare
- `get` in polling: le copertine arrivano in ritardo (il README dell'adapter consiglia `stream`).
- Controller monolitico con UI e sorgenti mescolate.

## Note per il nostro progetto
1. Usare `stream`.
2. foobar2000: richiede un componente esterno; fuori dal perimetro della fase 0.

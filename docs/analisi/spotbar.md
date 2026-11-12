# Spotbar

- **Repository:** https://github.com/levarr/Spotbar
- **Licenza (dal file LICENSE):** MIT (testo MIT senza titolo, Copyright 2023 Fabio Colonna) — si può copiare codice? **sì**
- **Linguaggio e framework:** TypeScript + Electron (electron-vite)
- **Ultimo commit:** 2023-05-14
- **Versione minima di macOS:** n/a (multipiattaforma)

## Come legge il brano in riproduzione
Solo **Spotify Web API** (`src/main/spotify-api-mgr.ts`, token in `spotify-token-mgr.ts`), polling.

## Architettura
Processo main Electron → renderer via preload.

## Interfaccia
Tray con disco che gira (copertina), vista compatta, controlli Spotify Connect (dispositivi, volume).

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Idea "disco che gira" e vista compatta | stile della copertina | 1 | Studio |
| Spotify Connect (dispositivi) | controllo remoto | 5 | Studio |

## Cosa evitare
- Electron per una menu bar app; dipendenza dall'account Spotify per vedere qualcosa.

## Note per il nostro progetto
1. La Web API serve solo per extra (libreria, dispositivi), non per il Now Playing.

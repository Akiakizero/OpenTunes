# Sidra

- **Repository:** https://github.com/wimpysworld/sidra
- **Licenza (dal file LICENSE):** **Blue Oak Model License 1.0.0** — si può copiare codice? **no per la nostra regola** (permissiva e compatibile con GPL, ma non è nella lista MIT/BSD/Apache/GPL-3; serve decisione esplicita) → solo studio
- **Linguaggio e framework:** TypeScript + Electron, client desktop di Apple Music (web)
- **Ultimo commit:** 2026-11-12
- **Versione minima di macOS:** n/a

## Come legge il brano in riproduzione
Hook MusicKit JS dentro la web app di Apple Music (`assets/musicKitHook.js`), poi
integrazioni per piattaforma: MPRIS, Dock macOS, taskbar Windows, notifiche, Discord, Last.fm.

## Architettura
`src/integrations/*/index.ts` uno per integrazione; `lastfm/index.ts` con `SCROBBLE_CAP_MS = 240_000`,
coda e gestione dei codici `ignoredMessage` di Last.fm.

## Interfaccia
Finestra Electron + tray.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `integrations/lastfm/index.ts` | gestione `ignoredMessage`, batch fino a 50 | 2 | Studio |
| Struttura a integrazioni separate | modularità | 2, 5 | Studio |

## Cosa evitare
- Copiare codice senza decidere sulla Blue Oak.

## Note per il nostro progetto
1. Ottimo riferimento per gli errori della risposta `track.scrobble`.

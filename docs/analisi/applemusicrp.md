# AppleMusicRP

- **Repository:** https://github.com/wxllow/applemusicrp
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** Python (rumps su macOS, pystray su Windows)
- **Ultimo commit:** 2026-05-26
- **Versione minima di macOS:** 10.15

## Come legge il brano in riproduzione
`src/applemusicrp/rpc.py` esegue `scripts/getmusicinfo.applescript` (variante legacy per iTunes) in polling.

## Architettura
Polling → Discord Rich Presence (con copertina cercata online).

## Interfaccia
Menu bar via `rumps`.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Integrazione Discord Rich Presence | stato su Discord | 5 | Studio |

## Cosa evitare
- L'autore stesso dichiara codice "sloppy", non aggiornato da anni.

## Note per il nostro progetto
1. Discord RPC solo in fase 5; per Apple Music servono copertine da URL pubblico (Discord non accetta dati binari).

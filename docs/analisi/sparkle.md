# Sparkle

- **Repository:** https://github.com/sparkle-project/Sparkle
- **Licenza (dal file LICENSE):** MIT (con componenti di terzi elencati nello stesso file) — si può copiare codice? **sì** (si usa come dipendenza)
- **Linguaggio e framework:** Objective-C + Swift, XPC services
- **Ultimo commit:** 2026-11-11
- **Versione minima di macOS:** 12.0

## Come legge il brano in riproduzione
n/a (aggiornamenti automatici).

## Architettura
Analisi mirata: `Sparkle/` (SPUUpdater, SPUStandardUpdaterController), `generate_appcast`, `sign_update`,
`generate_keys` (firme EdDSA), servizi XPC Installer/Downloader per app sandboxed.

## Interfaccia
Finestre standard di aggiornamento.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `SPUStandardUpdaterController` | integrazione minima | 4 | Dipendenza SPM |
| `generate_appcast` / `sign_update` | pipeline di rilascio | 4 | Strumenti |

## Cosa evitare
- Chiavi EdDSA private nel repo: vanno nei secret della CI.

## Note per il nostro progetto
1. Integrare solo in fase 4 insieme a notarizzazione.

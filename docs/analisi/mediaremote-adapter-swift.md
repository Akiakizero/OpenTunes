# mediaremote-adapter (Swift package, ejbills)

- **Repository:** https://github.com/ejbills/mediaremote-adapter
- **Licenza (dal file LICENSE):** BSD 3-Clause — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift package + target C/ObjC (`CIMediaRemote`) + `run.pl`
- **Ultimo commit:** 2026-11-03
- **Versione minima di macOS:** `.macOS(.v10_15)` in `Package.swift`

## Come legge il brano in riproduzione
Fork divergente di ungive: il framework dinamico del package è a sua volta caricato da
`/usr/bin/perl` (`Sources/MediaRemoteAdapter/Resources/run.pl`). API diversa dall'originale:
un processo persistente `loop` riceve comandi da **stdin** (`play`, `next_track`, `like_track`,
`ban_track`, `add_to_wish_list`, `set_time` …) e scrive JSON su stdout.
File: `Sources/MediaRemoteAdapter/MediaController.swift`, `Sources/CIMediaRemote/MediaRemoteAdapter.m`.

## Architettura
`MediaController` (classe, callback `onTrackInfoReceived`) → `Process` + `Pipe` → buffer `Data`
spezzato su `\n` → `JSONDecoder` → `TrackInfo`. Riavvia il processo ogni 100 eventi
(`restartThreshold`), usa `NSLock` e `DispatchQueue`.

## Interfaccia
Nessuna.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Lettura su `Data` cercando `\n` | parsing robusto a righe | 0 — `LineBuffer` | Studio (idea) |
| Comandi like/ban/wishlist | azioni sul brano via MR | 1–2 (like) | Studio |
| Processo persistente con comandi da stdin | evita uno spawn di perl per comando | 5 (ottimizzazione) | Studio |

## Cosa evitare
- Nessun comando `test`: niente rilevazione affidabile del guasto → serve il fallback.
- Riavvio periodico ogni 100 eventi: sintomo di perdite non risolte.
- Callback + `DispatchQueue` + `NSLock`: incompatibile con la nostra concorrenza stretta Swift 6.
- Protocollo non compatibile con quello documentato da ungive.

## Note per il nostro progetto
1. Restiamo sull'upstream ungive (contratto documentato, comando `test`).
2. Teniamo d'occhio il fork per like/ban (fase 1–2).
3. Il parsing su `Data` (non `String`) evita di rompere caratteri UTF-8 spezzati tra due chunk.

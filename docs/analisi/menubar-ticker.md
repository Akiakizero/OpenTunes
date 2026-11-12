# Menu Bar Ticker

- **Repository:** https://github.com/serban/menubar-ticker (trovato da AlternativeTo, autore Serban Giuroiu)
- **Licenza (dal file LICENSE):** MIT (Copyright 2012 Serban Giuroiu) — si può copiare codice? **sì**
- **Linguaggio e framework:** Objective-C + AppKit + ScriptingBridge
- **Ultimo commit:** 2021-02-14
- **Versione minima di macOS:** non indicata (v2.0.0 aggiunge Apple Silicon)

## Come legge il brano in riproduzione
`MenubarTicker/AppDelegate.m`: `SBApplication` per `com.apple.music` e `com.spotify.client`
(header `Music.h`, `Spotify.h`), notifiche `com.apple.iTunes.playerInfo`, `com.apple.music.playerInfo`,
`com.spotify.client.PlaybackStateChanged` + un `NSTimer` di sicurezza.

## Architettura
109 righe: notifica/timer → lettura SB → titolo dello status item.

## Interfaccia
Solo testo "Artista — Titolo" nella menu bar.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| Commento sul nome della notifica | Music ha inviato a lungo `com.apple.iTunes.playerInfo` | 0 — osservare **entrambi** i nomi | Studio |

## Cosa evitare
- Il nome usato `com.apple.music.playerInfo` è in minuscolo: quello corretto è `com.apple.Music.playerInfo`.

## Note per il nostro progetto
1. Osservare `com.apple.Music.playerInfo` **e** `com.apple.iTunes.playerInfo`.
2. Un timer lento di sicurezza è utile come rete se le notifiche si perdono.

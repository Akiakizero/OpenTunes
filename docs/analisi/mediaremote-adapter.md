# mediaremote-adapter (ungive)

- **Repository:** https://github.com/ungive/mediaremote-adapter
- **Licenza (dal file LICENSE):** BSD 3-Clause — si può copiare codice? **sì** (mantenere copyright + avviso, in CREDITS.md)
- **Linguaggio e framework:** Objective-C (Foundation/AppKit) + script Perl, build CMake
- **Ultimo commit:** 2026-11-11 (`14eed93`)
- **Versione minima di macOS:** non dichiarata; badge README "testato su macOS 27.0 (26A5425a)", 2026-09-04

## Come legge il brano in riproduzione
Da macOS 15.4 `mediaremoted` risponde solo a client con bundle ID `com.apple.*`. L'adapter
carica un framework proprio (`MediaRemoteAdapter.framework`) dentro `/usr/bin/perl`
(che si presenta come `com.apple.perl5`) tramite `DynaLoader` e da lì chiama le API private
di `MediaRemote.framework`.
- `bin/mediaremote-adapter.pl` — loader Perl, CLI
- `src/adapter/stream.m` — `MRMediaRemoteRegisterForNowPlayingNotifications`, calcolo dei diff (`createDiff`, `isSameItemIdentity`)
- `src/adapter/now_playing.m` — conversione chiavi MR → JSON, `--micros`, `elapsedTimeNow`
- `src/adapter/test.m` + `src/test/*` — comando `test` con client che simula una riproduzione
- `src/private/MediaRemote.h/.m` — dichiarazioni delle funzioni private

## Architettura
Processo figlio → JSON una riga per evento su stdout → l'app fa il parsing.
`stream` emette `{"type":"data","diff":bool,"payload":{…}}`. Con `diff:false` il payload è lo
stato completo; con `diff:true` contiene solo le chiavi cambiate e una chiave che sparisce vale `null`.
Un diff è emesso solo se l'identità del brano non cambia (`isSameItemIdentity`), altrimenti
arriva un payload completo. `timestamp` è ISO-8601 al secondo → usare `--micros` per
`timestampEpochMicros`. Comandi: `send ID`, `seek µs`, `shuffle`, `repeat`, `speed`, `test`.

## Interfaccia
Nessuna (CLI). Esiste `ungive/media-control` come CLI via brew.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `bin/mediaremote-adapter.pl` | loader Perl | 0 — `Resources/MediaRemoteAdapter/` | Copia (BSD-3) |
| `src/**`, `include/**` | sorgenti del framework e del test client | 0 — compilati da `scripts/build-mediaremote-adapter.sh` in `Vendor/` | Copia (BSD-3) |
| Formato JSON + regole diff (README) | contratto | 0 — `AdapterPayload`, `AdapterStreamDecoder` | Studio |
| Tabella ID `send` (0…13) | comandi | 0 — `MediaCommand` | Studio |

## Cosa evitare
- Non linkare il framework all'app: va solo **incluso nel bundle** e passato come argomento.
- Non rilanciare lo script dopo exit code ≠ 0 (indicazione esplicita del README).
- Le righe su stderr sono errori non fatali.
- `test` può creare per un istante una voce Now Playing fittizia: lanciarlo una sola volta all'avvio.
- Percorsi relativi: passare sempre percorsi assoluti.

## Note per il nostro progetto
1. Compiliamo framework + `MediaRemoteAdapterTestClient` da sorgente fissato a un commit (no binari di terzi).
2. Usare `stream --micros` (precisione µs del timestamp) e gestire i diff noi stessi.
3. `test` all'avvio decide tra adapter e AppleScript (gate della fase 0).
4. `--experimental-peculiar-debounce:com.tidal.desktop=1000` quando la sorgente è TIDAL.
   Nota: l'opzione è per-bundle, quindi può essere passata **sempre** all'avvio dello stream.
5. Payload grandi (artwork base64 di centinaia di KB): il parser deve lavorare su `Data`, non su `String` a pezzi.

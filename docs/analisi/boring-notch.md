# Boring Notch

- **Repository:** https://github.com/TheBoredTeam/boring.notch
- **Licenza (dal file LICENSE):** GPL-3.0 — si può copiare codice? **sì** (compatibile con GPL-3.0-or-later; vedi anche `THIRD_PARTY_LICENSES`)
- **Linguaggio e framework:** Swift + SwiftUI + AppKit, helper XPC
- **Ultimo commit:** 2026-10-31
- **Versione minima di macOS:** 14.0 (`MACOSX_DEPLOYMENT_TARGET`)

## Come legge il brano in riproduzione
Analisi mirata a `boringNotch/MediaControllers/`, `managers/MusicManager.swift`, `helpers/`.
- `NowPlayingController.swift` — avvia `/usr/bin/perl mediaremote-adapter.pl <framework> stream`
  e decodifica le righe JSON (`JSONLinesPipeHandler`). Comandi inviati **in-process** con
  `MRMediaRemoteSendCommand` via `CFBundleGetFunctionPointerForName`.
- `helpers/MediaChecker.swift` — lancia il comando `test` con timeout di 10 s; exit 1 ⇒ "deprecato".
- `AppleMusicController.swift` / `SpotifyController.swift` — AppleScript (`AppleScriptHelper`)
  attivato dalle notifiche distribuite `com.apple.Music.playerInfo` e `com.spotify.client.PlaybackStateChanged`.
- `YouTube Music Controller/` — API HTTP dell'app th-ch YouTube Music.
- Bundle: `mediaremote-adapter/` contiene .pl, framework e test client **binari**.

## Architettura
`MediaControllerProtocol` (Combine `playbackStatePublisher`) → `MusicManager` (singleton,
sceglie il controller dalle preferenze; se `test` fallisce usa Apple Music) → viste SwiftUI.

## Interfaccia
Finestra notch (`components/Notch/BoringNotchWindow.swift`, `BoringNotchSkyLightWindow.swift`
con API private SkyLight/CGS per stare sopra la menu bar e su tutti gli Space), visualizzatore,
shelf, calendario, HUD. Dipendenze SPM: Defaults, KeyboardShortcuts, LaunchAtLogin-Modern, Sparkle.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `MediaChecker.checkDeprecationStatus` | `test` con timeout | 0 — `MediaRemoteSource.isAvailable()` | Studio (riscritto in Swift 6) |
| Notifiche distribuite Music/Spotify | evento → rilettura via AppleScript | 0 — `AppleScriptSource` | Studio |
| Script AppleScript che restituisce una lista | una sola chiamata Apple Event per tutti i campi | 0 | Studio |
| `BoringNotchWindow` / SkyLight | finestra nel notch | 3 | Studio/copia (GPL-3) |
| Controller YouTube Music | API locale di th-ch | 4–5 | Studio |

## Cosa evitare
- Bug in `handleAdapterUpdate`: con `diff:true` una chiave a `null` (sparita) mantiene il
  vecchio valore invece di essere rimossa.
- `JSONLinesPipeHandler` converte ogni chunk in `String`: un carattere UTF-8 spezzato tra due
  chunk fa scartare l'intero chunk (`String(data:)` restituisce nil).
- `timestamp` letto come ISO-8601 al secondo → posizione imprecisa (meglio `--micros`).
- `setFavorite` in `AppleMusicController`: concatenazione `" + (favorite ? …) + "` dentro una
  stringa multilinea Swift → lo script contiene testo letterale e non funziona.
- `MRMediaRemoteSendCommand` chiamato in-process: dipende dal comportamento di MR da 15.4 in poi;
  più sicuro usare `send` dell'adapter.
- `NSAppleScript` eseguito su `Task.detached` concorrenti: non è thread-safe.

## Note per il nostro progetto
1. Copiare il **flusso** (test → stream → fallback AppleScript), non il codice del parsing.
2. Applicare i diff correttamente (null = rimuovi) con test dedicati.
3. Serializzare tutte le chiamate AppleScript su un unico attore/esecutore.
4. Per la fase 3 studiare la finestra SkyLight e la forma `NotchShape.swift`.

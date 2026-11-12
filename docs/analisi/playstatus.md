# PlayStatus

- **Repository:** https://github.com/nbolar/playstatus
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift + SwiftUI/AppKit, Sparkle
- **Ultimo commit:** 2026-10-01
- **Versione minima di macOS:** non verificata nel pbxproj (progetto moderno)

## Come legge il brano in riproduzione
Solo AppleScript (Music e Spotify) ma molto ottimizzato:
- `Providers/NowPlayingProviders.swift` — `MusicProvider` / `SpotifyProvider`; separa campi
  "caldi" (dal payload della notifica) e "freddi" (`ColdFields`: album artist, disco, shuffle,
  repeat… riletti al massimo ogni 15 s). Rileva le **letture strappate**: lo script legge il
  persistent ID all'inizio e alla fine e ripete se differiscono.
- `System/PlayerEventObserver.swift` — notifiche `com.apple.Music.playerInfo`,
  `com.apple.iTunes.playerInfo`, `com.spotify.client.PlaybackStateChanged`; scarta i duplicati.
  Il payload della notifica contiene 8 dei 16 campi → evita Apple Events nel caso comune.
- `System/ProviderConnectionInspector.swift` — `AEDeterminePermissionToAutomateTarget` per
  sapere **senza chiedere** se il permesso Automazione c'è (`errAEEventNotPermitted`,
  `errAEEventWouldRequireUserConsent`).

## Architettura
Osservatore eventi → provider (AppleScript) → `NowPlayingModel` → `StatusBarController`.
Cache artwork (`ArtworkCache`), ricerca copertine su iTunes (`ITunesArtworkLookup`),
scrobbling, testi, cronologia.

## Interfaccia
Status item composito, popover, onboarding, "What's new".

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `automationPermission(for:askUserIfNeeded:)` | stato del permesso Automazione | 0 — `AutomationPermission` | Copia (MIT) |
| Uso del payload `userInfo` delle notifiche | meno Apple Events | 0 | Studio |
| Guardia persistent ID inizio/fine | letture coerenti | 0–1 | Studio |
| `ITunesArtworkLookup` | copertine mancanti (Spotify/browser) | 1 | Studio |

## Cosa evitare
- `AEDeterminePermissionToAutomateTarget` è **bloccante**: mai sul main thread.
- Molta logica statica con `NSLock`: da noi attori.

## Note per il nostro progetto
1. Prima di qualsiasi script verificare che l'app sia in esecuzione (altrimenti `tell` la avvia).
2. Chiedere il permesso Automazione solo su azione dell'utente, con testo chiaro.
3. Notifica = segnale; il payload serve per aggiornare subito titolo/artista/stato.

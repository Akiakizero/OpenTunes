# OpenTunes — istruzioni per Claude Code

## Progetto
App macOS (Swift 6, SwiftUI) che mostra il brano in riproduzione in menu bar,
finestra flottante, widget e notch. Licenza GPL-3.0-or-later. Target: macOS 26+.
Piano per fasi in `docs/` (fase 0 = fondamenta); analisi dei progetti di riferimento in `docs/analisi/`
(partire da `docs/analisi/SINTESI.md`).

## Architettura
- `Sources/MediaCore` è un framework separato e **non importa SwiftUI**. Le superfici leggono solo `NowPlayingStore`.
- Ogni sorgente implementa `MediaSource`. Mai accedere a un player fuori da una sorgente.
- Contratto delle sorgenti: `updates()` emette snapshot completi e **termina** quando la sorgente smette di
  funzionare; `NowPlayingStore` allora passa alla successiva (ordine: `MediaRemoteSource`, `AppleScriptSource`).
- `MediaRemoteSource`: `/usr/bin/perl mediaremote-adapter.pl <framework> <test client> stream --micros …`.
  Dopo exit ≠ 0 non si rilancia l'adapter. `test` si esegue una sola volta per avvio.
- `AppleScriptSource`: solo Musica e Spotify; gli script controllano `is running` (non avviano mai il player);
  gli AppleScript passano tutti da `AppleScriptRunner` (attore: `NSAppleScript` non è thread-safe).
- Il permesso Automazione si chiede solo su azione dell'utente (`AutomationPermission.request`).
- Concorrenza stretta di Swift 6 attiva. Niente DispatchQueue nuove: usare async/await, attori, `Mutex`.
- Niente App Sandbox: l'adapter richiede di avviare `/usr/bin/perl`.
- App (fase 1): entry point AppKit (`OpenTunesApp` + `AppDelegate`, `LSUIElement`). `AppModel` è lo stato condiviso
  delle superfici (store, `AppSettings`, copertina, tinta, volume); le superfici AppKit reagiscono con
  `observeChanges` (basato su `Observations`). Menu bar in `App/MenuBar`, finestra flottante in `App/FloatingPanel`,
  HUD in `App/HUD`. Volume = volume di sistema (CoreAudio), non del player.
- Blacklist, normalizzazione dei titoli dei browser, cronologia e lookup copertine stanno in `NowPlayingStore`.

## Build
- Requisiti: Xcode 26+, `brew install xcodegen`. Se `xcode-select` punta ai Command Line Tools:
  `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Generare il progetto: `xcodegen generate` (il `.xcodeproj` non è versionato)
- Build e test: `xcodebuild -scheme OpenTunes -destination 'platform=macOS' test`
- L'adapter si compila da solo (pre-build) con `scripts/build-mediaremote-adapter.sh` da `Vendor/mediaremote-adapter/`
  in `Resources/MediaRemoteAdapter/` (ignorato da git) e viene copiato nel bundle.
- Prova manuale dell'adapter (fuori da sandbox):
  `cd Resources/MediaRemoteAdapter && /usr/bin/perl mediaremote-adapter.pl "$PWD/MediaRemoteAdapter.framework" "$PWD/MediaRemoteAdapterTestClient" test; echo $?`

## Debug
- `OPENTUNES_LOG_FILE=/percorso` (es. con `open --env`) scrive gli eventi di `NowPlayingStore` in un file,
  comprese le decisioni della modalità compatta (`[menubar]`, con frame dell'elemento e del notch).
- `OPENTUNES_DEBUG_SHOW=popover|hud|volume|settings` apre quella superficie 3 s dopo l'avvio (screenshot, GIF).
- `scripts/record-gif.sh <nome> <x,y,l,a> [secondi]` crea `docs/media/<nome>.gif` (sequenza di screenshot + ffmpeg).
  Le GIF mostrano il brano e lo sfondo reali: registrarle con contenuti scelti apposta.
- Le anteprime SwiftUI avviano l'app: `AppDelegate` non parte con `XCODE_RUNNING_FOR_PREVIEWS=1` e
  `AppModel.preview()` usa `AppSettings(persists: false)`, così le anteprime non toccano le preferenze reali.
- Su macOS 27 gli elementi della menu bar sono disegnati da `MenuBarAgent`: non compaiono in `CGWindowList` dell'app.

## Test
- Swift Testing (`import Testing`) in `Tests/MediaCoreTests` e `Tests/OpenTunesTests` (logica dell'app, host = app,
  che sotto test non avvia le superfici); fixture JSONL in `Tests/Fixtures/` (vedi il README lì).
- Anteprime SwiftUI: `AppModel.preview()` usa `NowPlayingStore.inject` (sincrono) e `PreviewData` (copertine disegnate).

## Release
- `scripts/make-dmg.sh` → `dist/OpenTunes-<versione>.dmg`; il workflow `.github/workflows/release.yml` parte con un tag `v*`.
- Cask Homebrew da copiare nel tap: `packaging/homebrew/opentunes.rb`.

## Licenze
- Ogni file inizia con `// SPDX-License-Identifier: GPL-3.0-or-later`
- Codice preso da altri progetti: solo MIT, BSD, Apache-2.0 o GPL-3. Aggiornare CREDITS.md nella stessa PR.
- Le licenze verificate dei progetti di riferimento sono in `docs/analisi/SINTESI.md` (es. Tuneful, cbNP,
  SoundSeer: nessuna licenza → niente copia; MusicBar EUPL e Sidra Blue Oak: fuori lista).
- `reference/` contiene sorgenti di terzi solo per studio: mai committarli, mai eseguirne il codice.
- Mai copiare asset, icone o testi di NepTunes.

## Design (dalla fase 1)
- Solo materiali di sistema (.glassEffect, NSGlassEffectView). Niente blur fatti a mano.
- Valori di spaziatura, raggi e tipografia solo da DesignSystem.

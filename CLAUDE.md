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
- Fase 2: azioni sul brano di Musica (preferito, dislike, stelle, libreria) e «cambia player» passano da
  `NowPlayingStore` (`perform`, `trackState`, `switchPlayer`), implementate in `AppleScriptSource` via `AppleScriptRunner`.
- Scrobbling in `Sources/MediaCore/Scrobbling`: `ScrobbleEngine` è puro (snapshot + tick → eventi, testabile senza
  rete); `Scrobbler` lo collega a `ScrobbleQueue` (SwiftData, `Sources/MediaCore/Storage`) e ai client.
  Ogni ascolto si salva in coda **prima** dell'invio. Le chiamate HTTP passano da `HTTPTransport` (finto nei test).
- Segreti (session key Last.fm, token ListenBrainz, secret personale) solo via `SecretStore`: `KeychainStore`
  nell'app, `MemorySecretStore` in test e anteprime. Mai in `UserDefaults`.
- `AppModel()` senza argomenti = database in memoria e niente Portachiavi (anteprime, test); l'app usa `AppModel.live()`.
- Fase 3: widget WidgetKit nel target `OpenTunesWidget` (`Sources/Widget`, in sandbox, **senza MediaCore**). L'app scrive
  lo stato nell'App Group (`$(TeamIdentifierPrefix)org.opentunes.shared`) con `WidgetBridge`; il codice comune ai due
  target sta in `Sources/Shared` (`WidgetState`, App Intents). I pulsanti sono `AudioPlaybackIntent`: girano nel processo
  dell'app e arrivano ad `AppModel` tramite `WidgetCommandBridge`. Ricaricare i widget solo se cambia qualcosa di visibile.
- Widget sulla scrivania in `App/DesktopWidget` (livello `desktopIconWindow + 2` come i widget di macOS: a +1 lo copre la finestra «underbelly» del Window Server; posizione per UUID del display),
  player nel notch in `App/Notch` (pannello sopra la menu bar che ignora i clic finché il mouse non è sulla forma,
  seguito con monitor globali di `mouseMoved`), copertina nel Dock in `App/Dock`.
- Fase 4: ogni superficie si spegne in modo permanente (`Surface`, `AppSettings.isEnabled/setEnabled`); con la menu bar
  spenta le impostazioni si aprono riaprendo l'app. Testi (`LyricsService`, LRCLIB, cache su disco) e link universale
  (`ShareLinkService`, iTunes → Odesli) stanno in MediaCore e passano da `HTTPTransport`; `AppModel+Extras.swift` li
  collega alle superfici insieme a uscita audio (`AudioOutput`), volume del player e risveglio dal sopore.
  Temi in `SurfaceTheme` (DesignSystem): usare `surfaceGlass(…, theme:)` e `NSGlassEffectView.apply(theme:tint:)`.
  Visualizer reale: `AudioSpectrum` (process tap di Core Audio + FFT, idea da cava) acceso da `AppModel.needsSpectrum`;
  senza permesso «Registrazione audio di sistema» le barre tornano all'animazione.
  Finestra «Scopri» (top album, simili) in `App/Discover`. Aggiornamenti con Sparkle (`App/System/Updater.swift`,
  attivo solo con `SPARKLE_PUBLIC_KEY`, vedi `docs/aggiornamenti.md`).
- Fase 5: integrazioni in `App/Automation`: `URLCommand` (`opentunes://…`, eseguito da `AppModel.run` o da
  `AppDelegate` per le finestre), CLI = script `Sources/App/Resources/opentunes-cli.sh` che usa gli URL e legge
  `now-playing.json` scritto da `CommandLineBridge`; App Intents in `OpenTunesIntents.swift` (passano da
  `AppIntentBridge.model`, `perform` sul main actor); Discord con `DiscordIPC`/`DiscordPresence` (MediaCore, socket Unix)
  e `DiscordController`. Statistiche: `ListeningStats` (puro, MediaCore) dalla cronologia (`TrackHistory.plays(since:)`,
  fino a 10.000 voci, miniature solo sulle ultime 500). MIDI in `App/System/MIDIControl.swift` (CoreMIDI, UMP).
  Temi JSON: `CustomTheme` (DesignSystem, anche nel widget) con `SurfaceTheme.custom`.
- Ogni funzione ha un interruttore in `AppSettings` (scheda Funzioni); le viste e `AppModel` controllano il flag
  (`canShare`, `showsMusicActions`, `switchTarget`, `discoverAction`…), non solo la vista.
- Menu bar: `MenuBarFit` (in `NotchLayout.swift`, puro e testato) sceglie piena/compatta/icona; con il notch calcola
  lo spazio, senza notch scende quando il sistema nasconde l'elemento e ricorda la larghezza fallita.
- Spettro: `SpectrumAnalyzer` è un porting dell'algoritmo di `cavacore.c` (MIT, testo in CREDITS); il tap si legge
  dall'**ultimo** buffer dell'IOProc (prima vengono gli ingressi del dispositivo, es. il microfono delle AirPods).
- Localizzazione: catalogo unico `Sources/Shared/Localizable.xcstrings` (base italiano, inglese). Testi nelle viste
  come letterali (`LocalizedStringKey`); etichette `String` con `String(localized:)`. Dopo aver aggiunto testi:
  compilare e sincronizzare con `xcrun xcstringstool sync Sources/Shared/Localizable.xcstrings --stringsdata …`
  (i `.stringsdata` sono nelle Intermediates della build), poi tradurre le chiavi nuove.

## Build
- Requisiti: Xcode 26+, `brew install xcodegen`. Se `xcode-select` punta ai Command Line Tools:
  `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Generare il progetto: `xcodegen generate` (il `.xcodeproj` e `Sources/App/Info.plist` non sono versionati)
- API key Last.fm del progetto: variabili `LASTFM_API_KEY`/`LASTFM_API_SECRET` alla build (→ Info.plist
  `LastFMAPIKey`/`LastFMAPISecret`); senza, l'utente usa la propria chiave dalle impostazioni.
- Build e test: `xcodebuild -scheme OpenTunes -destination 'platform=macOS' test`
- L'adapter si compila da solo (pre-build) con `scripts/build-mediaremote-adapter.sh` da `Vendor/mediaremote-adapter/`
  in `Resources/MediaRemoteAdapter/` (ignorato da git) e viene copiato nel bundle.
- Prova manuale dell'adapter (fuori da sandbox):
  `cd Resources/MediaRemoteAdapter && /usr/bin/perl mediaremote-adapter.pl "$PWD/MediaRemoteAdapter.framework" "$PWD/MediaRemoteAdapterTestClient" test; echo $?`

## Debug
- `OPENTUNES_LOG_FILE=/percorso` (es. con `open --env`) scrive gli eventi di `NowPlayingStore` in un file,
  comprese le decisioni della modalità compatta (`[menubar]`, con frame dell'elemento e del notch).
- `OPENTUNES_DEBUG_SHOW=popover|hud|volume|settings|desktop|notch|discover|stats` apre quella superficie 3 s dopo l'avvio (screenshot, GIF).
- `scripts/record-gif.sh <nome> <x,y,l,a> [secondi]` crea `docs/media/<nome>.gif` (sequenza di screenshot + ffmpeg).
  Le GIF mostrano il brano e lo sfondo reali: registrarle con contenuti scelti apposta.
- Le anteprime SwiftUI avviano l'app: `AppDelegate` non parte con `XCODE_RUNNING_FOR_PREVIEWS=1` e
  `AppModel.preview()` usa `AppSettings(persists: false)`, così le anteprime non toccano le preferenze reali.
- Su macOS 27 gli elementi della menu bar sono disegnati da `MenuBarAgent`: non compaiono in `CGWindowList` dell'app.

## Widget
- Le anteprime di Xcode non supportano i widget su macOS. Per controllarli: `NowPlayingWidgetView(entry:family:)`
  con `ImageRenderer` (le viste a tempo come `ProgressView(timerInterval:)` lì non si disegnano).
- Con la firma ad-hoc l'App Group senza Team ID non è autorizzato: `SharedContainer` usa allora
  `~/Library/Application Support/OpenTunes/Widget/`, letta dal widget con l'eccezione sandbox `home-relative-path.read-only`
  (in `project.yml`). Con `DEVELOPMENT_TEAM=…` si usa l'App Group `<TEAM>.org.opentunes.shared`.
- Ogni nuova build ad-hoc fa ricomparire la richiesta del Portachiavi all'avvio (cambia la firma): l'app resta ferma
  in `KeychainStore.secret(for:)` finché l'utente non risponde.

## Test
- Swift Testing (`import Testing`) in `Tests/MediaCoreTests` e `Tests/OpenTunesTests` (logica dell'app, host = app,
  che sotto test non avvia le superfici); fixture JSONL in `Tests/Fixtures/` (vedi il README lì).
- Anteprime SwiftUI: `AppModel.preview()` usa `NowPlayingStore.inject` (sincrono) e `PreviewData` (copertine disegnate).

## Release
- `scripts/make-dmg.sh` → `dist/OpenTunes-<versione>.dmg`; il workflow `.github/workflows/release.yml` parte con un tag `v*`
  e, con le chiavi di Sparkle configurate, allega anche `appcast.xml` (`scripts/make-appcast.sh`).
- Il primo `xcodebuild -resolvePackageDependencies` deve poter scaricare l'archivio binario di Sparkle da GitHub.
- Sito: `site/index.html` (+ GIF di `docs/media`), pubblicato da `.github/workflows/pages.yml`.
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

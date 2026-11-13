<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Contribuire a OpenTunes

Grazie dell'interesse! Issue e pull request si possono scrivere in italiano o in inglese.

## Da dove partire

- Le issue con l'etichetta **good first issue** sono piccole e ben delimitate.
- Il piano del progetto è diviso in fasi in `docs/` (`fase-0-…` → `fase-5-…`): le caselle non spuntate sono il lavoro aperto.
- `docs/analisi/SINTESI.md` riassume i progetti open source studiati e le loro licenze.

## Preparare l'ambiente

```sh
brew install xcodegen
xcodegen generate          # il .xcodeproj non è nel repository
xcodebuild -scheme OpenTunes -destination 'platform=macOS' test
```

Serve Xcode 26 o successivo. Se `xcode-select` punta ai Command Line Tools:
`export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Per i widget di macOS conviene compilare con il proprio Team ID (`DEVELOPMENT_TEAM=…`): con la firma ad-hoc
macOS può non riconoscere l'App Group condiviso tra app e widget.

## Come è fatto il codice

- `Sources/MediaCore`: framework senza SwiftUI. Sorgenti del Now Playing (`MediaRemoteSource`, `AppleScriptSource`),
  `NowPlayingStore`, scrobbling, archivio SwiftData. È la parte più facile da testare.
- `Sources/App`: le superfici (menu bar, popover, finestra flottante, notch, widget sulla scrivania, HUD, Dock),
  tutte leggono `AppModel`.
- `Sources/Widget`: estensione WidgetKit. Non include MediaCore: legge lo stato che l'app scrive nell'App Group.
- `Sources/Shared`: codice compilato sia nell'app sia nel widget (stato condiviso, App Intents).
- `Sources/DesignSystem`: spaziature, raggi, tipografia e componenti comuni.

`CLAUDE.md` contiene le regole complete. Le più importanti:

- Swift 6 con concorrenza stretta: async/await, attori, `Mutex`; niente `DispatchQueue` nuove e niente Combine.
- Solo materiali di sistema (`.glassEffect`, `NSGlassEffectView`); niente blur disegnati a mano.
- Spaziature, raggi e tipografia solo da `DesignSystem`.
- Segreti (session key, token) solo nel Portachiavi tramite `SecretStore`, mai in `UserDefaults`.
- Test con Swift Testing (`import Testing`); le chiamate di rete passano da `HTTPTransport` (finto nei test).

## Licenze

- OpenTunes è GPL-3.0-or-later; ogni file inizia con `// SPDX-License-Identifier: GPL-3.0-or-later`.
- Si può riusare codice solo da progetti MIT, BSD, Apache-2.0 o GPL-3, indicandolo in `CREDITS.md` nella stessa PR.
- Mai copiare asset, icone, testi o screenshot di NepTunes o di altre app proprietarie.

## Pull request

1. Una PR per argomento, con la descrizione di cosa cambia e di come l'hai provato.
2. I test devono passare (`xcodebuild … test`, lo controlla anche la CI).
3. Per i cambi visivi allega uno screenshot o una GIF (`scripts/record-gif.sh`), con contenuti scelti apposta.

## Segnalare un problema

Usa il modulo «Segnala un problema». La finestra Impostazioni › Altro › «Apri la diagnostica…» mostra la sorgente
attiva e gli ultimi eventi: incolla le righe utili (togliendo quello che non vuoi condividere).

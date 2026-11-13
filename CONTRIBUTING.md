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

I widget di macOS funzionano anche con la firma ad-hoc (lo stato passa da `~/Library/Application Support/OpenTunes/Widget/`);
con il proprio Team ID (`DEVELOPMENT_TEAM=…`) si usa l'App Group condiviso.

## Come è fatto il codice

- `Sources/MediaCore`: framework senza SwiftUI. Sorgenti del Now Playing (`MediaRemoteSource`, `AppleScriptSource`),
  `NowPlayingStore`, scrobbling, archivio SwiftData. È la parte più facile da testare.
- `Sources/App`: le superfici (menu bar, popover, finestra flottante, notch, widget sulla scrivania, HUD, Dock),
  tutte leggono `AppModel`.
- `Sources/Widget`: estensione WidgetKit. Non include MediaCore: legge lo stato che l'app scrive (`SharedContainer`).
- `Sources/App/Automation`: comandi `opentunes://`, riga di comando, App Intents (Comandi Rapidi, Siri), Discord.
- `Sources/Shared`: codice compilato sia nell'app sia nel widget (stato condiviso, App Intents).
- `Sources/DesignSystem`: spaziature, raggi, tipografia e componenti comuni.

`CLAUDE.md` contiene le regole complete. Le più importanti:

- Swift 6 con concorrenza stretta: async/await, attori, `Mutex`; niente `DispatchQueue` nuove e niente Combine.
- Solo materiali di sistema (`.glassEffect`, `NSGlassEffectView`); niente blur disegnati a mano.
- Spaziature, raggi e tipografia solo da `DesignSystem`.
- Segreti (session key, token) solo nel Portachiavi tramite `SecretStore`, mai in `UserDefaults`.
- Test con Swift Testing (`import Testing`); le chiamate di rete passano da `HTTPTransport` (finto nei test).

## Temi

Un tema è un file JSON in [`themes/`](themes/) (vedi il README lì). Per proporne uno: esportalo da Impostazioni ›
Integrazioni › Temi, aggiungilo alla cartella con un nome in minuscolo (`mio-tema.json`) e apri una PR con uno
screenshot della finestra flottante e del popover.

## Traduzioni

I testi stanno nel catalogo `Sources/Shared/Localizable.xcstrings` (italiano di base, inglese). Si può tradurre da
Xcode (aprendo il catalogo) o da Weblate quando il progetto sarà collegato. Dopo aver aggiunto testi nel codice:
compila e sincronizza con `xcrun xcstringstool sync … --stringsdata …` (vedi `CLAUDE.md`).

## Contribuire con Claude Code

Il repository è pensato anche per chi lavora con [Claude Code](https://claude.com/claude-code):

1. `CLAUDE.md` è il contratto: architettura, regole di concorrenza, licenze, design. Claude Code lo legge da solo;
   tienilo aggiornato nella stessa PR se cambi l'architettura.
2. Parti da una issue precisa e chiedi un piano prima del codice (es. *«Leggi CLAUDE.md e docs/fase-5-dopo-la-v1.md,
   poi proponi come aggiungere X»*). I prompt suggeriti per ogni fase sono in fondo ai file `docs/fase-*`.
3. Chiedi sempre i test con Swift Testing e lancia `xcodebuild … test` prima della PR.
4. Rileggi il diff: niente codice da progetti con licenza non compatibile (`docs/analisi/SINTESI.md`), niente
   sorgenti di `reference/` nel commit, niente segreti.
5. Nella descrizione della PR indica che è stata scritta con Claude Code e come l'hai provata.

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

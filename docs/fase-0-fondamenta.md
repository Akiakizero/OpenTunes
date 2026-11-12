# Fase 0 — Fondamenta

> **Obiettivo:** leggere in modo affidabile il brano in riproduzione su macOS 27 Golden Gate, da qualsiasi player, e avere il repo pronto per lavorare con Claude Code.
> Se questa fase non funziona bene, nient'altro funziona.

## Gate per chiudere la fase

- [x] L'app legge titolo, artista, album, copertina, durata e posizione da **Apple Music** e **YouTube in Safari** su macOS 27 — **Spotify e Chrome non verificati** (non installati sulla macchina di sviluppo)
- [x] Play/pausa, successivo e precedente funzionano da codice su Musica (adapter e AppleScript) e su YouTube in Safari (play/pausa e seek; successivo/precedente accettati ma ignorati da YouTube su un video singolo) — Spotify non verificato
- [x] Se mediaremote-adapter non risponde, l'app passa da sola alla sorgente AppleScript
- [x] La build e i test passano da terminale con `xcodebuild`

### Verifica dal vivo (2026-11-12, macOS 27.2.1, Xcode 27.2)

| Verifica | Risultato |
| --- | --- |
| `test` dell'adapter | exit 0 (il primo avvio a freddo ha dato exit 4 → l'app ora ritenta fino a 3 volte) |
| Musica via adapter: titolo, artista, album, durata, posizione, copertina (`stream`, JPEG) | ok |
| Musica via adapter: successivo, precedente, play/pausa (CLI e pulsanti dell'app) | ok |
| YouTube in Safari via adapter: titolo, canale, durata, posizione; `parentApplicationBundleIdentifier` = `com.apple.Safari` | ok |
| YouTube in Safari: play/pausa, seek | ok — successivo/precedente: exit 0 ma nessun effetto (YouTube li espone solo nelle playlist) |
| Fallback: `kill -9` dello stream → l'app passa da sola ad `applescript` senza rilanciare l'adapter | ok |
| Musica via AppleScript (dopo il permesso Automazione): brano e copertina; successivo, precedente, play/pausa | ok |
| Spotify, Chrome | **da verificare** (app non installate) |

Per ripetere: `open --env OPENTUNES_LOG_FILE=/tmp/opentunes.log build/DerivedData/Build/Products/Debug/OpenTunes.app`.

## Prima di tutto: studio dei progetti di riferimento

- [ ] Eseguire `scripts/fetch-references.sh` per scaricare il codice sorgente di tutti i progetti elencati in `00-progetti-di-riferimento.md`
- [ ] Trovare e scaricare i repository segnati "da trovare" (Menu Bar Ticker, SoundSeer, Mooziac, GoPlaying, LRCLIB)
- [ ] Analizzare ogni progetto e scrivere `docs/analisi/<progetto>.md` seguendo la procedura del file
- [ ] Scrivere `docs/analisi/SINTESI.md` e aggiornare i file delle fasi con quello che emerge
- [ ] Verificare le licenze leggendo i file LICENSE: le voci "da verificare" vanno risolte prima di copiare codice

## 1. Setup del repository

- [ ] Creare il repo GitHub pubblico (nome provvisorio: `OpenTunes`, da sostituire con il nome definitivo)
- [ ] `LICENSE` con il testo completo della **GPL-3.0**
- [ ] Intestazione SPDX in ogni file sorgente: `// SPDX-License-Identifier: GPL-3.0-or-later`
- [ ] `CREDITS.md` vuoto, da riempire ogni volta che entra codice di altri progetti
- [ ] `README.md` minimo: cosa è, stato "work in progress", nota "non affiliato a NepTunes né ad Apple"
- [ ] `.gitignore` per Xcode e Swift
- [ ] `project.yml` per **XcodeGen** (target app + target test; il widget arriva in fase 3)
- [ ] `CLAUDE.md` con architettura, convenzioni e regole sulle licenze (vedi sotto)
- [ ] GitHub Actions: build + test a ogni PR su runner macOS

## 2. Struttura del progetto

```
OpenTunes/
├── project.yml
├── CLAUDE.md
├── Sources/
│   ├── App/                 # entry point, AppDelegate, ciclo di vita
│   ├── MediaCore/           # stato, sorgenti, modelli (nessuna UI qui)
│   │   ├── Models/          # Track, PlaybackState, PlayerApp
│   │   ├── Sources/         # MediaSource + implementazioni
│   │   └── NowPlayingStore.swift
│   └── DesignSystem/        # vuoto per ora, si riempie in fase 1
├── Resources/
│   └── MediaRemoteAdapter/  # framework + script .pl (NON linkati)
└── Tests/
    └── MediaCoreTests/
```

## 3. Modelli dati

- [ ] `Track`: titolo, artista, album, album artist, durata, artwork (`NSImage?` + hash), bundle ID del player
- [ ] `PlaybackState`: `isPlaying`, posizione, timestamp dell'ultima lettura (per calcolare la posizione senza polling), shuffle, repeat
- [ ] `PlayerApp`: bundle ID, nome, icona, capacità supportate (like, stelle, aggiungi alla libreria)

## 4. Sorgenti

Protocollo comune:

```swift
protocol MediaSource: Sendable {
    var id: String { get }
    func isAvailable() async -> Bool
    func updates() -> AsyncStream<NowPlayingSnapshot>
    func send(_ command: MediaCommand) async throws
}
```

- [ ] **`MediaRemoteSource`** — avvia `/usr/bin/perl mediaremote-adapter.pl <framework> stream` con `Process`, legge stdout riga per riga come JSON, applica i `diff` all'ultimo payload completo
- [ ] Usare il comando `test` dell'adapter all'avvio per sapere se funziona
- [ ] Gestire stderr come errori non fatali; non riavviare dopo exit code ≠ 0, passare al fallback
- [ ] Opzione `--experimental-peculiar-debounce` quando il player è TIDAL (`com.tidal.desktop`)
- [ ] **`AppleScriptSource`** — per `com.apple.Music` e `com.spotify.client`: lettura stato + comandi
- [ ] Richiesta dei permessi Automazione (Apple Events) con messaggio chiaro all'utente
- [ ] **`NowPlayingStore`** (`@Observable`, `@MainActor`) — riceve gli snapshot, sceglie la sorgente attiva, espone un unico stato

## 5. Prototipo visibile

- [ ] Una finestra di debug (anche brutta) che mostra lo stato del `NowPlayingStore` in tempo reale: copertina, testi, sorgente attiva, log degli eventi
- [ ] Tre pulsanti: precedente, play/pausa, successivo

## 6. Test

- [ ] Test del parsing JSON dell'adapter con payload di esempio salvati in `Tests/Fixtures/`
- [ ] Test dell'applicazione dei `diff`
- [ ] Test del calcolo della posizione corrente da posizione + timestamp
- [ ] Test del passaggio al fallback quando una sorgente smette di rispondere

## Riferimenti open-source

| Progetto | Cosa guardare |
| --- | --- |
| [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) | README: integrazione, comandi `stream`/`get`/`test`/`send`, formato JSON (BSD-3) |
| [ejbills/mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter) | Versione Swift package (API divergente, senza `test`): non adottata, vedi `docs/analisi/mediaremote-adapter-swift.md` |
| [Boring Notch](https://github.com/TheBoredTeam/boring.notch) | Come gestisce i media controller e il fallback (GPL-3) |
| [MusicMenu](https://github.com/niklhut/MusicMenu) | Esempio di progetto generato con XcodeGen |
| [osx-scrobbler](https://github.com/theli-ua/osx-scrobbler) | Elenco dei bundle ID dei player e come li riconosce |

## Bozza di `CLAUDE.md`

```markdown
# OpenTunes — istruzioni per Claude Code

## Progetto
App macOS (Swift 6, SwiftUI) che mostra il brano in riproduzione in menu bar,
finestra flottante, widget e notch. Licenza GPL-3.0-or-later. Target: macOS 26+.

## Architettura
- MediaCore non importa SwiftUI. Le superfici leggono solo NowPlayingStore.
- Ogni sorgente implementa MediaSource. Mai accedere a un player fuori da una sorgente.
- Concorrenza stretta di Swift 6 attiva. Niente DispatchQueue nuove: usare async/await.

## Build
- Generare il progetto: `xcodegen generate`
- Build e test: `xcodebuild -scheme OpenTunes -destination 'platform=macOS' test`

## Licenze
- Ogni file inizia con `// SPDX-License-Identifier: GPL-3.0-or-later`
- Codice preso da altri progetti: solo MIT, BSD, Apache-2.0 o GPL-3. Aggiornare CREDITS.md nella stessa PR.
- Mai copiare asset, icone o testi di NepTunes.

## Design (dalla fase 1)
- Solo materiali di sistema (.glassEffect, NSGlassEffectView). Niente blur fatti a mano.
- Valori di spaziatura, raggi e tipografia solo da DesignSystem.
```

## Prompt suggeriti per Claude Code

1. *"Leggi CLAUDE.md. Crea project.yml per XcodeGen con target app OpenTunes e target test MediaCoreTests, macOS 26, Swift 6 con strict concurrency."*
2. *"Implementa i modelli Track, PlaybackState e PlayerApp in Sources/MediaCore/Models con test."*
3. *"Implementa MediaRemoteSource seguendo il README di mediaremote-adapter: Process + /usr/bin/perl, parsing JSON riga per riga, gestione dei diff. Aggiungi test con fixture."*
4. *"Implementa AppleScriptSource per Music e Spotify e il fallback automatico in NowPlayingStore."*

## Aggiornamenti dall'analisi (2026-11-12)

- Adapter compilato **da sorgente** (`Vendor/mediaremote-adapter/`, commit `14eed93`) con `scripts/build-mediaremote-adapter.sh`, niente binari di terzi.
- `stream --micros --debounce=30 --experimental-peculiar-debounce:com.tidal.desktop=1000`: l'opzione TIDAL è per-bundle, quindi si passa sempre.
- Dopo exit ≠ 0 l'adapter **non** si rilancia (README upstream); DynamicNotch ed ejbills lo fanno, noi no.
- Diff: una chiave a `null` va rimossa (Boring Notch sbaglia qui). Parsing su `Data`, non su `String` a pezzi.
- Notifiche Musica: osservare sia `com.apple.Music.playerInfo` sia `com.apple.iTunes.playerInfo`.
- Gate YouTube nel browser: possibile **solo** con l'adapter; senza adapter non esiste fallback per i browser.
- `MediaCore` è un target framework separato, così il vincolo "niente SwiftUI" è verificato dal compilatore.
- Niente App Sandbox (serve avviare `/usr/bin/perl`); entitlement `com.apple.security.automation.apple-events`.

## Rischi di questa fase

- **L'adapter non funziona su Golden Gate per qualche player** → verificare subito con `test`; AppleScript come rete di sicurezza.
- **Copertine in ritardo** → usare sempre `stream`, non `get`.
- **Permessi Automazione negati dall'utente** → la sorgente AppleScript lo segnala e l'app continua con l'adapter.

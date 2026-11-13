# OpenTunes

> Nome provvisorio.

App macOS open source che mostra il brano in riproduzione (Apple Music, Spotify, YouTube nel browser e
qualsiasi player che pubblica il Now Playing di sistema) e permette di controllarlo.

**Stato: v0.5** — fase 5: Comandi Rapidi e Siri, riga di comando e URL, Discord Rich Presence, statistiche locali,
modalità focus, controllo MIDI, temi JSON, Maloja. Visualizer con lo spettro reale (algoritmo di cava) e un interruttore
per ogni funzione. Vedi [CHANGELOG](CHANGELOG.md).

![Menu bar, popover e finestra flottante](docs/media/opentunes-fase1.gif)

## Superfici

| Superficie | Cosa mostra | Dove si attiva |
| --- | --- | --- |
| **Menu bar** | copertina, titolo con formato personalizzabile e scorrevole, pulsanti, love; se manca spazio passa da sola a copertina + play/pausa e poi alla sola copertina | sempre |
| **Popover** | copertina grande, avanzamento con seek, shuffle/repeat, volume, ultimi brani, profilo Last.fm | clic sulla menu bar |
| **Finestra flottante** | player Liquid Glass compatto, grande o **focus** (copertina e testo grandi affiancati), sempre in primo piano | Impostazioni › Superfici |
| **Widget di macOS** | tre taglie (piccola, media, grande con ascolti recenti e top artisti Last.fm), pulsanti play/pausa, salto e love | Centro notifiche o scrivania › Modifica widget |
| **Widget live sulla scrivania** | copertina, titolo, controlli, avanzamento in tempo reale, grafico Last.fm opzionale; tre layout, ridimensionabile, bloccabile | Impostazioni › Superfici |
| **Notch** | chiuso: copertina a sinistra e indicatore a destra; aperto (passaggio del mouse o clic): titolo, controlli, avanzamento; titolo per qualche secondo a ogni cambio brano. Sui Mac senza notch: capsula di vetro nella menu bar | Impostazioni › Superfici (disattivabile, es. se usi Boring Notch) |
| **Dock** | copertina del brano come icona | Impostazioni › Superfici |
| **HUD e notifiche** | cambio brano, volume, love, cambio player | Impostazioni › Generali |
| **Scopri** | griglia dei top album Last.fm esportabile in PNG, artisti e brani simili | menu rapido o menu «…» del brano |
| **Statistiche** | ascolti, ore e artisti, grafici settimanali e giornalieri, top artisti, brani e player, tutto in locale | menu rapido, `opentunes stats` |

Menu bar, notch, finestra flottante, widget sulla scrivania e widget di macOS si accendono e si spengono uno per uno in
Impostazioni › Superfici (restano spenti anche dopo il riavvio). Tutte le superfici usano il vetro di sistema con
quattro temi (tinta dalla copertina, monocromo, più trasparente, più opaco) più i **temi JSON** importabili
(esempi in [`themes/`](themes/)). In Impostazioni › Funzioni c'è un interruttore per ogni funzione.

## Funzioni

- **Menu bar**: copertina, titolo con formato personalizzabile (`{artist} — {title}`, solo titolo, …) che scorre
  se è troppo lungo, pulsanti. Elementi riordinabili, controlli anche come elemento separato.
  Se lo spazio non basta (notch, troppe icone, menu lunghi) si riduce da sola a copertina + play/pausa e poi alla
  sola copertina, senza saltare avanti e indietro.
- **Azioni del mouse** configurabili: clic sinistro (player), centrale (play/pausa), destro (menu rapido), rotella (volume o seek).
- **HUD** al cambio brano e volume, **notifiche** con copertina, **scorciatoie globali**, avvio al login.
- Player da ignorare (es. Zoom), pulizia dei titoli di YouTube, copertine mancanti cercate su iTunes (disattivabile).
- **Testi sincronizzati** da [LRCLIB](https://lrclib.net) con cache locale; **link universale** song.link da copiare o
  condividere; **uscita audio** e **volume del player** (Musica, Spotify) dal popover; **visualizer** a tempo di musica
  nel notch e nella finestra flottante: spettro reale dell'audio in uscita con l'algoritmo di
  [cava](https://github.com/karlstav/cava), barre in stile Dynamic Island colorate con la copertina.
- **Scrobbling** su Last.fm e/o ListenBrainz (anche server compatibili come [Maloja](https://github.com/krateng/maloja)) da qualsiasi player: regola standard (metà brano o 4 minuti,
  soglia personalizzabile), la pausa non azzera il tempo, un invio per ascolto, `now playing` a ogni brano.
  Coda offline (SwiftData) con invio a blocchi e nuovi tentativi; indicatore in menu bar se ci sono ascolti in coda.
  Browser esclusi di default; ogni player si può includere o escludere.
- **Scrobble puliti**: via «(Remastered 2011)», «- Radio Edit», «[Official Video]», «feat. …» (opzionale),
  album artist delle compilation, con anteprima nelle impostazioni.
- **Love** su Last.fm (anche come preferito in Musica), **stelle, dislike e aggiungi alla libreria** per Apple Music,
  dal popover, dalla finestra flottante, dal notch, dai widget, dal menu rapido, dalla menu bar e con scorciatoie;
  **cambia player attivo**.
- **Profilo Last.fm** nel popover (scrobble recenti, brani amati, top artisti), in cache per 10 minuti.
- Cronologia degli ascolti salvata tra un avvio e l'altro.
- **Comandi Rapidi, Siri e Spotlight**: «Che brano sta suonando su OpenTunes?», play/pausa, successivo, precedente,
  love, copia il link universale, mostra il testo.
- **Riga di comando e URL**: `opentunes now`, `opentunes next`, `opentunes love`, `opentunes volume 40` (installabile da
  Impostazioni › Integrazioni) o `open opentunes://next` da Raycast, Alfred, BetterTouchTool e Keyboard Maestro.
- **Discord Rich Presence**: «Sta ascoltando» con titolo, artista, copertina e tempo.
- **Controllo da MIDI**: pad e manopole di qualsiasi controller (es. MPD218) per play/pausa, salto, love e volume.
- **Statistiche di ascolto locali** dalla cronologia, senza account.

## Confronto con NepTunes

OpenTunes nasce come alternativa libera a [NepTunes](https://neptunesmac.app). Il confronto si basa sulla pagina
pubblica di NepTunes (novembre 2026) e può non essere aggiornato.

| | OpenTunes | NepTunes |
| --- | --- | --- |
| Licenza | GPL-3.0, codice aperto | proprietaria |
| Prezzo | gratis | versione gratuita + Pro a pagamento |
| Scrobbling Last.fm e ListenBrainz | sì | sì |
| Scrobble puliti | sì | Pro |
| Player supportati | qualsiasi player del Now Playing di sistema, browser compresi | vedi il loro sito |
| Widget sulla scrivania | widget live nativo (3 layout) + widget di macOS | galleria di widget HTML (Pro) |
| Copertina nel Dock | sì | sì |

Non affiliato a NepTunes né ad Apple.

## Installazione

Scarica il `.dmg` dalla [pagina delle release](../../releases), trascina OpenTunes in Applicazioni e,
finché l'app non è notarizzata, togli la quarantena:

```sh
xattr -dr com.apple.quarantine /Applications/OpenTunes.app
```

Con Homebrew (tap personale, vedi `packaging/homebrew/`): `brew install --cask Akiakizero/tap/opentunes`.

## Widget e App Group

I widget di macOS sono in sandbox e leggono lo stato del brano scritto dall'app. Con una build firmata con un Team ID
lo stato passa dall'App Group `<Team ID>.org.opentunes.shared`; le build ufficiali sono firmate ad-hoc e macOS non
autorizza un App Group senza Team ID, quindi l'app scrive in `~/Library/Application Support/OpenTunes/Widget/` e il
widget legge solo quella cartella (eccezione di sola lettura della sandbox). Dalla 0.5 il widget funziona anche così.

## Requisiti

- macOS 26 o successivo
- Xcode 26 o successivo, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```sh
xcodegen generate
xcodebuild -scheme OpenTunes -destination 'platform=macOS' test
```

La build compila automaticamente l'adapter MediaRemote dai sorgenti in `Vendor/mediaremote-adapter/`.
`scripts/make-dmg.sh` crea il `.dmg` in `dist/`; il workflow `Release` lo allega alla release a ogni tag `v*`.

## Come funziona

Da macOS 15.4 le app di terze parti non possono più leggere direttamente il Now Playing di sistema.
OpenTunes usa [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), che passa da
`/usr/bin/perl`. Se l'adapter non funziona, l'app passa da sola ad AppleScript per Apple Music e Spotify
(e chiede il permesso Automazione).

## Last.fm e la API key

Last.fm richiede a ogni app una API key e una *shared secret*. In un'app open source la secret non può restare
segreta: chiunque la estragga dall'app la può usare. È la stessa situazione di tutti gli scrobbler open source.
Per questo:

- le build ufficiali includono la chiave del progetto (segreti `LASTFM_API_KEY` e `LASTFM_API_SECRET`
  del workflow di release); chi compila da sé ottiene un'app senza chiave;
- in Impostazioni › Scrobbling › «Usa una API key personale» puoi inserire la tua
  ([crea una chiave](https://www.last.fm/api/account/create)); la secret va nel Portachiavi.

L'accesso avviene nel browser (flusso desktop di Last.fm): OpenTunes non vede mai la tua password.
La session key e il token di ListenBrainz sono salvati nel Portachiavi. Le build non firmate con un certificato
possono far comparire la richiesta di accesso al Portachiavi dopo ogni aggiornamento: scegli «Consenti sempre».

## Non previsto

Per tenere il progetto piccolo e mantenibile, OpenTunes **non** farà: un player musicale proprio, download o
conversione di brani, statistiche nel cloud o account OpenTunes, versioni per iOS o Windows. Una versione Linux
(GNOME/MPRIS) si valuterà solo se diventa un obiettivo concreto.

## Contribuire

Leggi [CONTRIBUTING.md](CONTRIBUTING.md): issue «good first issue», temi in `themes/`, traduzioni nel catalogo
`Sources/Shared/Localizable.xcstrings` e una guida per lavorare con Claude Code a partire da `CLAUDE.md`.

## Licenza

GPL-3.0-or-later. Vedi [LICENSE](LICENSE) e [CREDITS.md](CREDITS.md).

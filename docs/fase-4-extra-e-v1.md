# Fase 4 — Extra e v1.0

> **Obiettivo:** coprire tutte le funzioni di NepTunes Pro che mancano e aggiungere gli extra che NepTunes non ha. Alla fine di questa fase esce la **v1.0**.

## Gate per chiudere la fase

- [ ] Ogni riga della tabella "Funzioni" del piano è implementata
- [ ] Nessun crash in una settimana di uso quotidiano
- [ ] App notarizzata (se l'account sviluppatore Apple è disponibile) o installazione Homebrew senza passaggi manuali
- [ ] Release `v1.0` con changelog e post di lancio

## 1. Funzioni Pro di NepTunes ancora mancanti

- [x] **Link di condivisione universale**: dal brano corrente genera un link [song.link / Odesli](https://odesli.co) che si apre nel servizio di chi lo riceve; copia negli appunti + menu di condivisione di macOS
- [x] **Griglia Top Albums** da Last.fm (periodo selezionabile: 7 giorni, 1 mese, 12 mesi, sempre), esportabile come immagine
- [x] **Artisti e brani simili** da Last.fm (`artist.getSimilar`, `track.getSimilar`)
- [ ] Verifica finale contro l'elenco Free + Pro di [neptunesmac.app](https://neptunesmac.app)

## 2. Extra

- [x] **Testi sincronizzati** da [LRCLIB](https://lrclib.net): ricerca per titolo, artista, album e durata; riga corrente evidenziata nella finestra flottante e nel notch; cache locale
- [x] **Visualizer audio** nel notch e nella finestra flottante (vedi come lo fa Boring Notch; valutare l'impatto su CPU)
- [x] **Uscita audio**: scelta del dispositivo di uscita dal popover (Core Audio)
- [x] **Volume per player** dove supportato (AppleScript per Music e Spotify)
- [x] **Temi**: tinta dalla copertina, monocromo, più trasparente, più opaco

## 3. Qualità e prestazioni

- [ ] Misure con Instruments: CPU a riposo, CPU durante la riproduzione, memoria dopo 8 ore
- [ ] Obiettivo indicativo: consumo trascurabile a riposo (da definire dopo la prima misura)
- [x] Gestione corretta di sospensione/riattivazione del Mac, cambio monitor, cambio Space
- [ ] Accessibilità: VoiceOver sui controlli, dimensioni del testo, contrasto
- [x] Localizzazione: italiano e inglese; file pronti per Weblate

## 4. Distribuzione v1.0

- [x] Aggiornamenti automatici con [Sparkle](https://github.com/sparkle-project/Sparkle) (MIT)
- [ ] Notarizzazione (richiede account Apple Developer, 99 $ l'anno) — opzionale
- [ ] Proposta del cask al repository ufficiale Homebrew quando il repo raggiunge la soglia di notorietà (per un'auto-proposta: 90 fork, 90 watcher o 225 stelle)
- [x] Sito minimo su GitHub Pages con GIF e download

## 5. Lancio v1.0

- [ ] Show HN su Hacker News
- [ ] Product Hunt
- [ ] Mail breve con GIF a blog Mac (9to5Mac, MacStories, appgefahren, iSpazio)
- [ ] Nuovo post su r/macapps (almeno 30 giorni dopo il precedente)

## Riferimenti open-source

| Progetto | Cosa guardare |
| --- | --- |
| [Boring Notch](https://github.com/TheBoredTeam/boring.notch) | Visualizer, scelta dell'uscita audio (GPL-3) |
| [Tuneful](https://github.com/martinfekete10/Tuneful) | Uscita audio e volume per player (1.x, MIT) |
| [Mooziac](https://alternativeto.net/software/mooziac/about/) | Testi sincronizzati nell'interfaccia |
| [SoundSeer](https://alternativeto.net/software/soundseer/about/) | Copia del link del brano |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Aggiornamenti automatici |

## Prompt suggeriti per Claude Code

1. *"Implementa ShareLinkService con l'API pubblica di Odesli e aggiungi 'Copia link universale' al popover e al menu rapido."*
2. *"Implementa LyricsService con LRCLIB, cache su disco, e una LyricsView che evidenzia la riga corrente usando la posizione del NowPlayingStore."*
3. *"Aggiungi la griglia Top Albums da Last.fm con export PNG."*
4. *"Integra Sparkle con feed appcast generato dalle GitHub Actions."*

## Rischi di questa fase

- **Il visualizer consuma troppa CPU** → disattivato di default, frame rate limitato.
- **Testi non trovati** per brani poco noti → messaggio chiaro, nessun errore.
- **Ritardo della v1.0 per inseguire la perfezione** → fissare l'elenco funzioni ora e spostare le idee nuove in fase 5.

## Aggiornamenti dall'analisi dei progetti di riferimento (2026-11-12)

- Testi: LRCLIB `/api/get` (artista, titolo, album, durata) poi `/api/search`; parser LRC di Mooziac (MIT).
- Sparkle 2 (MIT, macOS 12+): chiavi EdDSA solo nei secret della CI.

## Stato al 2026-11-13

Codice della fase fatto (versione 0.4.0, vedi `CHANGELOG.md`), con test in `Tests/MediaCoreTests/Phase4ServiceTests.swift`
e `Tests/OpenTunesTests/Phase4Tests.swift`:

- `ShareLinkService` (iTunes Search → Odesli, ripiego sul link di Apple Music), «Copia link universale» e «Condividi…»
  in popover, menu rapido e finestra flottante.
- Finestra «Scopri» (`App/Discover`): top album Last.fm con periodo e griglia 3×3–5×5, export PNG con `ImageRenderer`
  (copertine scaricate prima); artisti e brani simili (`artist.getSimilar`, `track.getSimilar`, basta la chiave API).
- `LyricsService` + `LRCParser` (MediaCore, cache in `~/Library/Caches/OpenTunes/lyrics/`, «non trovato» ritentato dopo
  7 giorni); `LyricsView` nella finestra flottante grande, riga corrente nel notch aperto.
- `VisualizerBars`: animazione (non analisi dell'audio, che richiederebbe il permesso di registrazione), spenta di
  default, 20 fps, ferma in pausa. Impatto CPU da misurare con Instruments insieme al resto (punto 3).
- `AudioOutput` (Core Audio) con menu nel popover; volume di Musica/Spotify via `sound volume` (`PlayerVolume.swift`).
- Temi (`SurfaceTheme`) applicati a vetro SwiftUI e `NSGlassEffectView`; la vecchia opzione della tinta è migrata.
- Superfici attivabili una per una (`Surface`, Impostazioni › Superfici); widget WidgetKit spenti = stato
  `WidgetState.disabled`.
- Sospensione/riattivazione e cambio monitor: notch, finestra flottante, volume, uscita audio, coda degli scrobble.
- Catalogo `Sources/Shared/Localizable.xcstrings` (base italiano, inglese completo); i messaggi d'errore di MediaCore
  restano in italiano.
- Sparkle 2 (`App/System/Updater.swift`), appcast firmato in CI (`scripts/make-appcast.sh`, `docs/aggiornamenti.md`).
- Sito in `site/` pubblicato da `.github/workflows/pages.yml`.

Restano, e non si possono fare dall'ambiente di sviluppo:
- misure con Instruments (CPU a riposo e in riproduzione, memoria dopo 8 ore) e una settimana d'uso senza crash;
- verifica a mano di VoiceOver e del contrasto sulle superfici, verifica finale contro l'elenco di neptunesmac.app;
- generare le chiavi di Sparkle e configurare `SPARKLE_PUBLIC_KEY`/`SPARKLE_PRIVATE_KEY`, attivare GitHub Pages;
- notarizzazione (account Apple Developer), release `v1.0` e lancio (punto 5).

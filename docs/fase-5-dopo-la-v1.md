# Fase 5 — Dopo la v1.0

> **Obiettivo:** far crescere il progetto oltre NepTunes — integrazioni, automazione, identità visiva propria — e costruire una community di contributori.

## Gate (continuo)

- [ ] Almeno alcuni contributori esterni con PR accettate
- [ ] Issue e PR gestite con regolarità (anche solo una sessione a settimana)
- [ ] Rilasci regolari con changelog visivi

## 1. Integrazioni

- [x] **Discord Rich Presence** con copertina, titolo e tempo (`DiscordIPC` in MediaCore, `DiscordController`; riferimento: [applemusicrp](https://github.com/wxllow/applemusicrp), MIT, nessun codice copiato)
- [x] **App Intents / Comandi Rapidi**: "Che brano sta suonando?", love, copia link, mostra testo, play/pausa, salto (`App/Automation/OpenTunesIntents.swift`)
- [x] **Spotlight e Siri** tramite gli stessi App Intents (`OpenTunesShortcuts`, frasi in italiano e inglese)
- [x] **CLI** (`opentunes now`, `opentunes next`, `opentunes love`) per chi usa il terminale, Raycast o Alfred (script zsh incluso nell'app, comandi via URL, stato in `now-playing.json`)
- [x] Integrazione opzionale con BetterTouchTool o Keyboard Maestro tramite URL scheme (`URLCommand`)

## 2. Identità visiva propria

- [ ] Evolvere lo stile oltre quello di NepTunes: lettering, icona e temi disegnati da te
- [x] Temi selezionabili e condivisibili (file JSON importabili, `CustomTheme`)
- [x] Possibilità per la community di proporre temi tramite PR (`themes/`, template di issue «Proponi un tema»)

## 3. Idee da valutare

- [x] Statistiche di ascolto locali (senza Last.fm), con grafici settimanali (`ListeningStats`, `StatisticsView`)
- [x] Modalità "focus": la finestra flottante mostra solo copertina e testo grandi (`FloatingSize.focus`)
- [x] Controllo da MIDI (es. pad MPD218 per play/pausa e successivo) (`MIDIControl`, con «Impara»)
- [ ] Core in **Rust** condiviso con una versione Linux/GNOME (MPRIS) — solo se la versione Linux diventa un obiettivo concreto; collegamento a Swift con UniFFI
- [x] Maloja e istanze proprie di ListenBrainz (server personalizzato)
- [ ] Libre.fm (API compatibile con Last.fm ma con autenticazione separata: serve un terzo servizio nella coda)

## 4. Community

- [ ] GitHub Discussions per idee e supporto
- [ ] Traduzioni su Weblate
- [ ] Etichette "good first issue" sempre presenti (etichette in `.github/labels.yml`, anche `theme`, `integration`, `translation`)
- [ ] Roadmap pubblica (GitHub Projects)
- [x] Guida per contribuire con Claude Code: come usare `CLAUDE.md`, come proporre una PR (`CONTRIBUTING.md`)

## 5. Manutenzione

- [ ] Test sulla beta di macOS 28 a partire da giugno (WWDC)
- [ ] Monitorare il repository di mediaremote-adapter per cambiamenti di Apple
- [ ] Rivedere le dipendenze ogni release

## Stato (0.5.0, 2026-11-13)

Fatto nella 0.5.0: integrazioni (Comandi Rapidi, Siri, Spotlight, CLI, URL, Discord), temi JSON, statistiche locali,
modalità focus, MIDI, Maloja, guida per contribuire, sezione «Non previsto» nel README. Prima della fase 5 sono state
corrette le superfici (spettro reale con l'algoritmo di cava, menu bar che si riduce in modo stabile, widget di macOS
con la firma ad-hoc) ed è arrivato un interruttore per ogni funzione.

Restano aperti: identità visiva propria (lettering e icona), Libre.fm, core in Rust (solo se serve Linux), e le voci
continue di community e manutenzione (Discussions, Weblate, roadmap pubblica, beta di macOS 28).

## Riferimenti open-source

| Progetto | Cosa guardare |
| --- | --- |
| [applemusicrp](https://github.com/wxllow/applemusicrp) | Discord Rich Presence con copertina |
| [GoPlaying](https://www.linuxlinks.com/goplaying-tui-showing-whats-playing/) | Estrazione colori dalla copertina, versione da terminale |
| [goscrobble](https://github.com/p-mng/goscrobble) | Esempio di scrobbler multipiattaforma macOS/Linux (MIT) |
| [media-controls](https://github.com/sakithb/media-controls) | Riferimento per un eventuale port su GNOME |

## Prompt suggeriti per Claude Code

1. *"Esponi le azioni principali come App Intents (NowPlaying, Love, CopyShareLink, ShowLyrics) con frasi in italiano e inglese."*
2. *"Crea un target CLI 'opentunes' che comunica con l'app tramite XPC o URL scheme."*
3. *"Implementa i temi come file JSON validati, con import ed export dalle impostazioni."*

## Rischi di questa fase

- **Burnout da manutenzione** → delegare: co-maintainer, issue ben descritte, niente promesse di date.
- **Richieste di funzioni infinite** → una sezione "Non previsto" nel README con le cose che il progetto non farà.
- **Apple chiude il Now Playing** → la fase 0 ha già il fallback AppleScript; comunicare subito agli utenti cosa smette di funzionare.

## Aggiornamenti dall'analisi dei progetti di riferimento (2026-11-12)

- ListenBrainz e export CSV: modello Source/Sink di goscrobble (MIT).
- Processo adapter persistente con comandi da stdin (idea del fork ejbills) per non lanciare perl a ogni comando.

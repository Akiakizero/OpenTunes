# Fase 1 — Menu bar e finestra flottante

> **Obiettivo:** un'app che usi ogni giorno al posto di NepTunes per le funzioni di base. Menu bar in stile media-controls (GNOME), finestra flottante Liquid Glass, hotkey e notifiche.

## Gate per chiudere la fase

- [ ] Sostituisce NepTunes nell'uso di base per almeno una settimana
- [ ] La menu bar resta visibile accanto al notch del MacBook Pro 16" (modalità compatta funzionante)
- [ ] Tutte le superfici sono coerenti in tema chiaro e scuro e con il cursore di trasparenza di Golden Gate
- [ ] Prima release `v0.1` su GitHub con `.dmg`

## 1. Design system (da fare per primo)

- [x] Modulo `DesignSystem` con: raggi, spaziature (multipli di 4/8), scala tipografica, durate delle animazioni
- [x] Tinta d'accento estratta dalla copertina (colore dominante + controllo di contrasto)
- [x] Componenti condivisi, usati da tutte le superfici:
  - [x] `ArtworkView` (copertina con angoli arrotondati, placeholder, transizione al cambio brano)
  - [x] `PlaybackControls` (precedente, play/pausa, successivo; varianti compatta e completa)
  - [x] `ProgressBar` (con seek trascinabile)
  - [x] `MarqueeText` (testo che scorre, si ferma con il mouse sopra)
- [x] Regola: solo materiali di sistema (`.glassEffect()`, `NSGlassEffectView`), niente blur o sfondi fissi
- [x] Screenshot di ogni componente in tema chiaro e scuro (anteprime SwiftUI in Xcode)

## 2. Menu bar in stile media-controls

- [x] `NSStatusItem` con vista SwiftUI personalizzata
- [x] Elementi configurabili e riordinabili: copertina, titolo/artista, pulsanti
- [x] Formato del titolo personalizzabile (es. `{artist} — {title}`, solo titolo, solo icona)
- [x] Larghezza massima del titolo con `MarqueeText`
- [x] Azioni del mouse configurabili:
  - [x] clic sinistro → apre il popover
  - [x] clic centrale → play/pausa
  - [x] clic destro → menu rapido
  - [x] rotella → volume o seek
- [x] **Modalità compatta automatica** quando lo spazio a destra del notch non basta (solo copertina + play/pausa)
- [x] Opzione: controlli e titolo come due elementi separati
- [x] Nascondi l'elemento quando non c'è niente in riproduzione (opzionale)
- [x] Blacklist dei player per bundle ID (es. ignorare Zoom, video di Safari)

## 3. Popover della menu bar

- [x] Copertina grande, titolo, artista, album
- [x] `ProgressBar` con seek
- [x] Controlli completi, shuffle e repeat (dove il player li supporta)
- [x] Ultimi brani ascoltati (lista in memoria per ora; persistenza in fase 2)
- [x] Pulsante per aprire il player sorgente

## 4. Finestra flottante

- [x] `NSPanel` non attivante, sempre in primo piano, trascinabile, posizione ricordata
- [x] Due taglie: compatta e grande
- [x] Liquid Glass con tinta dalla copertina
- [x] Mostra/nascondi con hotkey
- [x] Si nasconde automaticamente con app a schermo intero (opzionale)

## 5. Hotkey e HUD

- [x] Hotkey globali configurabili con [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (MIT): play/pausa, successivo, precedente, volume su/giù, mostra finestra
- [x] HUD a schermo al cambio brano e al cambio volume

## 6. Notifiche

- [x] Notifica al cambio brano con copertina (`UserNotifications`)
- [x] Opzione per disattivarle o mostrarle solo quando la finestra flottante è nascosta

## 7. Impostazioni

- [x] Finestra con sezioni Generali, Menu bar, Posizione, Scorciatoie, Altro (struttura presa da media-controls)
- [x] Avvio al login (`SMAppService`)

## 8. Release v0.1

- [x] `.dmg` allegato alla release GitHub tramite Actions
- [ ] Tap Homebrew personale (`brew install <utente>/tap/opentunes`) — cask pronto in `packaging/homebrew/opentunes.rb`, manca il repository del tap
- [x] Istruzioni `xattr -dr com.apple.quarantine` nel README finché l'app non è notarizzata
- [x] GIF della menu bar e della finestra flottante nel README (`docs/media/opentunes-fase1.gif`, dalle anteprime con dati finti; da sostituire con una registrazione dal vivo via `scripts/record-gif.sh`)

## Riferimenti open-source

| Progetto | Cosa guardare |
| --- | --- |
| [media-controls](https://github.com/sakithb/media-controls) | Funzioni della barra, azioni del mouse, struttura delle impostazioni (MIT, solo idee: è JavaScript) |
| [SpotMenu](https://github.com/kmikiy/SpotMenu) | Menu bar matura in Swift, hotkey, overlay con copertina (MIT) |
| [PlayStatus](https://github.com/nbolar/playstatus) | Formati del titolo, testo che scorre, transizioni |
| [Tuneful](https://github.com/martinfekete10/Tuneful) | Mini player always-on-top (versione 1.x, MIT) |
| [Now Playing (dd00031)](https://github.com/dd00031/now-playing) | App SwiftUI di Now Playing (GPL-3) |
| [Boring Notch](https://github.com/TheBoredTeam/boring.notch) | HUD di sistema sostitutivo (GPL-3) |

## Prompt suggeriti per Claude Code

1. *"Crea il modulo DesignSystem con token e i componenti ArtworkView, PlaybackControls, ProgressBar, MarqueeText. Solo materiali di sistema. Aggiungi #Preview in chiaro e scuro."*
2. *"Implementa la menu bar con NSStatusItem e vista SwiftUI, elementi riordinabili e azioni del mouse configurabili, come descritto in fase-1."*
3. *"Aggiungi la modalità compatta: misura lo spazio disponibile e riduci l'elemento quando non entra accanto al notch."*
4. *"Implementa la finestra flottante come NSPanel non attivante con due taglie e posizione salvata."*

## Rischi di questa fase

- **L'elemento sparisce dietro il notch** senza avvisi → modalità compatta + test su MacBook Pro 16".
- **Il Liquid Glass sembra diverso tra superfici** → tutto passa da `DesignSystem`, nessuna eccezione.
- **Scope creep** → niente Last.fm in questa fase, anche se è allettante.

## Aggiornamenti dall'analisi dei progetti di riferimento (2026-11-12)

- Copertine Spotify via AppleScript: solo URL → download con cache (fatto in fase 0); copertine mancanti dei browser: lookup iTunes come PlayStatus.
- Titoli YouTube "sporchi": riusare le regex di normalizzazione di web-scrobbler (MIT).
- Testo scorrevole e preferenze (larghezza, elementi, blacklist player): idee da media-controls (GNOME).
- KeyboardShortcuts come dipendenza SPM; avvio al login con `SMAppService`.
- Tuneful non ha più sorgenti pubblici: solo idee di prodotto.

## Stato dell'implementazione (2026-11-12)

- Fatto: tutte le voci spuntate sopra; 56 test (MediaCore + logica dell'app) verdi; `.dmg` creato in locale con `scripts/make-dmg.sh`.
- Modalità compatta verificata su MacBook Pro 16" con menu bar affollata: l'elemento pieno finiva sotto il notch ed è
  passato a compatto (log `[menubar]` con `OPENTUNES_LOG_FILE`).
- Volume: è il volume di sistema (CoreAudio), perché l'adapter non ha un comando per il volume del player.
- Hotkey: nessuna combinazione predefinita (si scelgono in Impostazioni › Scorciatoie).
- HUD: lo stesso per cambio brano, play/pausa e salto; posizione scelta in Impostazioni › Posizione.
- Verifica dal vivo (tema scuro, Firefox/YouTube): menu bar compatta a destra del notch, popover, finestra flottante,
  HUD di cambio brano e volume, titoli YouTube ripuliti. Stesse superfici controllate anche in tema chiaro;
  il cursore di trasparenza non è ancora stato provato (le superfici usano solo materiali di sistema).
- Restano aperti: gate d'uso (una settimana), prova del cursore di trasparenza, prima release `v0.1` (tag e remote GitHub), repository del tap Homebrew.

# Fase 3 — Widget, notch e icona del Dock

> **Obiettivo:** completare tutte le superfici — widget WidgetKit, widget live sul desktop, player nel notch, copertina come icona del Dock — e fare il primo rilascio pubblico.

## Gate per chiudere la fase

- [ ] Widget WidgetKit in tre taglie aggiornati entro pochi secondi dal cambio brano
- [ ] Widget live fluido sul desktop, con barra di avanzamento in tempo reale
- [ ] Player nel notch stabile sul MacBook Pro 16"
- [ ] Release pubblica `v0.3` con cask Homebrew nel tap personale
- [ ] Post di lancio su r/macapps (nel megathread "App Pile" o nel feed principale se i requisiti sono soddisfatti)

## 1. Widget WidgetKit (Centro notifiche e desktop)

- [ ] Nuovo target "Widget Extension" in `project.yml`
- [ ] **App Group** condiviso tra app e widget per passare lo stato (brano, copertina ridotta, stato di riproduzione)
- [ ] Tre taglie: piccola (copertina + play/pausa), media (copertina + titolo + controlli), grande (con Last.fm: brani recenti o top artisti)
- [ ] Pulsanti interattivi con **App Intents** (play/pausa, successivo, love)
- [ ] `WidgetCenter.shared.reloadTimelines` al cambio brano
- [ ] Materiali e stile coerenti con `DesignSystem` (versione condivisa tra app ed estensione)

> Limite noto: WidgetKit ha un budget di aggiornamenti e non può mostrare una barra di avanzamento in tempo reale. Per quello c'è il widget live.

## 2. Widget live sul desktop (funzione Pro di NepTunes)

- [ ] `NSWindow` senza bordi a livello del desktop (sopra lo sfondo, sotto le altre finestre)
- [ ] Visibile su tutti gli Spaces
- [ ] Trascinabile, ridimensionabile, posizione salvata per ogni monitor
- [ ] Contenuti: copertina, titolo, controlli, barra di avanzamento live, grafico Last.fm opzionale
- [ ] Più layout selezionabili
- [ ] Bloccabile per evitare spostamenti accidentali

## 3. Player nel notch

- [ ] Integrazione di [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) (MIT)
- [ ] Stato chiuso: copertina piccola a sinistra del notch, indicatore di riproduzione a destra
- [ ] Stato aperto (hover o clic): copertina, titolo, controlli, avanzamento
- [ ] Animazione al cambio brano
- [ ] Sui Mac senza notch: capsula flottante come in [DynamicNotch](https://github.com/jackson-storm/DynamicNotch) (GPL-3)
- [ ] Opzione per disattivare il notch se l'utente usa già Boring Notch

## 4. Icona del Dock e copertine animate

- [ ] Copertina come icona del Dock tramite `NSApp.dockTile` (opzionale: l'app di solito vive solo nella menu bar)
- [ ] Copertine animate quando il servizio le fornisce (Apple Music) — verificare cosa espone il Now Playing; se non disponibile, rimandare
- [ ] Colori dalla copertina applicati a tutte le superfici (temi dinamici)

## 5. Lancio v0.3

- [ ] README completo: GIF di ogni superficie, tabella funzioni, confronto con NepTunes (senza usare i loro asset)
- [ ] `CONTRIBUTING.md`, modelli di issue e PR, etichette "good first issue"
- [ ] Scheda su [AlternativeTo](https://alternativeto.net) come alternativa a NepTunes
- [ ] PR su [open-source-mac-os-apps](https://github.com/serhii-londar/open-source-mac-os-apps)
- [ ] Post su r/macapps (rispettando le regole: dichiarare di essere lo sviluppatore, max una volta ogni 30 giorni)
- [ ] Post su r/lastfm, r/opensource, r/swift (taglio tecnico)

## Riferimenti open-source

| Progetto | Cosa guardare |
| --- | --- |
| [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) | Finestra nel notch con viste SwiftUI (MIT) |
| [Boring Notch](https://github.com/TheBoredTeam/boring.notch) | Player e visualizer nel notch, gestione hover (GPL-3) |
| [DynamicNotch](https://github.com/jackson-storm/DynamicNotch) | Capsula flottante per Mac senza notch (GPL-3) |
| [Tuneful](https://github.com/martinfekete10/Tuneful) | Prima versione del notch player (1.x, MIT) |
| [Mooziac](https://alternativeto.net/software/mooziac/about/) | Interfaccia stile Dynamic Island e gesture del trackpad |

## Prompt suggeriti per Claude Code

1. *"Aggiungi il target Widget Extension in project.yml con App Group condiviso. Implementa i widget small/medium/large con App Intents per play/pausa e successivo."*
2. *"Implementa DesktopWidgetWindow: NSWindow senza bordi a livello desktop, su tutti gli Spaces, trascinabile, posizione salvata per monitor."*
3. *"Integra DynamicNotchKit e crea NotchPlayerView riusando i componenti di DesignSystem."*

## Rischi di questa fase

- **Widget che non si aggiornano** → verificare App Group ed entitlement; testare con build firmata.
- **Finestra a livello desktop che finisce sopra le icone o sparisce con Mission Control** → testare i livelli di finestra su macOS 27.
- **Conflitto con altre app del notch** → opzione per disattivare il notch.

## Aggiornamenti dall'analisi dei progetti di riferimento (2026-11-12)

- Preferire DynamicNotchKit (MIT, API pubbliche) e NotchDrop (MIT) alla finestra SkyLight privata di Boring Notch.
- Verificare DynamicNotchKit con Swift 6 strict concurrency; sostituire i blur fatti a mano con materiali di sistema.

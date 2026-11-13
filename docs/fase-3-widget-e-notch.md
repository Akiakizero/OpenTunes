# Fase 3 — Widget, notch e icona del Dock

> **Obiettivo:** completare tutte le superfici — widget WidgetKit, widget live sul desktop, player nel notch, copertina come icona del Dock — e fare il primo rilascio pubblico.

## Gate per chiudere la fase

- [ ] Widget WidgetKit in tre taglie aggiornati entro pochi secondi dal cambio brano — implementato (ricarica 0,4 s dopo il cambio, avanzamento con `ProgressView(timerInterval:)`); da verificare con una build firmata con Team ID
- [x] Widget live fluido sul desktop, con barra di avanzamento in tempo reale
- [ ] Player nel notch stabile sul MacBook Pro 16" — implementato e provato sullo schermo da 1728×1117 (stato aperto); manca una settimana d'uso
- [ ] Release pubblica `v0.3` con cask Homebrew nel tap personale — versione 0.3.0 e cask pronti; tag e tap da fare a mano (`docs/lancio/README.md`)
- [ ] Post di lancio su r/macapps (nel megathread "App Pile" o nel feed principale se i requisiti sono soddisfatti) — bozza in `docs/lancio/reddit-macapps.md`

## 1. Widget WidgetKit (Centro notifiche e desktop)

- [x] Nuovo target "Widget Extension" in `project.yml` (`OpenTunesWidget`, in sandbox, senza MediaCore)
- [x] **App Group** condiviso tra app e widget per passare lo stato (brano, copertina ridotta, stato di riproduzione): `$(TeamIdentifierPrefix)org.opentunes.shared`, file `widget-state.json` + `widget-artwork.png` (`WidgetBridge`)
- [x] Tre taglie: piccola (copertina + play/pausa), media (copertina + titolo + controlli), grande (con Last.fm: brani recenti e top artisti)
- [x] Pulsanti interattivi con **App Intents** (play/pausa, successivo, precedente, love): `AudioPlaybackIntent`, eseguiti nel processo dell'app
- [x] `WidgetCenter.shared.reloadTimelines` al cambio brano (solo quando cambia qualcosa di visibile, per il budget)
- [x] Materiali e stile coerenti con `DesignSystem` (versione condivisa tra app ed estensione: `DesignSystem.swift` e `AccentTint.swift` compilati in entrambi)

> Limite noto: WidgetKit ha un budget di aggiornamenti e non può mostrare una barra di avanzamento in tempo reale. Per quello c'è il widget live.

## 2. Widget live sul desktop (funzione Pro di NepTunes)

- [x] `NSWindow` senza bordi a livello del desktop (sopra lo sfondo, sotto le altre finestre): livello `desktopIconWindow + 1`, così i clic non finiscono alla scrivania del Finder
- [x] Visibile su tutti gli Spaces (`.canJoinAllSpaces`, `.stationary` per Mission Control)
- [x] Trascinabile, ridimensionabile, posizione salvata per ogni monitor (UUID del display, `DesktopWidgetPlacement`)
- [x] Contenuti: copertina, titolo, controlli, barra di avanzamento live, grafico Last.fm opzionale (top artisti, Swift Charts)
- [x] Più layout selezionabili (scheda, orizzontale, solo copertina)
- [x] Bloccabile per evitare spostamenti accidentali

## 3. Player nel notch

- [x] Integrazione di [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) (MIT) — adattati `NotchShape` e la misura del notch; il pannello è nostro perché l'API della libreria usa `ObservableObject`/Combine e `NSVisualEffectView` (vedi CREDITS.md)
- [x] Stato chiuso: copertina piccola a sinistra del notch, indicatore di riproduzione a destra (solo mentre suona)
- [x] Stato aperto (hover o clic): copertina, titolo, controlli, avanzamento, love
- [x] Animazione al cambio brano (il notch si allarga e mostra il titolo per 3 s, copertina in dissolvenza)
- [x] Sui Mac senza notch: capsula flottante come in [DynamicNotch](https://github.com/jackson-storm/DynamicNotch) (GPL-3) — capsula di vetro al centro della menu bar
- [x] Opzione per disattivare il notch se l'utente usa già Boring Notch (le impostazioni lo segnalano se Boring Notch, DynamicNotch o NotchDrop sono aperte)

## 4. Icona del Dock e copertine animate

- [x] Copertina come icona del Dock tramite `NSApp.applicationIconImage` (opzionale: con l'opzione attiva l'app passa a `.regular`)
- [ ] Copertine animate quando il servizio le fornisce (Apple Music) — verificato: l'adapter espone solo `artworkData` statico (+ `artworkMimeType`), nessuna copertina animata. Rimandato
- [x] Colori dalla copertina applicati a tutte le superfici (temi dinamici): popover, finestra flottante, HUD, widget sulla scrivania, notch, widget di macOS

## 5. Lancio v0.3

- [ ] README completo: GIF di ogni superficie, tabella funzioni, confronto con NepTunes (senza usare i loro asset) — tabella e confronto fatti; GIF delle superfici nuove da registrare con contenuti scelti apposta
- [x] `CONTRIBUTING.md`, modelli di issue e PR, etichette "good first issue" (`.github/labels.yml` + `scripts/sync-labels.sh`, da lanciare sul repository)
- [ ] Scheda su [AlternativeTo](https://alternativeto.net) come alternativa a NepTunes — testo in `docs/lancio/alternativeto.md`
- [ ] PR su [open-source-mac-os-apps](https://github.com/serhii-londar/open-source-mac-os-apps) — voce pronta in `docs/lancio/open-source-mac-os-apps.md`
- [ ] Post su r/macapps (rispettando le regole: dichiarare di essere lo sviluppatore, max una volta ogni 30 giorni) — bozza pronta
- [ ] Post su r/lastfm, r/opensource, r/swift (taglio tecnico) — bozze in `docs/lancio/reddit-altri.md`

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

## Stato al 2026-11-13

Il codice della fase è completo (widget, widget sulla scrivania, notch, Dock, tinte) con test in
`Tests/OpenTunesTests/Phase3Tests.swift`. Restano i passi manuali: build firmata per provare i widget di macOS,
GIF delle superfici, tag `v0.3.0`, tap Homebrew, etichette su GitHub e i post (vedi `docs/lancio/`).

- Le anteprime di Xcode non supportano i widget su macOS: `NowPlayingWidgetView` riceve la taglia come parametro,
  così si può disegnare anche con `ImageRenderer` fuori da WidgetKit.
- Con la firma ad-hoc l'App Group diventa `org.opentunes.shared` (prefisso del Team ID vuoto); Xcode non chiede un
  provisioning profile perché non è un gruppo `group.*`.

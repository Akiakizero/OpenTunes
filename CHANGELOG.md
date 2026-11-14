# Changelog

## 0.5.0 — fase 5

La prima release pubblica dopo la 0.3.0: comprende anche tutta la fase 4 (sotto).

### Nuovo
- **Comandi Rapidi, Siri e Spotlight**: «Che brano sta suonando su OpenTunes?», play/pausa, successivo, precedente,
  love, copia il link universale, mostra il testo. Frasi in italiano e in inglese.
- **Riga di comando e URL**: `opentunes now | status | json | next | love | copy-link | volume 40 | seek -10 …`
  (Impostazioni › Integrazioni › Installa) e `open opentunes://next` per Raycast, Alfred, BetterTouchTool,
  Keyboard Maestro. Lo stato del brano è in `~/Library/Application Support/OpenTunes/now-playing.json`.
- **Discord Rich Presence**: «Sta ascoltando» con titolo, artista, album, copertina e tempo; sparisce in pausa.
- **Statistiche di ascolto locali**: ascolti, ore, artisti, grafici per settimana e per giorno, top artisti, brani e
  player (7 giorni, 30 giorni, 12 mesi, sempre). La cronologia ora tiene fino a 10.000 ascolti.
- **Modalità focus** della finestra flottante: copertina e testo sincronizzato grandi, affiancati.
- **Controllo da MIDI**: pad e manopole di qualsiasi controller, con «Impara».
- **Temi JSON** importabili ed esportabili, con esempi in `themes/` e un modello per proporne di nuovi.
- **Maloja** e istanze proprie di ListenBrainz: campo «Server» nelle impostazioni di ListenBrainz.
- **Un interruttore per ogni funzione** (Impostazioni › Funzioni): love, azioni di Musica, cambio player, link
  universale, testi, Scopri, ogni parte del popover, visualizer e spettro, HUD, scorciatoie, Comandi Rapidi, URL,
  Discord, MIDI, statistiche.

### Corretto
- **Widget di macOS** (Centro notifiche e scrivania) di nuovo con il brano in riproduzione: con la firma ad-hoc l'App
  Group senza Team ID non è autorizzato e il widget in sandbox non lo leggeva. Ora lo stato passa da una cartella che il
  widget legge con un'eccezione di sola lettura.
- **Visualizer**: le barre seguono davvero la musica. Prima erano sempre l'animazione di ripiego: mancava nell'app la
  descrizione del permesso «Registrazione audio di sistema» (macOS rifiutava la cattura) e la cattura si ricreava di
  continuo (creare il dispositivo aggregato cambiava l'elenco dei dispositivi e faceva ripartire lo spettro). Si legge il
  flusso del tap audio (prima, con uscite come le AirPods, si leggeva il microfono) e l'analisi usa l'algoritmo di cava: equalizzazione per frequenza, sensibilità automatica,
  gravità e filtro integrale a 60 analisi al secondo. Nuovo aspetto in stile Dynamic Island: sei capsule sottili
  centrate, più alte al centro (bassi e medi al centro, acuti ai lati), colorate con una sfumatura dei colori della
  copertina, puntini nel silenzio.
- **Menu bar** stabile quando manca spazio: passa da sola a copertina + play/pausa e poi alla sola copertina (anche senza
  notch, se il sistema nasconde l'elemento), con isteresi e memoria della larghezza che non stava: niente più salti.
  Accanto al notch resta sempre un margine (macOS nasconde gli elementi anche a pochi punti dal notch) e il calcolo
  dello spazio comprende il margine che il sistema aggiunge attorno all'elemento.
- **Widget sulla scrivania** di nuovo visibile: su macOS 27 una finestra del Window Server allo stesso livello lo
  copriva; ora sta al livello dei widget di macOS.

## Fase 4 (pubblicata con la 0.5.0)

### Nuovo
- **Superfici attivabili**: in Impostazioni › Superfici un interruttore per menu bar, notch, finestra flottante,
  widget sulla scrivania e widget di macOS. Una superficie spenta resta spenta dopo il riavvio; la finestra
  flottante spenta non si apre più con scorciatoie e menu, i widget di macOS mostrano «disattivato».
- **Testi sincronizzati** da LRCLIB con cache su disco: nella finestra flottante grande (pulsante testo, clic su una
  riga per saltare) e una riga sotto il titolo nel notch aperto.
- **Link universale** song.link (Odesli): «Copia link universale» e «Condividi…» nel popover, nel menu rapido e nella
  finestra flottante.
- **Scopri**: griglia dei top album di Last.fm (7 giorni, 1 mese, 12 mesi, sempre; 3×3–5×5) esportabile in PNG,
  artisti e brani simili a quello in riproduzione.
- **Uscita audio** scelta dal popover e **volume del player** (Musica, Spotify) separato da quello di sistema.
- **Temi**: tinta dalla copertina, monocromo, più trasparente, più opaco.
- **Visualizer** nel notch e nella finestra flottante: spettro reale dell'audio in uscita (process tap di Core Audio,
  permesso «Registrazione audio di sistema», niente viene registrato), animazione se il permesso manca; fermo in pausa e
  con «Riduci movimento».
- **Aggiornamenti automatici** con Sparkle (attivi nelle build di release con la chiave pubblica).
- **Inglese**: catalogo `Localizable.xcstrings` (italiano di base), pronto per Weblate.

### Migliorato
- Notch: la copertina chiusa ha lo stesso margine sopra, sotto e verso l'esterno (non finisce più sulla curva
  dell'angolo), indicatore simmetrico, titolo del «peek» staccato dal bordo, copertina allineata al titolo da aperto.
- Riattivazione dal sopore e cambio monitor: notch, finestra flottante, volume e uscita audio si riallineano; la coda
  degli scrobble riparte.
- VoiceOver: il notch chiuso è un pulsante con il titolo del brano; righe del testo come pulsanti.
- Impostazioni: «Posizione» unita a «Generali» (HUD), finestra flottante spostata in «Superfici».

## 0.3.0
- Widget di macOS, widget live sulla scrivania, player nel notch, copertina nel Dock.

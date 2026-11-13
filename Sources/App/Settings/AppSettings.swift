// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MediaCore
import Observation

/// Elementi della menu bar, riordinabili.
enum MenuBarElement: String, CaseIterable, Codable, Identifiable, Sendable {
    case artwork, title, controls, love

    var id: String { rawValue }

    var label: String {
        switch self {
        case .artwork: String(localized: "Copertina")
        case .title: String(localized: "Titolo e artista")
        case .controls: String(localized: "Pulsanti")
        case .love: String(localized: "Love (Last.fm / Musica)")
        }
    }

    /// Elementi aggiunti in versioni successive che partono nascosti.
    static let hiddenByDefault: Set<MenuBarElement> = [.love]
}

/// Cosa fa un clic sull'elemento in menu bar.
enum MouseAction: String, CaseIterable, Identifiable, Sendable {
    case openPopover, playPause, nextTrack, previousTrack, quickMenu, toggleFloatingWindow, love, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openPopover: String(localized: "Apri il player")
        case .playPause: String(localized: "Play/pausa")
        case .nextTrack: String(localized: "Brano successivo")
        case .previousTrack: String(localized: "Brano precedente")
        case .quickMenu: String(localized: "Menu rapido")
        case .toggleFloatingWindow: String(localized: "Mostra/nascondi finestra flottante")
        case .love: String(localized: "Love")
        case .none: String(localized: "Niente")
        }
    }
}

/// Cosa fa la rotella sopra l'elemento in menu bar.
enum ScrollAction: String, CaseIterable, Identifiable, Sendable {
    case volume, seek, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .volume: String(localized: "Volume")
        case .seek: String(localized: "Avanti/indietro nel brano")
        case .none: String(localized: "Niente")
        }
    }
}

enum FloatingSize: String, CaseIterable, Identifiable, Sendable {
    case compact, large
    /// Modalità focus: copertina e testo grandi, uno accanto all'altro.
    case focus

    var id: String { rawValue }
    var label: String {
        switch self {
        case .compact: String(localized: "Compatta")
        case .large: String(localized: "Grande")
        case .focus: String(localized: "Focus (copertina e testo)")
        }
    }
}

/// Layout del widget live sulla scrivania.
enum DesktopWidgetLayout: String, CaseIterable, Identifiable, Sendable {
    case card, horizontal, artwork

    var id: String { rawValue }

    var label: String {
        switch self {
        case .card: String(localized: "Scheda (copertina sopra)")
        case .horizontal: String(localized: "Orizzontale")
        case .artwork: String(localized: "Solo copertina")
        }
    }
}

enum NotificationMode: String, CaseIterable, Identifiable, Sendable {
    case off, always, whenFloatingHidden

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: String(localized: "Mai")
        case .always: String(localized: "Sempre")
        case .whenFloatingHidden: String(localized: "Solo se la finestra flottante è nascosta")
        }
    }
}

enum HUDPosition: String, CaseIterable, Identifiable, Sendable {
    case bottom, center, topRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bottom: String(localized: "In basso al centro")
        case .center: String(localized: "Al centro")
        case .topRight: String(localized: "In alto a destra")
        }
    }
}

/// Superfici dell'app, ognuna attivabile o disattivabile in modo permanente dalle impostazioni.
enum Surface: String, CaseIterable, Identifiable, Sendable {
    case menuBar, notch, floating, desktopWidget, systemWidget

    var id: String { rawValue }

    var label: String {
        switch self {
        case .menuBar: String(localized: "Menu bar")
        case .notch: String(localized: "Notch")
        case .floating: String(localized: "Finestra flottante")
        case .desktopWidget: String(localized: "Widget sulla scrivania")
        case .systemWidget: String(localized: "Widget di macOS")
        }
    }

    var symbol: String {
        switch self {
        case .menuBar: "menubar.rectangle"
        case .notch: "macbook"
        case .floating: "pip"
        case .desktopWidget: "rectangle.on.rectangle"
        case .systemWidget: "square.grid.2x2"
        }
    }

    var summary: String {
        switch self {
        case .menuBar: String(localized: "Titolo, copertina e controlli in alto a destra, con il player completo al clic.")
        case .notch: String(localized: "Copertina ai lati del notch, player completo passandoci sopra.")
        case .floating: String(localized: "Mini player sempre in primo piano, da mostrare con una scorciatoia o dal menu.")
        case .desktopWidget: String(localized: "Player live sullo sfondo, sotto le finestre.")
        case .systemWidget: String(localized: "Widget «In riproduzione» del Centro notifiche e della scrivania.")
        }
    }
}

/// Preferenze dell'utente, salvate in `UserDefaults` a ogni modifica.
@Observable
@MainActor
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults
    /// `false` per anteprime: le modifiche restano in memoria.
    @ObservationIgnored private let persists: Bool

    // MARK: Superfici

    /// Elemento in menu bar. Spento, le impostazioni si aprono riaprendo l'app dal Finder o da Spotlight.
    var menuBarEnabled: Bool { didSet { save(menuBarEnabled, "menuBarEnabled") } }
    /// Finestra flottante disponibile: spenta, scorciatoie e menu non la mostrano più.
    var floatingEnabled: Bool { didSet { save(floatingEnabled, "floatingEnabled") } }
    /// Widget WidgetKit: spento, l'app non scrive più lo stato e i widget mostrano che sono disattivati.
    var systemWidgetEnabled: Bool { didSet { save(systemWidgetEnabled, "systemWidgetEnabled") } }

    // MARK: Aspetto

    var theme: SurfaceTheme { didSet { save(theme.rawValue, "theme") } }
    /// File del tema personalizzato (JSON già validato), usato con `theme == .custom`.
    var customThemeJSON: String { didSet { save(customThemeJSON, "customThemeJSON") } }
    /// Barre animate al posto dell'indicatore di riproduzione (notch e finestra flottante).
    var visualizerEnabled: Bool { didSet { save(visualizerEnabled, "visualizerEnabled") } }

    /// Il visualizer segue l'audio reale (process tap): spento, è solo un'animazione e non serve alcun permesso.
    var visualizerUsesAudio: Bool { didSet { save(visualizerUsesAudio, "visualizerUsesAudio") } }

    // MARK: Funzioni (ognuna si può spegnere)

    /// Brani ascoltati di recente nel popover.
    var showsRecentTracks: Bool { didSet { save(showsRecentTracks, "showsRecentTracks") } }
    /// Scheda Last.fm (profilo, recenti, top artisti) nel popover.
    var showsLastFMProfile: Bool { didSet { save(showsLastFMProfile, "showsLastFMProfile") } }
    /// Pulsante love (Last.fm / preferito di Musica) in popover, finestra flottante, menu e widget.
    var loveEnabled: Bool { didSet { save(loveEnabled, "loveEnabled") } }
    /// Stelle, dislike e «Aggiungi alla libreria» per i brani di Musica.
    var musicActionsEnabled: Bool { didSet { save(musicActionsEnabled, "musicActionsEnabled") } }
    /// «Passa a…» per cambiare player tra Musica e Spotify.
    var switchPlayerEnabled: Bool { didSet { save(switchPlayerEnabled, "switchPlayerEnabled") } }
    /// Link universale song.link e menu Condividi.
    var shareLinksEnabled: Bool { didSet { save(shareLinksEnabled, "shareLinksEnabled") } }
    /// Finestra «Scopri» (top album, simili) da Last.fm.
    var discoverEnabled: Bool { didSet { save(discoverEnabled, "discoverEnabled") } }
    /// Cursore del volume di sistema nel popover.
    var showsSystemVolume: Bool { didSet { save(showsSystemVolume, "showsSystemVolume") } }
    /// Scelta dell'uscita audio nel popover.
    var showsAudioOutput: Bool { didSet { save(showsAudioOutput, "showsAudioOutput") } }
    /// Volume interno di Musica e Spotify nel popover.
    var showsPlayerVolume: Bool { didSet { save(showsPlayerVolume, "showsPlayerVolume") } }
    /// Pulsante «Apri <player>» nel popover e nel menu.
    var showsOpenPlayer: Bool { didSet { save(showsOpenPlayer, "showsOpenPlayer") } }
    /// Stato dello scrobbling ed errori sotto i controlli.
    var showsScrobbleStatus: Bool { didSet { save(showsScrobbleStatus, "showsScrobbleStatus") } }
    /// Scorciatoie da tastiera globali.
    var hotkeysEnabled: Bool { didSet { save(hotkeysEnabled, "hotkeysEnabled") } }

    // MARK: Integrazioni (fase 5)

    /// Discord Rich Presence (spenta di default: serve Discord aperto e un'applicazione Discord).
    var discordEnabled: Bool { didSet { save(discordEnabled, "discordEnabled") } }
    /// ID dell'applicazione Discord personale (vuoto = quella del progetto, se presente nella build).
    var discordApplicationID: String { didSet { save(discordApplicationID, "discordApplicationID") } }
    /// Comandi via URL `opentunes://…` (CLI, Raycast, Alfred, BetterTouchTool, Keyboard Maestro).
    var urlCommandsEnabled: Bool { didSet { save(urlCommandsEnabled, "urlCommandsEnabled") } }
    /// Comandi Rapidi, Siri e Spotlight (App Intents).
    var appIntentsEnabled: Bool { didSet { save(appIntentsEnabled, "appIntentsEnabled") } }
    /// Statistiche di ascolto locali (dal database della cronologia, senza Last.fm).
    var statisticsEnabled: Bool { didSet { save(statisticsEnabled, "statisticsEnabled") } }
    /// Controllo da MIDI (note e Control Change verso play/pausa, successivo, precedente).
    var midiEnabled: Bool { didSet { save(midiEnabled, "midiEnabled") } }
    /// Nota MIDI per ogni azione (la prima nota premuta in modalità «impara» si salva qui).
    var midiMappings: [String: Int] { didSet { save(midiMappings, "midiMappings") } }

    // MARK: Testi e condivisione

    /// Cerca i testi su LRCLIB quando una superficie li mostra.
    var lyricsEnabled: Bool { didSet { save(lyricsEnabled, "lyricsEnabled") } }
    /// Riga del testo sotto il titolo nel notch aperto.
    var notchShowsLyrics: Bool { didSet { save(notchShowsLyrics, "notchShowsLyrics") } }

    // MARK: Menu bar

    /// Ordine degli elementi in menu bar (tutti presenti, anche se disattivati).
    var menuBarOrder: [MenuBarElement] { didSet { save(menuBarOrder.map(\.rawValue), "menuBarOrder") } }
    var menuBarHidden: Set<MenuBarElement> { didSet { save(menuBarHidden.map(\.rawValue), "menuBarHidden") } }
    var titleTemplate: String { didSet { save(titleTemplate, "titleTemplate") } }
    var maxTitleWidth: Double { didSet { save(maxTitleWidth, "maxTitleWidth") } }
    var scrollsTitle: Bool { didSet { save(scrollsTitle, "scrollsTitle") } }
    var separateControlsItem: Bool { didSet { save(separateControlsItem, "separateControlsItem") } }
    var hidesWhenIdle: Bool { didSet { save(hidesWhenIdle, "hidesWhenIdle") } }
    var autoCompact: Bool { didSet { save(autoCompact, "autoCompact") } }
    var leftClick: MouseAction { didSet { save(leftClick.rawValue, "leftClick") } }
    var middleClick: MouseAction { didSet { save(middleClick.rawValue, "middleClick") } }
    var rightClick: MouseAction { didSet { save(rightClick.rawValue, "rightClick") } }
    var scrollAction: ScrollAction { didSet { save(scrollAction.rawValue, "scrollAction") } }

    // MARK: Finestra flottante e HUD

    var floatingVisible: Bool { didSet { save(floatingVisible, "floatingVisible") } }
    var floatingSize: FloatingSize { didSet { save(floatingSize.rawValue, "floatingSize") } }
    var floatingHidesInFullScreen: Bool { didSet { save(floatingHidesInFullScreen, "floatingHidesInFullScreen") } }
    var hudOnTrackChange: Bool { didSet { save(hudOnTrackChange, "hudOnTrackChange") } }
    var hudOnVolumeChange: Bool { didSet { save(hudOnVolumeChange, "hudOnVolumeChange") } }
    var hudPosition: HUDPosition { didSet { save(hudPosition.rawValue, "hudPosition") } }

    // MARK: Widget sulla scrivania, notch e Dock

    var desktopWidgetVisible: Bool { didSet { save(desktopWidgetVisible, "desktopWidgetVisible") } }
    var desktopWidgetLayout: DesktopWidgetLayout { didSet { save(desktopWidgetLayout.rawValue, "desktopWidgetLayout") } }
    /// Bloccato: non si sposta né si ridimensiona.
    var desktopWidgetLocked: Bool { didSet { save(desktopWidgetLocked, "desktopWidgetLocked") } }
    /// Grafico dei top artisti Last.fm sotto i controlli.
    var desktopWidgetShowsChart: Bool { didSet { save(desktopWidgetShowsChart, "desktopWidgetShowsChart") } }
    var notchEnabled: Bool { didSet { save(notchEnabled, "notchEnabled") } }
    /// Si apre passando sopra il notch (altrimenti solo con un clic).
    var notchOpensOnHover: Bool { didSet { save(notchOpensOnHover, "notchOpensOnHover") } }
    /// Al cambio brano il notch mostra per qualche secondo il titolo.
    var notchPeeksOnTrackChange: Bool { didSet { save(notchPeeksOnTrackChange, "notchPeeksOnTrackChange") } }
    /// Copertina come icona del Dock (l'app compare nel Dock).
    var dockShowsArtwork: Bool { didSet { save(dockShowsArtwork, "dockShowsArtwork") } }

    // MARK: Notifiche

    var notificationMode: NotificationMode { didSet { save(notificationMode.rawValue, "notificationMode") } }

    // MARK: Altro

    var ignoredBundleIDs: [String] { didSet { save(ignoredBundleIDs, "ignoredBundleIDs") } }
    var normalizesBrowserTitles: Bool { didSet { save(normalizesBrowserTitles, "normalizesBrowserTitles") } }
    var looksUpMissingArtwork: Bool { didSet { save(looksUpMissingArtwork, "looksUpMissingArtwork") } }

    // MARK: Scrobbling

    var lastFMEnabled: Bool { didSet { save(lastFMEnabled, "lastFMEnabled") } }
    var listenBrainzEnabled: Bool { didSet { save(listenBrainzEnabled, "listenBrainzEnabled") } }
    /// Server compatibile con ListenBrainz (Maloja, istanza propria); vuoto = listenbrainz.org.
    var listenBrainzServer: String { didSet { save(listenBrainzServer, "listenBrainzServer") } }
    /// Chiave personale Last.fm (la secret sta nel Portachiavi).
    var lastFMUsesCustomKey: Bool { didSet { save(lastFMUsesCustomKey, "lastFMUsesCustomKey") } }
    var lastFMCustomAPIKey: String { didSet { save(lastFMCustomAPIKey, "lastFMCustomAPIKey") } }
    /// Percentuale del brano da ascoltare (50 = regola di Last.fm).
    var scrobblePercent: Double { didSet { save(scrobblePercent, "scrobblePercent") } }
    /// Tetto dei 4 minuti.
    var scrobbleCapsAtFourMinutes: Bool { didSet { save(scrobbleCapsAtFourMinutes, "scrobbleCapsAtFourMinutes") } }
    /// Player esclusi dallo scrobbling (per default i browser: i video di YouTube non sono musica).
    var scrobbleExcludedBundleIDs: [String] { didSet { save(scrobbleExcludedBundleIDs, "scrobbleExcludedBundleIDs") } }
    /// Player visti finora, per scegliere nelle impostazioni quali possono fare scrobbling.
    var seenPlayerBundleIDs: [String] { didSet { save(seenPlayerBundleIDs, "seenPlayerBundleIDs") } }
    var cleansRemaster: Bool { didSet { save(cleansRemaster, "cleansRemaster") } }
    var cleansVersionTags: Bool { didSet { save(cleansVersionTags, "cleansVersionTags") } }
    var cleansVideoTags: Bool { didSet { save(cleansVideoTags, "cleansVideoTags") } }
    var cleansFeaturing: Bool { didSet { save(cleansFeaturing, "cleansFeaturing") } }
    var fixesAlbumArtist: Bool { didSet { save(fixesAlbumArtist, "fixesAlbumArtist") } }
    /// Il love su Last.fm imposta anche il preferito in Musica (e viceversa dal pulsante).
    var syncsLoveWithMusic: Bool { didSet { save(syncsLoveWithMusic, "syncsLoveWithMusic") } }
    /// Indicatore in menu bar quando ci sono ascolti in coda.
    var showsQueueIndicator: Bool { didSet { save(showsQueueIndicator, "showsQueueIndicator") } }

    init(defaults: UserDefaults = .standard, persists: Bool = true) {
        self.defaults = defaults
        self.persists = persists
        let order = (defaults.stringArray(forKey: "menuBarOrder") ?? []).compactMap(MenuBarElement.init(rawValue:))
        // Gli elementi mancanti (es. aggiunti in una versione nuova) vanno in coda; alcuni partono nascosti.
        let added = MenuBarElement.allCases.filter { !order.contains($0) }
        menuBarOrder = order + added
        let savedHidden = (defaults.stringArray(forKey: "menuBarHidden") ?? []).compactMap(MenuBarElement.init(rawValue:))
        menuBarHidden = Set(savedHidden).union(MenuBarElement.hiddenByDefault.intersection(added))
        titleTemplate = defaults.string(forKey: "titleTemplate") ?? "{artist} — {title}"
        maxTitleWidth = defaults.object(forKey: "maxTitleWidth") as? Double ?? 180
        scrollsTitle = defaults.object(forKey: "scrollsTitle") as? Bool ?? true
        separateControlsItem = defaults.bool(forKey: "separateControlsItem")
        hidesWhenIdle = defaults.bool(forKey: "hidesWhenIdle")
        autoCompact = defaults.object(forKey: "autoCompact") as? Bool ?? true
        leftClick = Self.value(defaults, "leftClick") ?? .openPopover
        middleClick = Self.value(defaults, "middleClick") ?? .playPause
        rightClick = Self.value(defaults, "rightClick") ?? .quickMenu
        scrollAction = Self.value(defaults, "scrollAction") ?? .volume

        menuBarEnabled = defaults.object(forKey: "menuBarEnabled") as? Bool ?? true
        floatingEnabled = defaults.object(forKey: "floatingEnabled") as? Bool ?? true
        systemWidgetEnabled = defaults.object(forKey: "systemWidgetEnabled") as? Bool ?? true
        // Prima della fase 4 c'era solo «Colora con la tinta della copertina»: spenta equivale al tema monocromo.
        theme = Self.value(defaults, "theme")
            ?? ((defaults.object(forKey: "tintsWithArtwork") as? Bool ?? true) ? .artwork : .monochrome)
        visualizerEnabled = defaults.object(forKey: "visualizerEnabled") as? Bool ?? true
        let savedTheme = defaults.string(forKey: "customThemeJSON") ?? ""
        customThemeJSON = savedTheme
        if let data = savedTheme.data(using: .utf8), let custom = try? CustomTheme.decode(data) {
            CustomTheme.active = custom
        }
        visualizerUsesAudio = defaults.object(forKey: "visualizerUsesAudio") as? Bool ?? true
        lyricsEnabled = defaults.object(forKey: "lyricsEnabled") as? Bool ?? true
        func flag(_ key: String, _ fallback: Bool = true) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        showsRecentTracks = flag("showsRecentTracks")
        showsLastFMProfile = flag("showsLastFMProfile")
        loveEnabled = flag("loveEnabled")
        musicActionsEnabled = flag("musicActionsEnabled")
        switchPlayerEnabled = flag("switchPlayerEnabled")
        shareLinksEnabled = flag("shareLinksEnabled")
        discoverEnabled = flag("discoverEnabled")
        showsSystemVolume = flag("showsSystemVolume")
        showsAudioOutput = flag("showsAudioOutput")
        showsPlayerVolume = flag("showsPlayerVolume")
        showsOpenPlayer = flag("showsOpenPlayer")
        showsScrobbleStatus = flag("showsScrobbleStatus")
        hotkeysEnabled = flag("hotkeysEnabled")
        discordEnabled = flag("discordEnabled", false)
        discordApplicationID = defaults.string(forKey: "discordApplicationID") ?? ""
        urlCommandsEnabled = flag("urlCommandsEnabled")
        appIntentsEnabled = flag("appIntentsEnabled")
        statisticsEnabled = flag("statisticsEnabled")
        midiEnabled = flag("midiEnabled", false)
        midiMappings = defaults.dictionary(forKey: "midiMappings") as? [String: Int] ?? [:]
        notchShowsLyrics = defaults.object(forKey: "notchShowsLyrics") as? Bool ?? true

        floatingVisible = defaults.bool(forKey: "floatingVisible")
        floatingSize = Self.value(defaults, "floatingSize") ?? .large
        floatingHidesInFullScreen = defaults.object(forKey: "floatingHidesInFullScreen") as? Bool ?? true
        // HUD e notifiche al cambio brano sono opzionali: spenti finché l'utente non li attiva.
        hudOnTrackChange = defaults.object(forKey: "hudOnTrackChange") as? Bool ?? false
        hudOnVolumeChange = defaults.object(forKey: "hudOnVolumeChange") as? Bool ?? true
        hudPosition = Self.value(defaults, "hudPosition") ?? .bottom

        desktopWidgetVisible = defaults.bool(forKey: "desktopWidgetVisible")
        desktopWidgetLayout = Self.value(defaults, "desktopWidgetLayout") ?? .card
        desktopWidgetLocked = defaults.bool(forKey: "desktopWidgetLocked")
        desktopWidgetShowsChart = defaults.bool(forKey: "desktopWidgetShowsChart")
        notchEnabled = defaults.object(forKey: "notchEnabled") as? Bool ?? true
        notchOpensOnHover = defaults.object(forKey: "notchOpensOnHover") as? Bool ?? true
        notchPeeksOnTrackChange = defaults.object(forKey: "notchPeeksOnTrackChange") as? Bool ?? true
        dockShowsArtwork = defaults.bool(forKey: "dockShowsArtwork")

        notificationMode = Self.value(defaults, "notificationMode") ?? .off

        ignoredBundleIDs = defaults.stringArray(forKey: "ignoredBundleIDs") ?? ["us.zoom.xos"]
        normalizesBrowserTitles = defaults.object(forKey: "normalizesBrowserTitles") as? Bool ?? true
        looksUpMissingArtwork = defaults.object(forKey: "looksUpMissingArtwork") as? Bool ?? true

        lastFMEnabled = defaults.object(forKey: "lastFMEnabled") as? Bool ?? true
        listenBrainzEnabled = defaults.object(forKey: "listenBrainzEnabled") as? Bool ?? true
        listenBrainzServer = defaults.string(forKey: "listenBrainzServer") ?? ""
        lastFMUsesCustomKey = defaults.bool(forKey: "lastFMUsesCustomKey")
        lastFMCustomAPIKey = defaults.string(forKey: "lastFMCustomAPIKey") ?? ""
        scrobblePercent = defaults.object(forKey: "scrobblePercent") as? Double ?? 50
        scrobbleCapsAtFourMinutes = defaults.object(forKey: "scrobbleCapsAtFourMinutes") as? Bool ?? true
        scrobbleExcludedBundleIDs = defaults.stringArray(forKey: "scrobbleExcludedBundleIDs")
            ?? PlayerApp.browserBundleIDs.sorted()
        seenPlayerBundleIDs = defaults.stringArray(forKey: "seenPlayerBundleIDs") ?? []
        cleansRemaster = defaults.object(forKey: "cleansRemaster") as? Bool ?? true
        cleansVersionTags = defaults.object(forKey: "cleansVersionTags") as? Bool ?? true
        cleansVideoTags = defaults.object(forKey: "cleansVideoTags") as? Bool ?? true
        cleansFeaturing = defaults.bool(forKey: "cleansFeaturing")
        fixesAlbumArtist = defaults.object(forKey: "fixesAlbumArtist") as? Bool ?? true
        syncsLoveWithMusic = defaults.object(forKey: "syncsLoveWithMusic") as? Bool ?? true
        showsQueueIndicator = defaults.object(forKey: "showsQueueIndicator") as? Bool ?? true
    }

    /// Importa un tema JSON (validato) e lo attiva.
    func importTheme(_ data: Data) throws {
        let custom = try CustomTheme.decode(data)
        CustomTheme.active = custom
        customThemeJSON = String(decoding: try custom.encoded(), as: UTF8.self)
        // Riassegnare il tema avvisa le superfici anche se era già «Personalizzato».
        theme = .custom
    }

    /// La tinta della copertina si usa solo con il tema «Tinta dalla copertina».
    var tintsWithArtwork: Bool { theme.usesArtworkTint }

    func isEnabled(_ surface: Surface) -> Bool {
        switch surface {
        case .menuBar: menuBarEnabled
        case .notch: notchEnabled
        case .floating: floatingEnabled
        case .desktopWidget: desktopWidgetVisible
        case .systemWidget: systemWidgetEnabled
        }
    }

    func setEnabled(_ surface: Surface, _ enabled: Bool) {
        switch surface {
        case .menuBar: menuBarEnabled = enabled
        case .notch: notchEnabled = enabled
        case .floating:
            floatingEnabled = enabled
            if !enabled { floatingVisible = false }
        case .desktopWidget: desktopWidgetVisible = enabled
        case .systemWidget: systemWidgetEnabled = enabled
        }
    }

    /// La finestra flottante è sullo schermo: abilitata e mostrata.
    var showsFloatingWindow: Bool { floatingEnabled && floatingVisible }

    /// Superfici attive da cui si raggiunge il player (per avvisare se si spengono tutte).
    var hasInteractiveSurface: Bool { menuBarEnabled || notchEnabled || showsFloatingWindow || desktopWidgetVisible }

    /// Regole di scrobbling scelte dall'utente.
    var scrobbleRules: ScrobbleRules {
        ScrobbleRules(fraction: scrobblePercent / 100, maximumWait: scrobbleCapsAtFourMinutes ? 240 : nil)
    }

    var cleanerOptions: TitleCleaner.Options {
        TitleCleaner.Options(
            removesRemaster: cleansRemaster, removesVersionTags: cleansVersionTags, removesVideoTags: cleansVideoTags,
            removesFeaturing: cleansFeaturing, fixesAlbumArtist: fixesAlbumArtist)
    }

    func scrobbles(_ bundleID: String) -> Bool { !scrobbleExcludedBundleIDs.contains(bundleID) }

    func setScrobbles(_ bundleID: String, _ enabled: Bool) {
        scrobbleExcludedBundleIDs.removeAll { $0 == bundleID }
        if !enabled { scrobbleExcludedBundleIDs.append(bundleID) }
    }

    var titleFormat: TitleFormat { TitleFormat(titleTemplate) }

    /// Elementi visibili, nell'ordine scelto.
    var visibleMenuBarElements: [MenuBarElement] {
        menuBarOrder.filter { !menuBarHidden.contains($0) }
    }

    func isVisible(_ element: MenuBarElement) -> Bool { !menuBarHidden.contains(element) }

    func setVisible(_ element: MenuBarElement, _ visible: Bool) {
        if visible { menuBarHidden.remove(element) } else { menuBarHidden.insert(element) }
    }

    private func save(_ value: Any, _ key: String) {
        guard persists else { return }
        defaults.set(value, forKey: key)
    }

    private static func value<T: RawRepresentable>(_ defaults: UserDefaults, _ key: String) -> T? where T.RawValue == String {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return T(rawValue: raw)
    }
}

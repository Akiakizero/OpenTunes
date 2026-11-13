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
        case .artwork: "Copertina"
        case .title: "Titolo e artista"
        case .controls: "Pulsanti"
        case .love: "Love (Last.fm / Musica)"
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
        case .openPopover: "Apri il player"
        case .playPause: "Play/pausa"
        case .nextTrack: "Brano successivo"
        case .previousTrack: "Brano precedente"
        case .quickMenu: "Menu rapido"
        case .toggleFloatingWindow: "Mostra/nascondi finestra flottante"
        case .love: "Love"
        case .none: "Niente"
        }
    }
}

/// Cosa fa la rotella sopra l'elemento in menu bar.
enum ScrollAction: String, CaseIterable, Identifiable, Sendable {
    case volume, seek, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .volume: "Volume"
        case .seek: "Avanti/indietro nel brano"
        case .none: "Niente"
        }
    }
}

enum FloatingSize: String, CaseIterable, Identifiable, Sendable {
    case compact, large

    var id: String { rawValue }
    var label: String { self == .compact ? "Compatta" : "Grande" }
}

/// Layout del widget live sulla scrivania.
enum DesktopWidgetLayout: String, CaseIterable, Identifiable, Sendable {
    case card, horizontal, artwork

    var id: String { rawValue }

    var label: String {
        switch self {
        case .card: "Scheda (copertina sopra)"
        case .horizontal: "Orizzontale"
        case .artwork: "Solo copertina"
        }
    }
}

enum NotificationMode: String, CaseIterable, Identifiable, Sendable {
    case off, always, whenFloatingHidden

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Mai"
        case .always: "Sempre"
        case .whenFloatingHidden: "Solo se la finestra flottante è nascosta"
        }
    }
}

enum HUDPosition: String, CaseIterable, Identifiable, Sendable {
    case bottom, center, topRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bottom: "In basso al centro"
        case .center: "Al centro"
        case .topRight: "In alto a destra"
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
    var tintsWithArtwork: Bool { didSet { save(tintsWithArtwork, "tintsWithArtwork") } }
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

        floatingVisible = defaults.bool(forKey: "floatingVisible")
        floatingSize = Self.value(defaults, "floatingSize") ?? .large
        floatingHidesInFullScreen = defaults.object(forKey: "floatingHidesInFullScreen") as? Bool ?? true
        tintsWithArtwork = defaults.object(forKey: "tintsWithArtwork") as? Bool ?? true
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

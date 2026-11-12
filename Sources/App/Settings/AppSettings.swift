// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation

/// Elementi della menu bar, riordinabili.
enum MenuBarElement: String, CaseIterable, Codable, Identifiable, Sendable {
    case artwork, title, controls

    var id: String { rawValue }

    var label: String {
        switch self {
        case .artwork: "Copertina"
        case .title: "Titolo e artista"
        case .controls: "Pulsanti"
        }
    }
}

/// Cosa fa un clic sull'elemento in menu bar.
enum MouseAction: String, CaseIterable, Identifiable, Sendable {
    case openPopover, playPause, nextTrack, previousTrack, quickMenu, toggleFloatingWindow, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openPopover: "Apri il player"
        case .playPause: "Play/pausa"
        case .nextTrack: "Brano successivo"
        case .previousTrack: "Brano precedente"
        case .quickMenu: "Menu rapido"
        case .toggleFloatingWindow: "Mostra/nascondi finestra flottante"
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

    // MARK: Notifiche

    var notificationMode: NotificationMode { didSet { save(notificationMode.rawValue, "notificationMode") } }

    // MARK: Altro

    var ignoredBundleIDs: [String] { didSet { save(ignoredBundleIDs, "ignoredBundleIDs") } }
    var normalizesBrowserTitles: Bool { didSet { save(normalizesBrowserTitles, "normalizesBrowserTitles") } }
    var looksUpMissingArtwork: Bool { didSet { save(looksUpMissingArtwork, "looksUpMissingArtwork") } }

    init(defaults: UserDefaults = .standard, persists: Bool = true) {
        self.defaults = defaults
        self.persists = persists
        let order = (defaults.stringArray(forKey: "menuBarOrder") ?? []).compactMap(MenuBarElement.init(rawValue:))
        // Gli elementi mancanti (es. aggiunti in una versione nuova) vanno in coda.
        menuBarOrder = order + MenuBarElement.allCases.filter { !order.contains($0) }
        menuBarHidden = Set((defaults.stringArray(forKey: "menuBarHidden") ?? []).compactMap(MenuBarElement.init(rawValue:)))
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

        notificationMode = Self.value(defaults, "notificationMode") ?? .off

        ignoredBundleIDs = defaults.stringArray(forKey: "ignoredBundleIDs") ?? ["us.zoom.xos"]
        normalizesBrowserTitles = defaults.object(forKey: "normalizesBrowserTitles") as? Bool ?? true
        looksUpMissingArtwork = defaults.object(forKey: "looksUpMissingArtwork") as? Bool ?? true
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

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Un'app che riproduce media.
public struct PlayerApp: Sendable, Hashable, Identifiable {
    public struct Capabilities: OptionSet, Sendable, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let like = Capabilities(rawValue: 1 << 0)
        public static let rating = Capabilities(rawValue: 1 << 1)
        public static let addToLibrary = Capabilities(rawValue: 1 << 2)
        /// Controllabile via AppleScript (fallback senza adapter).
        public static let appleScript = Capabilities(rawValue: 1 << 3)
    }

    public var id: String { bundleID }
    public let bundleID: String
    public let name: String
    public let capabilities: Capabilities

    public init(bundleID: String, name: String, capabilities: Capabilities = []) {
        self.bundleID = bundleID
        self.name = name
        self.capabilities = capabilities
    }

    /// Icona dell'app installata, se presente.
    @MainActor public var icon: NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    public var isBrowser: Bool { Self.browserBundleIDs.contains(bundleID) }

    public static let appleMusic = PlayerApp(
        bundleID: "com.apple.Music", name: "Musica",
        capabilities: [.like, .rating, .addToLibrary, .appleScript])
    public static let spotify = PlayerApp(
        bundleID: "com.spotify.client", name: "Spotify",
        capabilities: [.appleScript])
    public static let tidal = PlayerApp(bundleID: "com.tidal.desktop", name: "TIDAL")
    public static let safari = PlayerApp(bundleID: "com.apple.Safari", name: "Safari")
    public static let chrome = PlayerApp(bundleID: "com.google.Chrome", name: "Google Chrome")

    public static let known: [PlayerApp] = [appleMusic, spotify, tidal, safari, chrome]

    public static let browserBundleIDs: Set<String> = [
        "com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.google.Chrome",
        "com.google.Chrome.canary", "org.mozilla.firefox", "com.microsoft.edgemac",
        "com.brave.Browser", "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
    ]

    /// Restituisce l'app nota o ne costruisce una dal bundle installato.
    public static func resolve(bundleID: String) -> PlayerApp {
        if let app = known.first(where: { $0.bundleID == bundleID }) { return app }
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .flatMap { Bundle(url: $0) }
            .flatMap {
                ($0.object(forInfoDictionaryKey: "CFBundleDisplayName")
                    ?? $0.object(forInfoDictionaryKey: "CFBundleName")) as? String
            }
        return PlayerApp(bundleID: bundleID, name: name ?? bundleID)
    }
}

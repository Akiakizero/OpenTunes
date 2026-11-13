// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Comandi `opentunes://<comando>` per la riga di comando (`opentunes next`), Raycast, Alfred, BetterTouchTool,
/// Keyboard Maestro o un semplice `open opentunes://next`.
///
/// `opentunes://player` (clic sul widget) apre sempre il player; gli altri si possono spegnere nelle impostazioni
/// (Funzioni › «Comandi via URL e riga di comando»).
enum URLCommand: Equatable, Sendable {
    case player
    case playPause, play, pause, next, previous
    case love
    case copyLink
    case lyrics
    case floating
    case discover
    case statistics
    case settings
    /// Volume di sistema 0…100.
    case volume(Int)
    /// Salto nel brano, in secondi (negativo = indietro).
    case seek(Int)

    /// Comandi accettati, per l'aiuto della CLI e della documentazione.
    static let names = [
        "player", "play-pause", "play", "pause", "next", "previous", "love", "copy-link", "lyrics", "floating",
        "discover", "stats", "settings", "volume?level=0…100", "seek?by=±secondi",
    ]

    init?(url: URL) {
        guard url.scheme?.lowercased() == "opentunes" else { return nil }
        // `opentunes://next` ha il comando nell'host; `opentunes:next` o `opentunes:///next` nel percorso.
        let name = (url.host() ?? url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func number(_ key: String) -> Int? { query.first { $0.name == key }?.value.flatMap { Int($0) } }
        switch name {
        case "", "player", "open": self = .player
        case "play-pause", "playpause", "toggle": self = .playPause
        case "play": self = .play
        case "pause": self = .pause
        case "next", "skip": self = .next
        case "previous", "prev", "back": self = .previous
        case "love", "like": self = .love
        case "copy-link", "link", "share": self = .copyLink
        case "lyrics": self = .lyrics
        case "floating", "window": self = .floating
        case "discover": self = .discover
        case "stats", "statistics": self = .statistics
        case "settings", "preferences": self = .settings
        case "volume":
            guard let level = number("level") ?? number("value") else { return nil }
            self = .volume(min(100, max(0, level)))
        case "seek":
            guard let seconds = number("by") ?? number("seconds") else { return nil }
            self = .seek(seconds)
        default: return nil
        }
    }

    /// `opentunes://player` resta attivo anche con i comandi spenti: è il clic sul widget.
    var isAlwaysAllowed: Bool { self == .player || self == .settings }
}

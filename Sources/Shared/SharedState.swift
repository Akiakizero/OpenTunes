// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Stato del brano che l'app scrive nell'App Group e il widget WidgetKit legge.
///
/// Compilato sia nell'app sia nell'estensione: non dipende da MediaCore (l'estensione non lo include).
struct WidgetState: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable, Identifiable {
        var id: String { "\(artist)\u{1F}\(title)" }
        var title: String
        var artist: String
    }

    struct Artist: Codable, Equatable, Sendable, Identifiable {
        var id: String { name }
        var name: String
        var playCount: Int
    }

    var title: String?
    var artist: String?
    var album: String?
    var playerName: String?
    var isPlaying = false
    /// Posizione in secondi al momento `timestamp` (come `PlaybackState`).
    var elapsedTime: TimeInterval = 0
    var timestamp = Date.now
    var duration: TimeInterval?
    /// Hash della copertina salvata accanto allo stato (`nil` = nessuna copertina).
    var artworkHash: String?
    /// Tinta della copertina in sRGB (0…1), se attiva.
    var tint: [Double]?
    var canLove = false
    var isLoved = false
    /// Utente Last.fm collegato (per la taglia grande).
    var lastFMUser: String?
    var recentTracks: [Entry] = []
    var topArtists: [Artist] = []

    var hasTrack: Bool { title != nil }

    /// Intervallo per `ProgressView(timerInterval:)`: il widget mostra l'avanzamento senza ricaricarsi.
    var playbackInterval: ClosedRange<Date>? {
        guard let duration, duration > 0 else { return nil }
        let start = timestamp.addingTimeInterval(-elapsedTime)
        return start...start.addingTimeInterval(duration)
    }

    /// Frazione ascoltata all'istante `date` (per lo stato in pausa).
    func fraction(at date: Date = .now) -> Double {
        guard let duration, duration > 0 else { return 0 }
        let position = isPlaying ? elapsedTime + max(0, date.timeIntervalSince(timestamp)) : elapsedTime
        return max(0, min(1, position / duration))
    }

    static let empty = WidgetState()
}

/// Cartella dell'App Group condivisa da app e widget.
enum SharedContainer {
    /// Identificatore dell'App Group, dall'Info.plist (impostato in `project.yml`).
    static var groupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "OpenTunesAppGroup") as? String
    }

    static var url: URL? {
        guard let groupID, !groupID.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    static var stateURL: URL? { url?.appending(path: "widget-state.json") }
    static var artworkURL: URL? { url?.appending(path: "widget-artwork.png") }

    static func readState() -> WidgetState {
        guard let stateURL, let data = try? Data(contentsOf: stateURL),
            let state = try? JSONDecoder().decode(WidgetState.self, from: data)
        else { return .empty }
        return state
    }

    static func readArtwork() -> Data? {
        artworkURL.flatMap { try? Data(contentsOf: $0) }
    }
}

/// Identificatori dei widget WidgetKit.
enum WidgetKind {
    static let nowPlaying = "org.opentunes.widget.nowPlaying"
}

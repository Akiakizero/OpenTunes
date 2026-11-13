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
    /// `true` se l'utente ha spento i widget nelle impostazioni (opzionale: gli stati salvati prima non lo hanno).
    var isDisabled: Bool?

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

    /// Stato scritto quando l'utente spegne i widget: nessun dato del brano.
    static var disabled: WidgetState {
        var state = WidgetState()
        state.isDisabled = true
        return state
    }
}

/// Cartella condivisa da app e widget.
///
/// Con una build firmata con un Team ID è l'App Group (`<TEAM>.org.opentunes.shared`). Con la firma ad-hoc l'App Group
/// non ha il prefisso del team e macOS non lo autorizza: il widget in sandbox non lo vede (e l'app riceverebbe la richiesta
/// «accedere ai dati di altre app»). In quel caso si usa `~/Library/Application Support/OpenTunes/Widget/`, che il widget
/// legge grazie all'eccezione di sola lettura `temporary-exception.files.home-relative-path.read-only` nei suoi entitlement.
enum SharedContainer {
    /// Identificatore dell'App Group, dall'Info.plist (impostato in `project.yml`).
    static var groupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "OpenTunesAppGroup") as? String
    }

    /// Nome dell'App Group senza prefisso del team: la build è ad-hoc.
    static let unprefixedGroupID = "org.opentunes.shared"

    /// Percorso della cartella di ripiego, relativo alla home (lo stesso negli entitlement del widget).
    static let fallbackRelativePath = "Library/Application Support/OpenTunes/Widget"

    static var usesAppGroup: Bool {
        guard let groupID, !groupID.isEmpty else { return false }
        return groupID != unprefixedGroupID
    }

    static var url: URL? {
        if usesAppGroup, let groupID,
            let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return url
        }
        return fallbackURL
    }

    /// Cartella nella home reale dell'utente: in sandbox `NSHomeDirectory()` è il container del widget.
    static var fallbackURL: URL? {
        guard let home = realHomeDirectory else { return nil }
        return URL(filePath: home, directoryHint: .isDirectory).appending(path: fallbackRelativePath, directoryHint: .isDirectory)
    }

    private static var realHomeDirectory: String? {
        guard let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir else { return nil }
        return String(cString: dir)
    }

    /// Crea la cartella se manca (solo l'app: il widget ha accesso in sola lettura).
    @discardableResult
    static func prepare() -> URL? {
        guard let url else { return nil }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
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

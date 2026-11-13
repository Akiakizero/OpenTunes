// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Un ascolto da inviare a Last.fm o ListenBrainz.
public struct ScrobbleTrack: Sendable, Equatable, Hashable, Codable {
    public var artist: String
    public var title: String
    public var album: String?
    public var albumArtist: String?
    public var duration: TimeInterval?
    /// Inizio dell'ascolto: è il timestamp richiesto da Last.fm e ListenBrainz.
    public var startedAt: Date
    public var playerBundleID: String

    public init(
        artist: String, title: String, album: String? = nil, albumArtist: String? = nil,
        duration: TimeInterval? = nil, startedAt: Date, playerBundleID: String
    ) {
        self.artist = artist
        self.title = title
        self.album = album
        self.albumArtist = albumArtist
        self.duration = duration
        self.startedAt = startedAt
        self.playerBundleID = playerBundleID
    }

    /// Chiave di deduplicazione: player + artista + titolo (senza maiuscole).
    var identity: String {
        [playerBundleID, artist, title].map { $0.lowercased() }.joined(separator: "\u{1F}")
    }
}

/// Quando un brano conta come ascoltato.
///
/// Regola standard di Last.fm (vista in web-scrobbler, MIT; scritta da zero): il brano deve durare
/// più di 30 s ed essere stato ascoltato per metà della durata o per 4 minuti, quello che arriva prima.
public struct ScrobbleRules: Sendable, Equatable {
    /// I brani più corti di così non si inviano mai.
    public var minimumDuration: TimeInterval
    /// Frazione della durata da ascoltare (0.5 = metà).
    public var fraction: Double
    /// Tetto all'attesa (240 s di Last.fm); `nil` = conta solo la frazione.
    public var maximumWait: TimeInterval?

    public init(minimumDuration: TimeInterval = 30, fraction: Double = 0.5, maximumWait: TimeInterval? = 240) {
        self.minimumDuration = minimumDuration
        self.fraction = fraction
        self.maximumWait = maximumWait
    }

    public static let lastFM = ScrobbleRules()

    /// Secondi di ascolto necessari, o `nil` se il brano non si può inviare (troppo corto).
    /// Senza durata nota si usa il tetto (o 240 s).
    public func threshold(duration: TimeInterval?) -> TimeInterval? {
        guard let duration, duration > 0 else { return maximumWait ?? 240 }
        guard duration > minimumDuration else { return nil }
        let byFraction = duration * min(1, max(0.05, fraction))
        guard let maximumWait else { return byFraction }
        return min(byFraction, maximumWait)
    }
}

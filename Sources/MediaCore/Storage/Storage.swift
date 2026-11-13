// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// Scrobble in attesa di invio (o già inviato, tenuto qualche giorno per la deduplicazione).
@Model
final class QueuedScrobble {
    var id: UUID
    var artist: String
    var title: String
    var album: String?
    var albumArtist: String?
    var duration: Double?
    var startedAt: Date
    var playerBundleID: String
    var pendingLastFM: Bool
    var pendingListenBrainz: Bool
    var attempts: Int
    var nextAttempt: Date
    var lastError: String?
    var createdAt: Date

    init(track: ScrobbleTrack, services: Set<ScrobbleServiceKind>, now: Date) {
        id = UUID()
        artist = track.artist
        title = track.title
        album = track.album
        albumArtist = track.albumArtist
        duration = track.duration
        startedAt = track.startedAt
        playerBundleID = track.playerBundleID
        pendingLastFM = services.contains(.lastFM)
        pendingListenBrainz = services.contains(.listenBrainz)
        attempts = 0
        nextAttempt = now
        createdAt = now
    }

    var track: ScrobbleTrack {
        ScrobbleTrack(
            artist: artist, title: title, album: album, albumArtist: albumArtist, duration: duration,
            startedAt: startedAt, playerBundleID: playerBundleID)
    }

    func isPending(_ service: ScrobbleServiceKind) -> Bool {
        switch service {
        case .lastFM: pendingLastFM
        case .listenBrainz: pendingListenBrainz
        }
    }

    func setPending(_ value: Bool, _ service: ScrobbleServiceKind) {
        switch service {
        case .lastFM: pendingLastFM = value
        case .listenBrainz: pendingListenBrainz = value
        }
    }
}

/// Un brano della cronologia "Ascoltati di recente".
@Model
final class HistoryEntry {
    var title: String
    var artist: String?
    var album: String?
    var albumArtist: String?
    var duration: Double?
    var playerBundleID: String
    var playedAt: Date
    /// Miniatura JPEG della copertina (non l'originale, per tenere piccolo il database).
    @Attribute(.externalStorage) var artwork: Data?

    init(track: Track, playedAt: Date, artwork: Data?) {
        title = track.title
        artist = track.artist
        album = track.album
        albumArtist = track.albumArtist
        duration = track.duration
        playerBundleID = track.playerBundleID
        self.playedAt = playedAt
        self.artwork = artwork
    }
}

/// Database SwiftData dell'app (coda degli scrobble e cronologia).
public enum Storage {
    static let schema = Schema([QueuedScrobble.self, HistoryEntry.self])

    /// `inMemory` per test e anteprime; altrimenti `~/Library/Application Support/OpenTunes/OpenTunes.store`.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
        let folder = URL.applicationSupportDirectory.appending(path: "OpenTunes", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(schema: schema, url: folder.appending(path: "OpenTunes.store"))
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

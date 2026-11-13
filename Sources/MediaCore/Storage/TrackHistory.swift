// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

/// Una voce della cronologia salvata.
public struct StoredPlay: Sendable, Equatable {
    public var track: Track
    public var playedAt: Date

    public init(track: Track, playedAt: Date) {
        self.track = track
        self.playedAt = playedAt
    }
}

/// Dove `NowPlayingStore` salva la cronologia dei brani ascoltati.
public protocol HistoryPersistence: Sendable {
    func load(limit: Int) async -> [StoredPlay]
    /// Nuovo brano (o copertina arrivata dopo il titolo: stessa data, si aggiorna la voce).
    func record(_ play: StoredPlay) async
    func clear() async
}

/// Cronologia in SwiftData, con miniature delle copertine.
public actor TrackHistory: ModelActor, HistoryPersistence {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    /// Voci tenute nel database (bastano per le statistiche di un anno di ascolti medi).
    let maxEntries: Int
    /// Solo le voci più recenti tengono la miniatura della copertina; le altre servono alle statistiche.
    let artworkEntries: Int

    public init(modelContainer: ModelContainer, maxEntries: Int = 10_000, artworkEntries: Int = 500) {
        self.modelContainer = modelContainer
        self.maxEntries = maxEntries
        self.artworkEntries = artworkEntries
        modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
    }

    public func load(limit: Int) async -> [StoredPlay] {
        var descriptor = FetchDescriptor<HistoryEntry>(sortBy: [SortDescriptor(\.playedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        return entries.map { entry in
            StoredPlay(
                track: Track(
                    title: entry.title, artist: entry.artist, album: entry.album, albumArtist: entry.albumArtist,
                    duration: entry.duration, artworkData: entry.artwork, playerBundleID: entry.playerBundleID),
                playedAt: entry.playedAt)
        }
    }

    public func record(_ play: StoredPlay) async {
        let track = play.track
        let date = play.playedAt
        let thumbnail = track.artworkData.flatMap { Self.thumbnail($0) }
        let title = track.title, player = track.playerBundleID
        let existing = try? modelContext.fetch(FetchDescriptor<HistoryEntry>(predicate: #Predicate {
            $0.playedAt == date && $0.title == title && $0.playerBundleID == player
        })).first
        if let existing {
            existing.artwork = thumbnail ?? existing.artwork
        } else {
            modelContext.insert(HistoryEntry(track: track, playedAt: date, artwork: thumbnail))
        }
        try? modelContext.save()
        prune()
    }

    /// Ascolti da `date` in poi, senza copertine (per le statistiche locali).
    public func plays(since date: Date) async -> [StoredPlay] {
        let descriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.playedAt >= date }, sortBy: [SortDescriptor(\.playedAt, order: .reverse)])
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        return entries.map { entry in
            StoredPlay(
                track: Track(
                    title: entry.title, artist: entry.artist, album: entry.album, albumArtist: entry.albumArtist,
                    duration: entry.duration, artworkData: nil, playerBundleID: entry.playerBundleID),
                playedAt: entry.playedAt)
        }
    }

    public func clear() async {
        try? modelContext.delete(model: HistoryEntry.self)
        try? modelContext.save()
    }

    private func prune() {
        let count = (try? modelContext.fetchCount(FetchDescriptor<HistoryEntry>())) ?? 0
        if count > artworkEntries {
            // La miniatura della voce appena uscita dalle più recenti non serve più.
            var old = FetchDescriptor<HistoryEntry>(sortBy: [SortDescriptor(\.playedAt, order: .reverse)])
            old.fetchOffset = artworkEntries
            old.fetchLimit = 20
            for entry in (try? modelContext.fetch(old)) ?? [] where entry.artwork != nil { entry.artwork = nil }
            try? modelContext.save()
        }
        guard count > maxEntries else { return }
        var descriptor = FetchDescriptor<HistoryEntry>(sortBy: [SortDescriptor(\.playedAt)])
        descriptor.fetchLimit = count - maxEntries
        for entry in (try? modelContext.fetch(descriptor)) ?? [] { modelContext.delete(entry) }
        try? modelContext.save()
    }

    /// Miniatura JPEG di 128 px (ImageIO è sicuro fuori dal main thread).
    static func thumbnail(_ data: Data, maxPixels: Int = 128) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixels,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ] as CFDictionary)
        else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// Servizi di scrobbling supportati.
public enum ScrobbleServiceKind: String, Sendable, CaseIterable, Codable {
    case lastFM, listenBrainz

    public var displayName: String {
        switch self {
        case .lastFM: "Last.fm"
        case .listenBrainz: "ListenBrainz"
        }
    }
}

/// Coda persistente degli scrobble: ogni ascolto si salva **prima** dell'invio e resta finché
/// tutti i servizi attivi l'hanno accettato. Gli errori temporanei riprovano con attesa crescente.
/// Gli scrobble inviati restano qualche giorno per riconoscere i duplicati, poi si cancellano.
public actor ScrobbleQueue: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
    }

    public struct Item: Sendable, Identifiable, Equatable {
        public let id: UUID
        public let track: ScrobbleTrack
        public let attempts: Int
    }

    /// Stesso brano dello stesso player con inizio entro questa distanza = stesso ascolto.
    static let duplicateWindow: TimeInterval = 30
    /// Per quanto si tengono gli scrobble già inviati.
    static let keepSent: TimeInterval = 7 * 24 * 3600

    /// Attesa prima del tentativo successivo: 30 s, 1, 2, 4… minuti, al massimo un'ora.
    public static func backoff(attempts: Int) -> TimeInterval {
        min(3600, 30 * pow(2, Double(max(0, attempts - 1))))
    }

    /// Aggiunge un ascolto. Restituisce `false` se era già in coda (o già inviato).
    @discardableResult
    public func enqueue(_ track: ScrobbleTrack, services: Set<ScrobbleServiceKind>, now: Date = .now) throws -> Bool {
        guard !services.isEmpty else { return false }
        let artist = track.artist, title = track.title, player = track.playerBundleID
        let from = track.startedAt.addingTimeInterval(-Self.duplicateWindow)
        let to = track.startedAt.addingTimeInterval(Self.duplicateWindow)
        let duplicates = try modelContext.fetchCount(FetchDescriptor<QueuedScrobble>(predicate: #Predicate {
            $0.artist == artist && $0.title == title && $0.playerBundleID == player && $0.startedAt >= from && $0.startedAt <= to
        }))
        guard duplicates == 0 else { return false }
        modelContext.insert(QueuedScrobble(track: track, services: services, now: now))
        try modelContext.save()
        return true
    }

    /// Fino a `limit` scrobble pronti per `service`, dal più vecchio.
    public func due(for service: ScrobbleServiceKind, limit: Int, now: Date = .now) throws -> [Item] {
        try pending(service).filter { $0.nextAttempt <= now }.prefix(limit)
            .map { Item(id: $0.id, track: $0.track, attempts: $0.attempts) }
    }

    public func markSent(_ ids: [UUID], for service: ScrobbleServiceKind) throws {
        for entry in try entries(ids) {
            entry.setPending(false, service)
            entry.lastError = nil
        }
        try modelContext.save()
    }

    /// Errore temporaneo: si riprova più tardi.
    public func markFailed(_ ids: [UUID], for service: ScrobbleServiceKind, error: String, now: Date = .now) throws {
        for entry in try entries(ids) {
            entry.attempts += 1
            entry.nextAttempt = now.addingTimeInterval(Self.backoff(attempts: entry.attempts))
            entry.lastError = error
        }
        try modelContext.save()
    }

    /// Rifiuto definitivo (es. brano ignorato da Last.fm): non si ritenta per quel servizio.
    public func drop(_ ids: [UUID], for service: ScrobbleServiceKind, reason: String) throws {
        for entry in try entries(ids) {
            entry.setPending(false, service)
            entry.lastError = reason
        }
        try modelContext.save()
    }

    /// Toglie un servizio da tutti gli scrobble in attesa (es. account scollegato).
    public func cancelAll(for service: ScrobbleServiceKind) throws {
        for entry in try pending(service) { entry.setPending(false, service) }
        try modelContext.save()
    }

    /// Ascolti ancora da inviare ad almeno un servizio.
    public func pendingCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<QueuedScrobble>(predicate: #Predicate {
            $0.pendingLastFM || $0.pendingListenBrainz
        }))
    }

    /// Ascolti ancora da inviare ad almeno uno dei servizi indicati.
    public func pendingCount(for services: Set<ScrobbleServiceKind>) throws -> Int {
        let lastFM = services.contains(.lastFM), listenBrainz = services.contains(.listenBrainz)
        guard lastFM || listenBrainz else { return 0 }
        return try modelContext.fetchCount(FetchDescriptor<QueuedScrobble>(predicate: #Predicate {
            (lastFM && $0.pendingLastFM) || (listenBrainz && $0.pendingListenBrainz)
        }))
    }

    /// Prossimo momento in cui c'è qualcosa da ritentare.
    public func nextAttempt() throws -> Date? {
        var descriptor = FetchDescriptor<QueuedScrobble>(
            predicate: #Predicate { $0.pendingLastFM || $0.pendingListenBrainz },
            sortBy: [SortDescriptor(\.nextAttempt)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.nextAttempt
    }

    /// Rende subito ritentabili tutti gli scrobble in attesa (es. la rete è tornata).
    public func retryNow(now: Date = .now) throws {
        for entry in try modelContext.fetch(FetchDescriptor<QueuedScrobble>(predicate: #Predicate {
            $0.pendingLastFM || $0.pendingListenBrainz
        })) where entry.nextAttempt > now {
            entry.nextAttempt = now
        }
        try modelContext.save()
    }

    /// Cancella gli scrobble inviati più vecchi di una settimana.
    public func purge(now: Date = .now) throws {
        let limit = now.addingTimeInterval(-Self.keepSent)
        try modelContext.delete(model: QueuedScrobble.self, where: #Predicate {
            !$0.pendingLastFM && !$0.pendingListenBrainz && $0.createdAt < limit
        })
        try modelContext.save()
    }

    private func pending(_ service: ScrobbleServiceKind) throws -> [QueuedScrobble] {
        let lastFM = service == .lastFM
        let predicate = #Predicate<QueuedScrobble> { lastFM ? $0.pendingLastFM : $0.pendingListenBrainz }
        return try modelContext.fetch(FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedAt)]))
    }

    private func entries(_ ids: [UUID]) throws -> [QueuedScrobble] {
        guard !ids.isEmpty else { return [] }
        return try modelContext.fetch(FetchDescriptor<QueuedScrobble>(predicate: #Predicate { ids.contains($0.id) }))
    }
}

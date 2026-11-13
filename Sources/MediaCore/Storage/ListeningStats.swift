// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Statistiche di ascolto locali, calcolate dalla cronologia (senza Last.fm). Pure: si provano con date fisse.
public struct ListeningStats: Sendable, Equatable {
    public struct Ranked: Sendable, Equatable, Identifiable {
        public var id: String { name + "\u{1F}" + (detail ?? "") }
        public var name: String
        /// Artista per i brani, `nil` per gli artisti.
        public var detail: String?
        public var plays: Int

        public init(name: String, detail: String?, plays: Int) {
            self.name = name
            self.detail = detail
            self.plays = plays
        }
    }

    public struct Bucket: Sendable, Equatable, Identifiable {
        public var id: Date { start }
        public var start: Date
        public var plays: Int
        /// Minuti ascoltati (durata dei brani, al massimo 10 minuti ciascuno).
        public var minutes: Double
    }

    public var totalPlays: Int
    public var totalMinutes: Double
    public var distinctArtists: Int
    /// Ascolti per giorno negli ultimi 7 giorni (oggi compreso), dal più vecchio.
    public var days: [Bucket]
    /// Ascolti per settimana nelle ultime `weeks` settimane, dalla più vecchia.
    public var weeks: [Bucket]
    public var topArtists: [Ranked]
    public var topTracks: [Ranked]
    /// Player più usati (bundle ID → ascolti).
    public var players: [Ranked]

    /// Durata attribuita a un ascolto senza durata nota.
    static let defaultMinutes = 3.5

    public init(plays: [StoredPlay], now: Date = .now, period: TimeInterval? = nil, weeks: Int = 8, calendar: Calendar = .current) {
        let inPeriod = period.map { span in plays.filter { $0.playedAt >= now.addingTimeInterval(-span) } } ?? plays
        func minutes(_ play: StoredPlay) -> Double {
            play.track.duration.map { min($0, 600) / 60 } ?? Self.defaultMinutes
        }
        totalPlays = inPeriod.count
        totalMinutes = inPeriod.reduce(0) { $0 + minutes($1) }

        var artists: [String: (name: String, plays: Int)] = [:]
        var tracks: [String: (title: String, artist: String?, plays: Int)] = [:]
        var players: [String: Int] = [:]
        for play in inPeriod {
            let artist = play.track.artist?.trimmingCharacters(in: .whitespaces) ?? ""
            if !artist.isEmpty {
                let key = artist.lowercased()
                artists[key] = (artists[key]?.name ?? artist, (artists[key]?.plays ?? 0) + 1)
            }
            let trackKey = "\(artist.lowercased())\u{1F}\(play.track.title.lowercased())"
            tracks[trackKey] = (tracks[trackKey]?.title ?? play.track.title, artist.isEmpty ? nil : artist, (tracks[trackKey]?.plays ?? 0) + 1)
            players[play.track.playerBundleID, default: 0] += 1
        }
        distinctArtists = artists.count
        // A parità di ascolti, ordine alfabetico: il risultato non dipende dall'ordine del dizionario.
        topArtists = artists.values.map { Ranked(name: $0.name, detail: nil, plays: $0.plays) }
            .sorted { ($0.plays, $1.name) > ($1.plays, $0.name) }.prefix(10).map { $0 }
        topTracks = tracks.values.map { Ranked(name: $0.title, detail: $0.artist, plays: $0.plays) }
            .sorted { ($0.plays, $1.name) > ($1.plays, $0.name) }.prefix(10).map { $0 }
        self.players = players.map { Ranked(name: $0.key, detail: nil, plays: $0.value) }
            .sorted { ($0.plays, $1.name) > ($1.plays, $0.name) }

        let today = calendar.startOfDay(for: now)
        days = (0..<7).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: -offset, to: today),
                let end = calendar.date(byAdding: .day, value: 1, to: start)
            else { return nil }
            let slice = plays.filter { $0.playedAt >= start && $0.playedAt < end }
            return Bucket(start: start, plays: slice.count, minutes: slice.reduce(0) { $0 + minutes($1) })
        }
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        self.weeks = (0..<max(1, weeks)).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)
            else { return nil }
            let slice = plays.filter { $0.playedAt >= start && $0.playedAt < end }
            return Bucket(start: start, plays: slice.count, minutes: slice.reduce(0) { $0 + minutes($1) })
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation
import os

/// Stato unico del Now Playing letto da tutte le superfici.
///
/// Prova le sorgenti in ordine di priorità: usa la prima disponibile finché il suo stream
/// non termina, poi passa da sola alla successiva (es. adapter → AppleScript).
@Observable
@MainActor
public final class NowPlayingStore {
    public struct LogEvent: Identifiable, Sendable, Equatable {
        public let id: Int
        public let date: Date
        public let sourceID: String
        public let message: String
    }

    /// Una voce della cronologia in memoria (la persistenza arriva in fase 2).
    public struct PlayedTrack: Identifiable, Sendable, Equatable {
        public let id: Int
        public let track: Track
        public let date: Date
    }

    /// Snapshot visibile alle superfici: già filtrato dalla blacklist e normalizzato.
    public private(set) var snapshot: NowPlayingSnapshot?
    /// Brani ascoltati, dal più recente. Il primo è quello in corso (se c'è).
    public private(set) var recentTracks: [PlayedTrack] = []
    /// Cresce di 1 a ogni cambio di brano: utile alle superfici per reagire (HUD, notifiche).
    public private(set) var trackChangeCount = 0

    /// Bundle ID da ignorare (es. Zoom, Safari): i loro snapshot valgono "niente in riproduzione".
    public var ignoredBundleIDs: Set<String> = [] {
        didSet { if ignoredBundleIDs != oldValue { publish(rawSnapshot) } }
    }
    /// Pulisce i titoli dei browser ("Artista - Titolo (Official Video)").
    public var normalizesBrowserTitles = true {
        didSet { if normalizesBrowserTitles != oldValue { publish(rawSnapshot) } }
    }
    /// Cerca su iTunes le copertine mancanti (invia artista e titolo ad Apple).
    public var looksUpMissingArtwork = true
    public private(set) var activeSourceID: String?
    public private(set) var events: [LogEvent] = []
    /// `true` dopo che tutte le sorgenti sono state provate senza successo.
    public private(set) var exhausted = false

    public var track: Track? { snapshot?.track }
    public var playback: PlaybackState { snapshot?.playback ?? .stopped }
    public var player: PlayerApp? { track.map { PlayerApp.resolve(bundleID: $0.playerBundleID) } }

    /// Logger da passare alle sorgenti: thread-safe, i messaggi finiscono in `events`.
    public nonisolated let log: SourceLogger

    @ObservationIgnored private var sources: [any MediaSource] = []
    @ObservationIgnored private var activeSource: (any MediaSource)?
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private var logTask: Task<Void, Never>?
    @ObservationIgnored private var nextEventID = 0
    @ObservationIgnored private var nextHistoryID = 0
    @ObservationIgnored private var rawSnapshot: NowPlayingSnapshot?
    @ObservationIgnored private var lookupTask: Task<Void, Never>?
    /// Copertina trovata online per il brano corrente (chiave: titolo+artista).
    @ObservationIgnored private var lookedUpArtwork: (key: String, data: Data)?
    @ObservationIgnored private let artworkLookup: ArtworkLookup
    private let maxEvents: Int
    private let maxHistory: Int

    public init(maxEvents: Int = 300, maxHistory: Int = 25, artworkLookup: ArtworkLookup = .shared) {
        self.maxEvents = maxEvents
        self.maxHistory = maxHistory
        self.artworkLookup = artworkLookup
        let (stream, continuation) = AsyncStream<(String, String)>.makeStream()
        self.log = { sourceID, message in continuation.yield((sourceID, message)) }
        logTask = Task { [weak self] in
            for await (sourceID, message) in stream {
                self?.record(sourceID, message)
            }
        }
    }

    /// Sorgenti predefinite: mediaremote-adapter, poi AppleScript.
    public func startDefault() {
        start(sources: [MediaRemoteSource(log: log), AppleScriptSource(log: log)])
    }

    public func start(sources: [any MediaSource]) {
        stop()
        self.sources = sources
        exhausted = false
        runTask = Task { [weak self] in
            await self?.run()
        }
    }

    public func stop() {
        runTask?.cancel()
        runTask = nil
        activeSource = nil
        activeSourceID = nil
    }

    /// Imposta subito uno snapshot senza sorgenti: solo per anteprime SwiftUI e test.
    public func inject(_ snapshot: NowPlayingSnapshot) {
        apply(snapshot)
    }

    /// Termina quando tutte le sorgenti sono state esaurite (o il task viene annullato).
    public func waitUntilFinished() async {
        await runTask?.value
    }

    public func send(_ command: MediaCommand) async {
        guard let source = activeSource else {
            record("store", "comando \(command) ignorato: nessuna sorgente attiva")
            return
        }
        do {
            try await source.send(command)
            record(source.id, "comando inviato: \(command)")
        } catch {
            record(source.id, "comando \(command) fallito: \(error)")
        }
    }

    private func run() async {
        for source in sources {
            if Task.isCancelled { return }
            record(source.id, "verifico disponibilità…")
            guard await source.isAvailable() else {
                record(source.id, "non disponibile, passo alla prossima sorgente")
                continue
            }
            if Task.isCancelled { return }
            activeSource = source
            activeSourceID = source.id
            record(source.id, "sorgente attiva")
            var count = 0
            for await snapshot in source.updates() {
                if Task.isCancelled { return }
                apply(snapshot)
                count += 1
            }
            if Task.isCancelled { return }
            record(source.id, "la sorgente ha smesso di rispondere dopo \(count) aggiornamenti: fallback")
            activeSource = nil
            activeSourceID = nil
            rawSnapshot = nil
            publish(nil)
        }
        exhausted = true
        record("store", "nessuna sorgente funzionante")
    }

    private func apply(_ raw: NowPlayingSnapshot) {
        rawSnapshot = raw
        publish(raw)
    }

    /// Applica blacklist, normalizzazione e copertina trovata online, poi aggiorna lo stato pubblico.
    private func publish(_ raw: NowPlayingSnapshot?) {
        guard var new = raw else {
            if snapshot != nil { snapshot = nil }
            return
        }
        if var track = new.track {
            if ignoredBundleIDs.contains(track.playerBundleID) {
                new.track = nil
                new.playback = .stopped
            } else {
                let isBrowser = PlayerApp.browserBundleIDs.contains(track.playerBundleID)
                if normalizesBrowserTitles {
                    track = TitleNormalizer.normalize(track, isBrowser: isBrowser)
                }
                if track.artworkData == nil, let found = lookedUpArtwork, found.key == Self.lookupKey(track) {
                    track.setArtwork(found.data)
                }
                new.track = track
            }
        }
        let old = snapshot
        guard old != new else { return }
        snapshot = new
        guard let track = new.track else {
            if old?.track != nil { record(new.sourceID, "niente in riproduzione") }
            return
        }
        if old?.track.map({ !$0.isSameItem(as: track) }) ?? true {
            let who = [track.artist, track.title].compactMap { $0 }.joined(separator: " — ")
            record(new.sourceID, "brano: \(who) [\(track.playerBundleID)]")
            trackChangeCount += 1
            addToHistory(track)
            lookUpArtworkIfNeeded(for: track)
        } else if old?.playback.isPlaying != new.playback.isPlaying {
            record(new.sourceID, new.playback.isPlaying ? "riproduzione" : "pausa")
        }
        if track.artworkHash != nil, old?.track?.artworkHash != track.artworkHash {
            record(new.sourceID, "copertina aggiornata")
            refreshHistoryArtwork(track)
        }
    }

    private func addToHistory(_ track: Track) {
        if let first = recentTracks.first, first.track.isSameItem(as: track) { return }
        recentTracks.removeAll { $0.track.isSameItem(as: track) }
        nextHistoryID += 1
        recentTracks.insert(PlayedTrack(id: nextHistoryID, track: track, date: .now), at: 0)
        if recentTracks.count > maxHistory { recentTracks.removeLast(recentTracks.count - maxHistory) }
    }

    /// Aggiorna la copertina nella cronologia quando arriva dopo il titolo (succede spesso).
    private func refreshHistoryArtwork(_ track: Track) {
        guard let first = recentTracks.first, first.track.isSameItem(as: track),
            first.track.artworkHash != track.artworkHash, track.artworkData != nil
        else { return }
        recentTracks[0] = PlayedTrack(id: first.id, track: track, date: first.date)
    }

    static func lookupKey(_ track: Track) -> String {
        "\(track.artist ?? "")\u{1F}\(track.title)"
    }

    private func lookUpArtworkIfNeeded(for track: Track) {
        lookupTask?.cancel()
        guard looksUpMissingArtwork, track.artworkData == nil, track.artworkURL == nil,
            let artist = track.artist, !artist.isEmpty
        else { return }
        let key = Self.lookupKey(track)
        lookupTask = Task { [weak self, artworkLookup] in
            // Breve attesa: spesso la copertina arriva dal player subito dopo il titolo.
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self,
                self.snapshot?.track.map({ Self.lookupKey($0) == key && $0.artworkData == nil }) == true
            else { return }
            guard let data = await artworkLookup.artwork(artist: artist, title: track.title),
                !Task.isCancelled
            else { return }
            self.lookedUpArtwork = (key, data)
            self.record("store", "copertina trovata su iTunes")
            self.publish(self.rawSnapshot)
        }
    }

    /// Solo per debug: se `OPENTUNES_LOG_FILE` è impostata, gli eventi vengono aggiunti a quel file.
    private static let debugFile: URL? = ProcessInfo.processInfo.environment["OPENTUNES_LOG_FILE"]
        .map { URL(fileURLWithPath: $0) }

    private static func appendToDebugFile(_ line: String) {
        guard let url = debugFile else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }

    private static let logger = Logger(subsystem: "org.opentunes.OpenTunes", category: "NowPlayingStore")

    private func record(_ sourceID: String, _ message: String) {
        Self.logger.notice("[\(sourceID, privacy: .public)] \(message, privacy: .public)")
        Self.appendToDebugFile("\(Date.now.formatted(.iso8601)) [\(sourceID)] \(message)\n")
        nextEventID += 1
        events.append(LogEvent(id: nextEventID, date: .now, sourceID: sourceID, message: message))
        if events.count > maxEvents { events.removeFirst(events.count - maxEvents) }
    }
}

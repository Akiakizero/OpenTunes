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

    /// Una voce della cronologia (salvata con `attachHistory`).
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
    /// Scritture verso la cronologia persistente, in ordine (un solo consumatore).
    @ObservationIgnored private var historyWrites: AsyncStream<HistoryWrite>.Continuation?

    private enum HistoryWrite: Sendable {
        case record(StoredPlay)
        case clear
    }
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

    // MARK: Cronologia persistente

    /// Carica la cronologia salvata e da qui in poi salva ogni brano nuovo.
    /// I brani ascoltati prima del caricamento restano in cima.
    public func attachHistory(_ persistence: any HistoryPersistence) async {
        let stored = await persistence.load(limit: maxHistory)
        let current = recentTracks
        var merged = current
        for play in stored where !merged.contains(where: { $0.track.isSameItem(as: play.track) }) {
            nextHistoryID += 1
            merged.append(PlayedTrack(id: nextHistoryID, track: play.track, date: play.playedAt))
        }
        recentTracks = Array(merged.prefix(maxHistory))
        let (stream, continuation) = AsyncStream<HistoryWrite>.makeStream()
        historyWrites = continuation
        Task {
            for await write in stream {
                switch write {
                case .record(let play): await persistence.record(play)
                case .clear: await persistence.clear()
                }
            }
        }
        for entry in current.reversed() { continuation.yield(.record(StoredPlay(track: entry.track, playedAt: entry.date))) }
        record("store", "cronologia caricata: \(stored.count) brani")
    }

    /// Svuota la cronologia (anche quella salvata), tranne il brano in corso.
    public func clearHistory() {
        recentTracks.removeAll { entry in !(track.map { entry.track.isSameItem(as: $0) } ?? false) }
        historyWrites?.yield(.clear)
        for entry in recentTracks { historyWrites?.yield(.record(StoredPlay(track: entry.track, playedAt: entry.date))) }
    }

    // MARK: Azioni sul brano

    /// `true` se il player corrente supporta preferito, stelle e aggiunta alla libreria (oggi: Musica).
    public var supportsTrackActions: Bool {
        track?.playerBundleID == AppleScriptPlayer.music.bundleID
    }

    /// Preferito, dislike e stelle del brano corrente (`nil` se il player non li espone
    /// o il permesso Automazione non è ancora concesso).
    public func trackState() async -> MusicTrackState? {
        guard supportsTrackActions else { return nil }
        return await AppleScriptSource.musicTrackState()
    }

    /// Esegue un'azione sul brano corrente. Solo su azione dell'utente (può chiedere il permesso Automazione).
    public func perform(_ action: TrackAction) async throws {
        guard supportsTrackActions else { throw MediaSourceError.noActivePlayer }
        do {
            try await AppleScriptSource.perform(action)
            record("applescript", "azione sul brano: \(action)")
        } catch {
            record("applescript", "azione \(action) fallita: \(error)")
            throw error
        }
    }

    // MARK: Volume del player

    /// Player del brano corrente se ne espone il volume (Musica, Spotify).
    public var volumeControllablePlayer: AppleScriptPlayer? {
        AppleScriptPlayer.allSupported.first { $0.bundleID == track?.playerBundleID && $0.isRunning }
    }

    /// Volume del player corrente (0…1), `nil` se non disponibile o senza permesso Automazione.
    public func playerVolume() async -> Double? {
        guard let player = volumeControllablePlayer else { return nil }
        return await AppleScriptSource.volume(of: player)
    }

    /// Imposta il volume del player corrente. Solo su azione dell'utente.
    public func setPlayerVolume(_ volume: Double) async throws {
        guard let player = volumeControllablePlayer else { throw MediaSourceError.noActivePlayer }
        try await AppleScriptSource.setVolume(volume, of: player)
    }

    /// Player controllabili via AppleScript in esecuzione, diversi da quello corrente.
    public var switchablePlayers: [AppleScriptPlayer] {
        AppleScriptPlayer.allSupported.filter { $0.isRunning && $0.bundleID != track?.playerBundleID }
    }

    /// Mette in pausa il player corrente e avvia il prossimo player in esecuzione (Musica ↔ Spotify).
    /// Restituisce il player avviato. Solo su azione dell'utente.
    @discardableResult
    public func switchPlayer() async -> AppleScriptPlayer? {
        guard let target = switchablePlayers.first else {
            record("store", "cambio player: nessun altro player in esecuzione")
            return nil
        }
        if playback.isPlaying { await send(.pause) }
        do {
            try await AppleScriptSource.play(target)
            record("store", "cambio player: \(target.displayName)")
            return target
        } catch {
            record("store", "cambio player fallito: \(error)")
            return nil
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
        let entry = PlayedTrack(id: nextHistoryID, track: track, date: .now)
        recentTracks.insert(entry, at: 0)
        if recentTracks.count > maxHistory { recentTracks.removeLast(recentTracks.count - maxHistory) }
        historyWrites?.yield(.record(StoredPlay(track: track, playedAt: entry.date)))
    }

    /// Aggiorna la copertina nella cronologia quando arriva dopo il titolo (succede spesso).
    private func refreshHistoryArtwork(_ track: Track) {
        guard let first = recentTracks.first, first.track.isSameItem(as: track),
            first.track.artworkHash != track.artworkHash, track.artworkData != nil
        else { return }
        recentTracks[0] = PlayedTrack(id: first.id, track: track, date: first.date)
        historyWrites?.yield(.record(StoredPlay(track: track, playedAt: first.date)))
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

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Synchronization

/// Fallback per Apple Music e Spotify via AppleScript.
///
/// Si attiva sulle notifiche distribuite dei player (`com.apple.Music.playerInfo`,
/// `com.apple.iTunes.playerInfo`, `com.spotify.client.PlaybackStateChanged`) e rilegge lo stato
/// con un polling lento di sicurezza. Gli script non avviano mai un player chiuso.
/// Gli script girano solo se il permesso Automazione è già concesso: la richiesta parte
/// da un'azione dell'utente (`AutomationPermission.request`).
public final class AppleScriptSource: MediaSource {
    public let id = "applescript"
    public let players: [AppleScriptPlayer]
    private let log: SourceLogger
    private let pollInterval: Duration
    private let lastPlayer = Mutex<String?>(nil)

    public init(
        players: [AppleScriptPlayer] = [.music, .spotify],
        pollInterval: Duration = .seconds(5),
        log: @escaping SourceLogger = { _, _ in }
    ) {
        self.players = players
        self.pollInterval = pollInterval
        self.log = log
    }

    /// Disponibile se almeno un player supportato è installato e il permesso non è stato negato.
    public func isAvailable() async -> Bool {
        for player in players {
            guard await MainActor.run(body: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) != nil })
            else { continue }
            if await AutomationPermission.status(for: player.bundleID) != .denied { return true }
        }
        return false
    }

    public func updates() -> AsyncStream<NowPlayingSnapshot> {
        let (stream, continuation) = AsyncStream<NowPlayingSnapshot>.makeStream(bufferingPolicy: .bufferingNewest(8))
        let (wakeups, wake) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))

        let observers = ObserverTokens()
        let center = DistributedNotificationCenter.default()
        for name in players.flatMap(\.notificationNames) {
            let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: nil) { _ in
                wake.yield()
            }
            observers.append(token)
        }

        let ticker = Task { [pollInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                wake.yield()
            }
        }

        let reader = Task { [weak self] in
            guard let self else { return }
            var last: NowPlayingSnapshot?
            var artworkCache: (URL, Data)?
            var warned: Set<String> = []
            wake.yield()  // prima lettura subito
            for await _ in wakeups {
                if Task.isCancelled { break }
                var snapshot = await self.readBest(warned: &warned)
                if var track = snapshot.track, track.artworkData == nil, let url = track.artworkURL {
                    if let cached = artworkCache, cached.0 == url {
                        track.setArtwork(cached.1)
                    } else if let data = try? await URLSession.shared.data(from: url).0 {
                        artworkCache = (url, data)
                        track.setArtwork(data)
                    }
                    snapshot.track = track
                }
                if let previous = last, !Self.differsMeaningfully(previous, snapshot) { continue }
                last = snapshot
                self.lastPlayer.withLock { $0 = snapshot.track?.playerBundleID }
                continuation.yield(snapshot)
            }
            continuation.finish()
        }

        continuation.onTermination = { _ in
            reader.cancel()
            ticker.cancel()
            wake.finish()
            observers.removeAll(from: center)
        }
        return stream
    }

    public func send(_ command: MediaCommand) async throws {
        let target = lastPlayer.withLock { $0 }
        guard let player = players.first(where: { $0.bundleID == target }) ?? players.first(where: { $0.isRunning }) else {
            throw MediaSourceError.noActivePlayer
        }
        do {
            _ = try await AppleScriptRunner.shared.run(player.commandScript(command)) { _ in true }
        } catch {
            if error.isPermissionDenied { throw MediaSourceError.permissionDenied(bundleID: player.bundleID) }
            throw MediaSourceError.commandFailed(error.message)
        }
    }

    /// Legge tutti i player in esecuzione e sceglie quello che sta suonando
    /// (a parità, quello usato per ultimo).
    private func readBest(warned: inout Set<String>) async -> NowPlayingSnapshot {
        var candidates: [NowPlayingSnapshot] = []
        for player in players where player.isRunning {
            let permission = await AutomationPermission.status(for: player.bundleID)
            guard permission == .granted else {
                if warned.insert(player.bundleID).inserted {
                    log(id, "\(player.displayName): permesso Automazione \(permission) — usa «Richiedi permesso»")
                }
                continue
            }
            warned.remove(player.bundleID)
            do {
                let reading = try await AppleScriptRunner.shared.run(player.readScript, parse: AppleScriptPlayer.parseReading)
                if let snapshot = player.snapshot(from: reading, sourceID: id) { candidates.append(snapshot) }
            } catch {
                log(id, "\(player.displayName): errore AppleScript \(error.number) — \(error.message)")
            }
        }
        let preferred = lastPlayer.withLock { $0 }
        let best = candidates.first { $0.playback.isPlaying && $0.track?.playerBundleID == preferred }
            ?? candidates.first { $0.playback.isPlaying }
            ?? candidates.first { $0.track?.playerBundleID == preferred }
            ?? candidates.first
        return best ?? .empty(sourceID: id)
    }

    /// Evita di emettere snapshot identici a ogni polling; la posizione conta solo se salta.
    static func differsMeaningfully(_ a: NowPlayingSnapshot, _ b: NowPlayingSnapshot) -> Bool {
        if a.track != b.track || a.playback.isPlaying != b.playback.isPlaying
            || a.playback.shuffle != b.playback.shuffle || a.playback.repeatMode != b.playback.repeatMode
        {
            return true
        }
        let now = Date.now
        return abs(a.playback.position(at: now) - b.playback.position(at: now)) > 1.5
    }
}

/// Token degli observer di `DistributedNotificationCenter`, da rimuovere alla fine dello stream.
private final class ObserverTokens: @unchecked Sendable {
    // NSLock + array: i token non sono Sendable, quindi niente Mutex.
    private let lock = NSLock()
    private var tokens: [any NSObjectProtocol] = []

    func append(_ token: any NSObjectProtocol) {
        lock.withLock { tokens.append(token) }
    }

    func removeAll(from center: DistributedNotificationCenter) {
        let all = lock.withLock { () -> [any NSObjectProtocol] in
            defer { tokens = [] }
            return tokens
        }
        for token in all { center.removeObserver(token) }
    }
}

/// Descrizione di un player controllabile via AppleScript.
public struct AppleScriptPlayer: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case music, spotify }

    public let kind: Kind
    public let bundleID: String
    public let displayName: String
    public let notificationNames: [String]

    public static let music = AppleScriptPlayer(
        kind: .music, bundleID: "com.apple.Music", displayName: "Musica",
        notificationNames: ["com.apple.Music.playerInfo", "com.apple.iTunes.playerInfo"])
    public static let spotify = AppleScriptPlayer(
        kind: .spotify, bundleID: "com.spotify.client", displayName: "Spotify",
        notificationNames: ["com.spotify.client.PlaybackStateChanged"])

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// Restituisce una lista: {stato, titolo, artista, album, album artist, durata s, posizione s,
    /// shuffle, repeat, artwork (dati per Musica, URL per Spotify)}. `{"notrunning"}` / `{"stopped"}` altrimenti.
    /// Il controllo `is running` è dentro lo script, così non avvia mai il player.
    var readScript: String {
        switch kind {
        case .music:
            """
            if application id "com.apple.Music" is running then
                tell application id "com.apple.Music"
                    try
                        set pState to player state as text
                        if pState is "stopped" then return {"stopped"}
                        set t to current track
                        set art to ""
                        try
                            set art to raw data of artwork 1 of t
                        on error
                            try
                                set art to data of artwork 1 of t
                            end try
                        end try
                        return {pState, name of t, artist of t, album of t, album artist of t, duration of t, player position, shuffle enabled, song repeat as text, art}
                    on error
                        return {"stopped"}
                    end try
                end tell
            else
                return {"notrunning"}
            end if
            """
        case .spotify:
            """
            if application id "com.spotify.client" is running then
                tell application id "com.spotify.client"
                    try
                        set pState to player state as text
                        if pState is "stopped" then return {"stopped"}
                        set t to current track
                        set rep to "off"
                        if repeating then set rep to "all"
                        return {pState, name of t, artist of t, album of t, album artist of t, (duration of t) / 1000, player position, shuffling, rep, artwork url of t}
                    on error
                        return {"stopped"}
                    end try
                end tell
            else
                return {"notrunning"}
            end if
            """
        }
    }

    func commandScript(_ command: MediaCommand) -> String {
        let verb: String
        switch command {
        case .play: verb = "play"
        case .pause: verb = "pause"
        case .togglePlayPause: verb = "playpause"
        case .nextTrack: verb = "next track"
        case .previousTrack: verb = "previous track"
        case .seek(let s): verb = "set player position to \(String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), max(0, s)))"
        case .setShuffle(let mode):
            let on = mode != .off
            verb = kind == .music ? "set shuffle enabled to \(on)" : "set shuffling to \(on)"
        case .setRepeat(let mode):
            switch kind {
            case .music: verb = "set song repeat to \(mode == .off ? "off" : mode == .one ? "one" : "all")"
            // Spotify espone solo un booleano: "ripeti brano" diventa "ripeti tutto".
            case .spotify: verb = "set repeating to \(mode != .off)"
            }
        }
        return """
            if application id "\(bundleID)" is running then
                tell application id "\(bundleID)" to \(verb)
            end if
            """
    }

    /// Risultato grezzo di `readScript`, già estratto dal descriptor (Sendable).
    struct Reading: Sendable, Equatable {
        var state: String
        var title: String?
        var artist: String?
        var album: String?
        var albumArtist: String?
        var duration: Double?
        var position: Double?
        var shuffle: Bool?
        var repeatText: String?
        var artworkData: Data?
        var artworkURL: String?
    }

    /// `missing value` di AppleScript ('msng').
    static let missingValue: OSType = 0x6D73_6E67

    @Sendable static func parseReading(_ d: NSAppleEventDescriptor) -> Reading {
        func item(_ i: Int) -> NSAppleEventDescriptor? {
            guard d.numberOfItems >= i, let x = d.atIndex(i), x.descriptorType != typeType || x.typeCodeValue != Self.missingValue
            else { return nil }
            return x
        }
        func text(_ i: Int) -> String? { item(i)?.stringValue.flatMap { $0.isEmpty ? nil : $0 } }
        var r = Reading(state: text(1) ?? (d.stringValue ?? "stopped"))
        guard d.numberOfItems >= 9 else { return r }
        r.title = text(2)
        r.artist = text(3)
        r.album = text(4)
        r.albumArtist = text(5)
        r.duration = item(6)?.doubleValue
        r.position = item(7)?.doubleValue
        r.shuffle = item(8)?.booleanValue
        r.repeatText = text(9)
        if let art = item(10) {
            if art.descriptorType == typeUnicodeText || art.descriptorType == typeUTF8Text || art.descriptorType == typeChar {
                r.artworkURL = art.stringValue.flatMap { $0.isEmpty ? nil : $0 }
            } else if !art.data.isEmpty {
                r.artworkData = art.data
            }
        }
        return r
    }

    func snapshot(from r: Reading, sourceID: String, now: Date = .now) -> NowPlayingSnapshot? {
        guard r.state == "playing" || r.state == "paused", let title = r.title else { return nil }
        let track = Track(
            title: title, artist: r.artist, album: r.album, albumArtist: r.albumArtist,
            duration: (r.duration ?? 0) > 0 ? r.duration : nil,
            artworkData: r.artworkData, artworkURL: r.artworkURL.flatMap(URL.init(string:)),
            playerBundleID: bundleID)
        let repeatMode: RepeatMode? = switch r.repeatText {
        case "off": .off
        case "one": .one
        case "all": .all
        default: nil
        }
        let playback = PlaybackState(
            isPlaying: r.state == "playing", elapsedTime: r.position ?? 0, timestamp: now,
            shuffle: r.shuffle.map { $0 ? .tracks : .off }, repeatMode: repeatMode)
        return NowPlayingSnapshot(track: track, playback: playback, sourceID: sourceID)
    }
}

extension AppleScriptPlayer {
    public static let allSupported: [AppleScriptPlayer] = [.music, .spotify]
}

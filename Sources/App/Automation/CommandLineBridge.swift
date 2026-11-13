// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import MediaCore
import os

/// Stato del brano per la riga di comando (`opentunes now`) e per gli script: un JSON in
/// `~/Library/Application Support/OpenTunes/now-playing.json`, scritto solo con i comandi via URL accesi.
@MainActor
final class CommandLineBridge {
    struct State: Codable, Equatable {
        var title: String?
        var artist: String?
        var album: String?
        var player: String?
        var isPlaying = false
        /// Posizione in secondi al momento `timestamp`.
        var elapsedTime: Double = 0
        var duration: Double?
        var timestamp: Date = .now
    }

    private let model: AppModel
    private var tasks: [Task<Void, Never>] = []
    private let logger = Logger(subsystem: "org.opentunes.OpenTunes", category: "CLI")

    static var stateURL: URL {
        URL.applicationSupportDirectory.appending(path: "OpenTunes/now-playing.json")
    }

    /// Script incluso nell'app.
    static var scriptURL: URL? { Bundle.main.url(forResource: "opentunes-cli", withExtension: "sh") }

    /// Dove «Installa» crea il collegamento (nella home: non servono permessi di amministratore).
    static var installURL: URL { URL.homeDirectory.appending(path: ".local/bin/opentunes") }

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        tasks.append(observeChanges({ [weak self] in self?.currentState() }) { [weak self] state in
            self?.write(state)
        })
    }

    private func currentState() -> State? {
        guard model.settings.urlCommandsEnabled else { return nil }
        var state = State()
        if let track = model.track {
            state.title = track.title
            state.artist = track.artist
            state.album = track.album
            state.player = model.player?.name
            state.isPlaying = model.playback.isPlaying
            state.elapsedTime = model.playback.position(at: model.playback.timestamp, duration: track.duration)
            state.duration = track.duration
            state.timestamp = model.playback.timestamp
        }
        return state
    }

    private func write(_ state: State?) {
        let url = Self.stateURL
        guard let state else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(state).write(to: url, options: .atomic)
        } catch {
            logger.error("stato per la riga di comando non salvato: \(error, privacy: .public)")
        }
    }

    /// Collegamento `~/.local/bin/opentunes` allo script nell'app.
    static func install() throws {
        guard let script = scriptURL else { throw CocoaError(.fileNoSuchFile) }
        let link = installURL
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        if (try? link.checkResourceIsReachable()) == true || (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) != nil {
            try FileManager.default.removeItem(at: link)
        }
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: script)
    }

    static var isInstalled: Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: installURL.path)) == scriptURL?.path
    }
}

extension AppModel {
    /// Esegue un comando `opentunes://…`; `false` se è spento nelle impostazioni o non si applica.
    @discardableResult
    func run(_ command: URLCommand) -> Bool {
        guard command.isAlwaysAllowed || settings.urlCommandsEnabled else { return false }
        switch command {
        case .player, .settings, .discover, .statistics: return false  // gestiti da AppDelegate (finestre)
        case .playPause: perform(.playPause)
        case .play: send(.play)
        case .pause: send(.pause)
        case .next: perform(.next)
        case .previous: perform(.previous)
        case .love: toggleLove(feedback: true)
        case .copyLink: copyShareLink()
        case .lyrics: showLyrics()
        case .floating: toggleFloatingWindow()
        case .volume(let level): setVolume(Float(level) / 100)
        case .seek(let seconds): seek(by: TimeInterval(seconds))
        }
        return true
    }
}

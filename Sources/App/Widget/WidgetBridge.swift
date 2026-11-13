// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MediaCore
import os
import WidgetKit

/// Scrive lo stato del brano nell'App Group e chiede a WidgetKit di ricaricare i widget.
///
/// WidgetKit ha un budget di aggiornamenti: si ricarica solo quando cambia qualcosa che il widget mostra
/// (brano, play/pausa, love, seek). L'avanzamento lo disegna il widget da solo con `ProgressView(timerInterval:)`.
@MainActor
final class WidgetBridge {
    private let model: AppModel
    private var tasks: [Task<Void, Never>] = []
    private var lastState: WidgetState?
    private var lastArtworkHash: String?
    private var reloadTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "org.opentunes.OpenTunes", category: "Widget")

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        guard SharedContainer.url != nil else {
            logger.error("App Group non disponibile: i widget non riceveranno lo stato")
            return
        }
        WidgetCommandBridge.handler = { [weak self] command in self?.handle(command) }
        tasks.append(observeChanges({ [weak self] in self?.currentState() }) { [weak self] state in
            guard let state else { return }
            self?.publish(state)
        })
    }

    private func handle(_ command: WidgetCommand) {
        switch command {
        case .playPause: model.perform(.playPause)
        case .next: model.perform(.next)
        case .previous: model.perform(.previous)
        case .toggleLove: model.toggleLove()
        }
    }

    private func currentState() -> WidgetState {
        Self.state(
            track: model.track, playback: model.playback, playerName: model.player?.name, tint: model.tint,
            canLove: model.canLove, isLoved: model.isLoved, profile: model.scrobbler.isLastFMConnected ? model.scrobbler.profile : nil)
    }

    nonisolated static func state(
        track: Track?, playback: PlaybackState, playerName: String?, tint: AccentTint?,
        canLove: Bool, isLoved: Bool, profile: LastFMProfile?
    ) -> WidgetState {
        var state = WidgetState()
        if let track {
            state.title = track.title
            state.artist = track.artist
            state.album = track.album
            state.playerName = playerName
            state.isPlaying = playback.isPlaying
            state.elapsedTime = playback.position(at: playback.timestamp, duration: track.duration)
            state.timestamp = playback.timestamp
            state.duration = track.duration
            state.artworkHash = track.artworkHash
            state.canLove = canLove
            state.isLoved = isLoved
        }
        state.tint = tint.map { [$0.dominant.r, $0.dominant.g, $0.dominant.b] }
        if let profile {
            state.lastFMUser = profile.user.name
            state.recentTracks = profile.recent.prefix(6).map { WidgetState.Entry(title: $0.title, artist: $0.artist) }
            state.topArtists = profile.topArtists.prefix(5).map { WidgetState.Artist(name: $0.name, playCount: $0.playCount) }
        }
        return state
    }

    /// Serve ricaricare i widget? Una deriva dell'orologio sotto i 2 s non conta (l'adapter ripubblica la posizione).
    nonisolated static func needsReload(from old: WidgetState?, to new: WidgetState) -> Bool {
        guard var old else { return true }
        let drift = abs(startDate(old).timeIntervalSince(startDate(new)))
        if new.isPlaying, old.isPlaying, drift < 2 {
            old.elapsedTime = new.elapsedTime
            old.timestamp = new.timestamp
        } else if !new.isPlaying, !old.isPlaying, abs(old.elapsedTime - new.elapsedTime) < 2 {
            old.elapsedTime = new.elapsedTime
            old.timestamp = new.timestamp
        }
        return old != new
    }

    nonisolated private static func startDate(_ state: WidgetState) -> Date {
        state.timestamp.addingTimeInterval(-state.elapsedTime)
    }

    private func publish(_ state: WidgetState) {
        guard Self.needsReload(from: lastState, to: state) else { return }
        lastState = state
        writeArtworkIfNeeded(hash: state.artworkHash)
        do {
            guard let url = SharedContainer.stateURL else { return }
            try JSONEncoder().encode(state).write(to: url, options: .atomic)
        } catch {
            logger.error("stato del widget non salvato: \(error, privacy: .public)")
            return
        }
        // Più cambi ravvicinati (brano + copertina + love) diventano una sola ricarica.
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.nowPlaying)
        }
    }

    private func writeArtworkIfNeeded(hash: String?) {
        guard hash != lastArtworkHash, let url = SharedContainer.artworkURL else { return }
        lastArtworkHash = hash
        // I widget ridimensionano comunque le immagini: 300 px bastano per la taglia grande.
        // La copertina si decodifica qui: `model.artwork` potrebbe non essere ancora aggiornata.
        if let png = model.track?.artwork?.squareThumbnail(side: 300)?.pngData {
            try? png.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

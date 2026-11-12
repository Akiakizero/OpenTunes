// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MediaCore
import Observation
import SwiftUI

/// Stato condiviso dalle superfici: lo store del Now Playing, le preferenze e i dati derivati
/// (copertina decodificata, tinta, volume). Le superfici leggono da qui e inviano azioni qui.
@Observable
@MainActor
final class AppModel {
    let store: NowPlayingStore
    let settings: AppSettings

    /// Copertina del brano corrente, decodificata una volta sola per hash.
    private(set) var artwork: NSImage?
    /// Tinta estratta dalla copertina (`nil` se disattivata o senza copertina).
    private(set) var tint: AccentTint?
    /// Ultimo volume di sistema noto (0…1).
    private(set) var volume: Float?

    /// Eventi per HUD e notifiche.
    enum Event {
        case trackChanged
        case playPauseToggled(isPlaying: Bool)
        case skipped(forward: Bool)
        case volumeChanged(Float)
    }

    @ObservationIgnored var onEvent: ((Event) -> Void)?
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var artworkHash: String?

    init(store: NowPlayingStore = NowPlayingStore(), settings: AppSettings = AppSettings()) {
        self.store = store
        self.settings = settings
    }

    var track: Track? { store.track }
    var playback: PlaybackState { store.playback }
    var player: PlayerApp? { store.player }
    var hasTrack: Bool { store.track != nil }

    /// Testo per la menu bar secondo il formato scelto.
    var menuBarTitle: String? {
        guard let track else { return nil }
        return settings.titleFormat.render(title: track.title, artist: track.artist, album: track.album)
    }

    func start() {
        applyStoreSettings()
        store.startDefault()
        startDerivedState()
    }

    /// Avvia gli osservatori che tengono aggiornati copertina, tinta, volume ed eventi.
    func startDerivedState() {
        volume = SystemVolume.current
        tasks.append(observeChanges({ [store] in store.track?.artworkHash }) { [weak self] _ in
            self?.updateArtwork()
        })
        tasks.append(observeChanges({ [settings] in settings.tintsWithArtwork }) { [weak self] _ in
            self?.updateArtwork(force: true)
        })
        tasks.append(observeChanges({ [store] in store.trackChangeCount }) { [weak self] count in
            // Il primo brano dopo l'avvio non è un "cambio": niente HUD né notifica.
            if count > 1 { self?.onEvent?(.trackChanged) }
        })
        tasks.append(observeChanges({ [settings] in
            [settings.ignoredBundleIDs.joined(separator: ","), "\(settings.normalizesBrowserTitles)", "\(settings.looksUpMissingArtwork)"]
        }) { [weak self] _ in
            self?.applyStoreSettings()
        })
    }

    private func applyStoreSettings() {
        store.ignoredBundleIDs = Set(settings.ignoredBundleIDs)
        store.normalizesBrowserTitles = settings.normalizesBrowserTitles
        store.looksUpMissingArtwork = settings.looksUpMissingArtwork
    }

    func updateArtwork(force: Bool = false) {
        let hash = store.track?.artworkHash
        guard force || hash != artworkHash else { return }
        artworkHash = hash
        artwork = store.track?.artwork
        tint = settings.tintsWithArtwork ? artwork.flatMap(AccentTint.from) : nil
    }

    /// Colore della tinta per lo schema indicato.
    func tintColor(for scheme: ColorScheme) -> Color? {
        tint?.color(for: scheme)
    }

    // MARK: Azioni

    func perform(_ action: PlaybackAction) {
        let playback = store.playback
        switch action {
        case .previous:
            send(.previousTrack)
            onEvent?(.skipped(forward: false))
        case .next:
            send(.nextTrack)
            onEvent?(.skipped(forward: true))
        case .playPause:
            send(.togglePlayPause)
            onEvent?(.playPauseToggled(isPlaying: !playback.isPlaying))
        case .toggleShuffle:
            let on = (playback.shuffle ?? .off) != .off
            send(.setShuffle(on ? .off : .tracks))
        case .cycleRepeat:
            send(.setRepeat((playback.repeatMode ?? .off).next))
        }
    }

    func seek(to seconds: TimeInterval) {
        send(.seek(to: seconds))
    }

    /// Salta di `delta` secondi rispetto alla posizione corrente.
    func seek(by delta: TimeInterval) {
        guard let duration = track?.duration else { return }
        let target = max(0, min(duration, playback.position(duration: duration) + delta))
        seek(to: target)
    }

    func changeVolume(by delta: Float) {
        guard let value = SystemVolume.change(by: delta) else { return }
        volume = value
        onEvent?(.volumeChanged(value))
    }

    func setVolume(_ value: Float) {
        volume = SystemVolume.set(value) ?? volume
    }

    func refreshVolume() {
        volume = SystemVolume.current
    }

    func toggleFloatingWindow() {
        settings.floatingVisible.toggle()
    }

    /// Porta in primo piano il player che sta suonando.
    func openSourcePlayer() {
        guard let bundleID = track?.playerBundleID, !bundleID.isEmpty else { return }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            running.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Chiede il permesso Automazione per i player installati (solo su azione dell'utente).
    func requestAutomationPermission() {
        Task {
            for player in AppleScriptPlayer.allSupported
            where NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) != nil {
                _ = await AutomationPermission.request(for: player.bundleID)
            }
        }
    }

    private func send(_ command: MediaCommand) {
        Task { await store.send(command) }
    }
}

/// Esegue `onChange` con il valore iniziale e a ogni sua modifica (deduplicando i valori uguali).
@MainActor
func observeChanges<T: Equatable & Sendable>(
    _ value: @escaping @MainActor @Sendable () -> T,
    onChange: @escaping @MainActor (T) -> Void
) -> Task<Void, Never> {
    Task { @MainActor in
        var last: T?
        for await current in Observations(value) {
            if current != last {
                last = current
                onChange(current)
            }
        }
    }
}

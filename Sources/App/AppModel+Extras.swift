// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreAudio
import MediaCore
import SwiftUI

/// Funzioni della fase 4: testi, link universale, volume del player, uscita audio, sospensione e riattivazione.
extension AppModel {
    // MARK: Testi

    nonisolated static func lyricsKey(_ track: Track) -> String {
        "\(track.artist ?? "")\u{1F}\(track.title)\u{1F}\(Int((track.duration ?? 0).rounded()))"
    }

    /// Carica il testo del brano corrente, una volta per brano. Le viste lo chiamano quando lo mostrano.
    func loadLyrics() {
        guard settings.lyricsEnabled, let track, let artist = track.artist, !artist.isEmpty else {
            if lyrics != .idle, track == nil { lyrics = .idle }
            return
        }
        let key = Self.lyricsKey(track)
        guard key != lyricsKey else { return }
        lyricsKey = key
        lyrics = .loading
        let query = LyricsService.Query(artist: artist, title: track.title, album: track.album, duration: track.duration)
        let service = lyricsService
        Task {
            let result: LyricsState
            do {
                result = try await service.lyrics(for: query).map(LyricsState.found) ?? .notFound
            } catch {
                result = .failed("\(error)")
            }
            // Nel frattempo il brano può essere cambiato.
            guard lyricsKey == key else { return }
            lyrics = result
            if case .failed = result { lyricsKey = nil }
        }
    }

    /// Riga del testo in corso (per il notch), `nil` senza testo sincronizzato.
    func currentLyricLine(at date: Date = .now) -> String? {
        guard let lyrics = lyrics.lyrics, lyrics.isSynced else { return nil }
        return lyrics.line(at: playback.position(at: date, duration: track?.duration))
    }

    // MARK: Link universale

    /// Il brano ha artista e titolo: si può cercare il link universale.
    var canShare: Bool { settings.shareLinksEnabled && track?.artist?.isEmpty == false }

    /// Stelle, dislike e libreria si mostrano: brano di Musica e funzione accesa.
    var showsMusicActions: Bool { settings.musicActionsEnabled && store.supportsTrackActions }

    /// Player verso cui passare con «Passa a…», se la funzione è accesa.
    var switchTarget: AppleScriptPlayer? { settings.switchPlayerEnabled ? store.switchablePlayers.first : nil }

    /// Apre «Scopri», se la funzione è accesa.
    var discoverAction: (() -> Void)? { settings.discoverEnabled ? onOpenDiscover : nil }

    /// Link song.link del brano corrente.
    func shareLink() async throws -> URL {
        guard let track, let artist = track.artist, !artist.isEmpty else { throw ShareLinkService.Failure.notFound }
        isPreparingShareLink = true
        defer { isPreparingShareLink = false }
        return try await shareLinks.link(artist: artist, title: track.title, country: Locale.current.region?.identifier)
    }

    /// Copia il link universale negli appunti; l'HUD conferma (o l'errore compare sotto i pulsanti).
    func copyShareLink() {
        let title = track?.title ?? ""
        Task {
            do {
                copyToPasteboard(try await shareLink())
                actionError = nil
                onEvent?(.trackAction(title: title, symbol: "link"))
            } catch {
                actionError = String(localized: "Link universale: \(String(describing: error))")
            }
        }
    }

    func copyToPasteboard(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSURL])
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    /// Mostra il testo nella finestra flottante grande (comandi, Siri, Comandi Rapidi).
    func showLyrics() {
        guard settings.lyricsEnabled, settings.floatingEnabled else { return }
        if settings.floatingSize == .compact { settings.floatingSize = .large }
        floatingShowsLyrics = true
        settings.floatingVisible = true
        loadLyrics()
    }

    /// Apre il menu di condivisione di macOS con il link universale, accanto al puntatore.
    func shareLinkWithPicker() {
        Task {
            do {
                let url = try await shareLink()
                SharePicker.present([url, "\(track?.artist ?? "") — \(track?.title ?? "")"])
            } catch {
                actionError = String(localized: "Link universale: \(String(describing: error))")
            }
        }
    }

    // MARK: Volume del player

    func refreshPlayerVolume() {
        guard store.volumeControllablePlayer != nil else {
            playerVolume = nil
            return
        }
        Task { playerVolume = await store.playerVolume() }
    }

    func setPlayerVolume(_ value: Double) {
        playerVolume = value
        Task {
            do {
                try await store.setPlayerVolume(value)
            } catch {
                actionError = String(localized: "Volume di \(player?.name ?? "player"): \(String(describing: error))")
                refreshPlayerVolume()
            }
        }
    }

    // MARK: Spettro

    /// Livelli reali per il visualizer, `nil` se non arriva audio (il visualizer torna all'animazione).
    var spectrumLevels: @Sendable () -> [Float]? {
        { [spectrum] in spectrum.isReceivingAudio ? spectrum.levels : nil }
    }

    var needsSpectrum: Bool {
        settings.visualizerEnabled && settings.visualizerUsesAudio && playback.isPlaying
            && (settings.notchEnabled || settings.showsFloatingWindow)
    }

    /// Colori del visualizer su fondo scuro (notch, copertina): quelli della copertina resi luminosi,
    /// bianco con il tema monocromo o senza copertina.
    var visualizerColors: [Color] {
        palette.isEmpty ? [.white] : palette.map { $0.vivid().color }
    }

    // MARK: Uscita audio

    func refreshOutputDevices() {
        outputDevices = AudioOutput.devices()
        currentOutputID = AudioOutput.defaultDeviceID
    }

    func selectOutput(_ device: AudioOutputDevice) {
        if AudioOutput.setDefault(device.id) {
            currentOutputID = device.id
            refreshVolume()
        } else {
            actionError = String(localized: "Impossibile usare \(device.name) come uscita")
        }
    }

    // MARK: Eventi di sistema

    /// Sospensione e riattivazione del Mac, cambi dell'uscita audio.
    func startSystemObservers() {
        refreshOutputDevices()
        // Lo spettro si cattura solo se il visualizer è acceso, qualcosa suona e una superficie lo mostra.
        tasks.append(observeChanges({ [weak self] in self?.needsSpectrum ?? false }) { [weak self] needed in
            guard let self else { return }
            if needed { spectrum.start() } else { spectrum.stop() }
        })
        tasks.append(Task { [weak self] in
            for await _ in AudioOutput.changes() {
                // Il dispositivo aggregato dello spettro è legato all'uscita: va ricreato.
                if let self, spectrum.isRunning {
                    spectrum.stop()
                    spectrum.start()
                }
                self?.refreshOutputDevices()
                self?.refreshVolume()
            }
        })
        tasks.append(Task { [weak self] in
            for await _ in NSWorkspace.shared.notificationCenter.notifications(named: NSWorkspace.didWakeNotification) {
                guard let self else { return }
                store.log("system", "riattivazione dalla sospensione")
                refreshVolume()
                refreshOutputDevices()
                refreshPlayerVolume()
                refreshMusicState()
                // Gli ascolti messi in coda durante la sospensione partono appena c'è rete.
                scrobbler.requestFlush()
            }
        })
    }
}

/// Menu di condivisione di macOS (`NSSharingServicePicker`) aperto sotto il puntatore, nella finestra attiva.
@MainActor
enum SharePicker {
    static func present(_ items: [Any]) {
        let mouse = NSEvent.mouseLocation
        let window = NSApp.keyWindow
            ?? NSApp.windows.first { $0.isVisible && $0.frame.contains(mouse) }
        guard let window, let view = window.contentView else { return }
        let point = view.convert(window.convertPoint(fromScreen: mouse), from: nil)
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: NSRect(origin: point, size: CGSize(width: 1, height: 1)), of: view, preferredEdge: .minY)
    }
}

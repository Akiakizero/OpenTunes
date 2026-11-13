// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MediaCore
import Observation

/// Collega il brano in riproduzione a Discord Rich Presence («Sta ascoltando»), se attivo nelle impostazioni.
///
/// Serve l'ID di un'applicazione Discord: quello del progetto (variabile `DISCORD_CLIENT_ID` alla build) o uno
/// personale creato su discord.com/developers e scritto nelle impostazioni. In pausa l'attività sparisce.
@MainActor
@Observable
final class DiscordController {
    private let model: AppModel
    @ObservationIgnored private var presence: DiscordPresence?
    @ObservationIgnored private var presenceClientID = ""
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var pending: Task<Void, Never>?
    /// Stato mostrato nelle impostazioni.
    private(set) var status: String = ""

    init(model: AppModel) {
        self.model = model
    }

    /// ID dell'applicazione Discord in uso (personale o del progetto), vuoto se manca.
    var clientID: String {
        let custom = model.settings.discordApplicationID.trimmingCharacters(in: .whitespaces)
        if !custom.isEmpty { return custom }
        return (Bundle.main.object(forInfoDictionaryKey: "DiscordClientID") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    struct Key: Equatable, Sendable {
        var enabled: Bool
        var clientID: String
        var title: String?
        var artist: String?
        var isPlaying: Bool
        /// Minuto di inizio del brano: un seek sposta l'avanzamento mostrato da Discord.
        var start: Int
    }

    func start() {
        tasks.append(observeChanges({ [weak self] in self?.key ?? Key(enabled: false, clientID: "", isPlaying: false, start: 0) }) {
            [weak self] key in
            self?.schedule(key)
        })
    }

    private var key: Key {
        let playback = model.playback
        let elapsed = playback.position(duration: model.track?.duration)
        return Key(
            enabled: model.settings.discordEnabled, clientID: clientID, title: model.track?.title, artist: model.track?.artist,
            isPlaying: playback.isPlaying, start: Int(Date.now.addingTimeInterval(-elapsed).timeIntervalSince1970 / 5))
    }

    /// Più cambi ravvicinati diventano un solo aggiornamento (Discord limita SET_ACTIVITY a 5 ogni 20 s).
    private func schedule(_ key: Key) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.apply(key)
        }
    }

    private func apply(_ key: Key) async {
        guard key.enabled else {
            await presence?.clear()
            await presence?.close()
            presence = nil
            status = ""
            return
        }
        guard !key.clientID.isEmpty else {
            status = String(localized: "Serve l'ID di un'applicazione Discord.")
            return
        }
        if presence == nil || presenceClientID != key.clientID {
            await presence?.close()
            presence = DiscordPresence(clientID: key.clientID)
            presenceClientID = key.clientID
        }
        guard let presence else { return }
        guard key.isPlaying, let track = model.track else {
            await presence.clear()
            status = String(localized: "In pausa: niente attività su Discord.")
            return
        }
        let activity = await makeActivity(track)
        await presence.update(activity)
        switch await presence.state {
        case .connected: status = String(localized: "Collegato: Discord mostra «\(track.title)».")
        case .failed(let message): status = message
        case .disconnected: status = String(localized: "Non collegato.")
        }
    }

    private func makeActivity(_ track: Track) async -> DiscordActivity {
        let playback = model.playback
        let elapsed = playback.position(duration: track.duration)
        let start = Date.now.addingTimeInterval(-elapsed)
        var artworkURL: URL?
        if let artist = track.artist, !artist.isEmpty, model.settings.looksUpMissingArtwork {
            artworkURL = await ArtworkLookup.shared.artworkURL(artist: artist, title: track.title)
        }
        return DiscordActivity(
            title: track.title, artist: track.artist, album: track.album, start: start,
            end: track.duration.map { start.addingTimeInterval($0) }, artworkURL: artworkURL, link: nil)
    }
}

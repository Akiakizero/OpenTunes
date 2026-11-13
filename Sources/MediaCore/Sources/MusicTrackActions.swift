// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Stato del brano corrente in Musica: preferito, "non mi piace", stelle.
public struct MusicTrackState: Sendable, Equatable {
    public var favorited: Bool
    public var disliked: Bool
    /// Stelle da 0 a 5 (Musica le salva come 0…100).
    public var stars: Int

    public init(favorited: Bool = false, disliked: Bool = false, stars: Int = 0) {
        self.favorited = favorited
        self.disliked = disliked
        self.stars = stars
    }
}

/// Azioni sul brano corrente del player (oggi solo Musica le supporta).
public enum TrackAction: Sendable, Equatable {
    case setFavorite(Bool)
    case setDisliked(Bool)
    /// 0…5 stelle.
    case setRating(Int)
    case addToLibrary
}

extension AppleScriptPlayer {
    /// Legge preferito/dislike/stelle del brano corrente. Solo Musica; il player non viene mai avviato.
    var trackStateScript: String? {
        guard kind == .music else { return nil }
        // `favorited` (macOS 14+) sostituisce `loved`: si prova il nuovo nome, poi il vecchio.
        return """
            if application id "com.apple.Music" is running then
                tell application id "com.apple.Music"
                    try
                        set t to current track
                        set fav to false
                        try
                            set fav to favorited of t
                        on error
                            try
                                set fav to loved of t
                            end try
                        end try
                        set dis to false
                        try
                            set dis to disliked of t
                        end try
                        return {fav, dis, rating of t}
                    on error
                        return {}
                    end try
                end tell
            end if
            return {}
            """
    }

    func actionScript(_ action: TrackAction) -> String? {
        guard kind == .music else { return nil }
        let body: String
        switch action {
        case .setFavorite(let on):
            body = """
                try
                    set favorited of current track to \(on)
                on error
                    set loved of current track to \(on)
                end try
                """
        case .setDisliked(let on):
            body = "set disliked of current track to \(on)"
        case .setRating(let stars):
            body = "set rating of current track to \(min(5, max(0, stars)) * 20)"
        case .addToLibrary:
            // I brani di Apple Music si aggiungono duplicandoli nella sorgente "Libreria" (la prima).
            body = """
                set t to current track
                try
                    duplicate t to source 1
                on error
                    duplicate t to library playlist 1 of source 1
                end try
                """
        }
        return """
            if application id "com.apple.Music" is running then
                tell application id "com.apple.Music"
                    \(body.replacingOccurrences(of: "\n", with: "\n            "))
                end tell
            end if
            """
    }

    static func parseTrackState(_ d: NSAppleEventDescriptor) -> MusicTrackState? {
        guard d.numberOfItems >= 3, let fav = d.atIndex(1), let dis = d.atIndex(2), let rating = d.atIndex(3) else { return nil }
        return MusicTrackState(
            favorited: fav.booleanValue, disliked: dis.booleanValue,
            stars: Int((Double(rating.int32Value) / 20).rounded()))
    }

    /// Script che avvia la riproduzione in questo player (usato da "cambia player attivo").
    var playScript: String {
        """
        if application id "\(bundleID)" is running then
            tell application id "\(bundleID)" to play
        end if
        """
    }
}

extension AppleScriptSource {
    /// Stato del brano in Musica, se il permesso Automazione è già concesso (non chiede mai il permesso).
    public static func musicTrackState() async -> MusicTrackState? {
        let player = AppleScriptPlayer.music
        guard player.isRunning, await AutomationPermission.status(for: player.bundleID) == .granted,
            let script = player.trackStateScript
        else { return nil }
        return try? await AppleScriptRunner.shared.run(script) { AppleScriptPlayer.parseTrackState($0) }
    }

    /// Esegue un'azione sul brano corrente di Musica. Va chiamata solo su azione dell'utente:
    /// se serve, mostra la richiesta del permesso Automazione.
    public static func perform(_ action: TrackAction) async throws {
        let player = AppleScriptPlayer.music
        guard player.isRunning, let script = player.actionScript(action) else { throw MediaSourceError.noActivePlayer }
        try await runWithPermission(script, player: player)
    }

    /// Avvia la riproduzione in `player`. Solo su azione dell'utente.
    public static func play(_ player: AppleScriptPlayer) async throws {
        guard player.isRunning else { throw MediaSourceError.noActivePlayer }
        try await runWithPermission(player.playScript, player: player)
    }

    private static func runWithPermission(_ script: String, player: AppleScriptPlayer) async throws {
        let permission = await AutomationPermission.request(for: player.bundleID)
        guard permission != .denied else { throw MediaSourceError.permissionDenied(bundleID: player.bundleID) }
        do {
            _ = try await AppleScriptRunner.shared.run(script) { _ in true }
        } catch {
            if error.isPermissionDenied { throw MediaSourceError.permissionDenied(bundleID: player.bundleID) }
            throw MediaSourceError.commandFailed(error.message)
        }
    }
}

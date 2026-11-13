// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Volume interno del player (Musica e Spotify espongono `sound volume`, 0…100), distinto dal volume di sistema.
extension AppleScriptPlayer {
    var volumeScript: String {
        """
        if application id "\(bundleID)" is running then
            tell application id "\(bundleID)" to return sound volume
        end if
        return -1
        """
    }

    func setVolumeScript(_ percent: Int) -> String {
        """
        if application id "\(bundleID)" is running then
            tell application id "\(bundleID)" to set sound volume to \(min(100, max(0, percent)))
        end if
        """
    }

    /// 0…1 da `sound volume`; `nil` per valori fuori scala (player chiuso = -1).
    static func parseVolume(_ descriptor: NSAppleEventDescriptor) -> Double? {
        let value = Int(descriptor.int32Value)
        return (0...100).contains(value) ? Double(value) / 100 : nil
    }
}

extension AppleScriptSource {
    /// Volume del player, solo se il permesso Automazione è già concesso (non chiede mai il permesso).
    public static func volume(of player: AppleScriptPlayer) async -> Double? {
        guard player.isRunning, await AutomationPermission.status(for: player.bundleID) == .granted else { return nil }
        let reading = try? await AppleScriptRunner.shared.run(player.volumeScript) { AppleScriptPlayer.parseVolume($0) }
        return reading ?? nil
    }

    /// Imposta il volume del player (0…1). Solo su azione dell'utente: può chiedere il permesso Automazione.
    public static func setVolume(_ volume: Double, of player: AppleScriptPlayer) async throws {
        guard player.isRunning else { throw MediaSourceError.noActivePlayer }
        let permission = await AutomationPermission.request(for: player.bundleID)
        guard permission != .denied else { throw MediaSourceError.permissionDenied(bundleID: player.bundleID) }
        do {
            _ = try await AppleScriptRunner.shared.run(player.setVolumeScript(Int((volume * 100).rounded()))) { _ in true }
        } catch {
            if error.isPermissionDenied { throw MediaSourceError.permissionDenied(bundleID: player.bundleID) }
            throw MediaSourceError.commandFailed(error.message)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreServices

/// Stato del permesso Automazione (Apple Events) verso un'app.
/// Tecnica `AEDeterminePermissionToAutomateTarget` vista in PlayStatus (MIT); codice scritto da zero.
public enum AutomationPermission: Sendable, Equatable, CustomStringConvertible {
    case granted
    case denied
    /// L'utente non ha ancora deciso: la prossima richiesta mostrerà il dialog di sistema.
    case notDetermined
    /// L'app di destinazione non è in esecuzione: lo stato non è verificabile.
    case targetNotRunning
    case unknown(OSStatus)

    public var description: String {
        switch self {
        case .granted: "concesso"
        case .denied: "negato"
        case .notDetermined: "da chiedere"
        case .targetNotRunning: "app non in esecuzione"
        case .unknown(let s): "sconosciuto (\(s))"
        }
    }

    init(status: OSStatus) {
        switch status {
        case noErr: self = .granted
        case OSStatus(errAEEventNotPermitted): self = .denied
        case OSStatus(errAEEventWouldRequireUserConsent): self = .notDetermined
        case OSStatus(procNotFound): self = .targetNotRunning
        default: self = .unknown(status)
        }
    }

    /// Legge lo stato senza mostrare dialog. La chiamata è bloccante: gira fuori dal main actor.
    public static func status(for bundleID: String) async -> AutomationPermission {
        await determine(bundleID, ask: false)
    }

    /// Chiede il permesso (mostra il dialog di sistema se non ancora deciso).
    /// Va chiamata solo in risposta a un'azione dell'utente.
    public static func request(for bundleID: String) async -> AutomationPermission {
        await determine(bundleID, ask: true)
    }

    @concurrent
    private static func determine(_ bundleID: String, ask: Bool) async -> AutomationPermission {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let desc = target.aeDesc else { return .unknown(OSStatus(errAENotAEDesc)) }
        return AutomationPermission(status: AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, ask))
    }

    /// Apre Impostazioni di Sistema › Privacy e sicurezza › Automazione.
    @MainActor public static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

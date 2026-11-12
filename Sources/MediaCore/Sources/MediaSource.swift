// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Una sorgente di informazioni Now Playing.
///
/// Contratto: `updates()` emette snapshot completi; quando la sorgente smette di funzionare
/// lo stream **termina**, e `NowPlayingStore` passa alla sorgente successiva.
public protocol MediaSource: Sendable {
    var id: String { get }
    func isAvailable() async -> Bool
    func updates() -> AsyncStream<NowPlayingSnapshot>
    func send(_ command: MediaCommand) async throws
}

public enum MediaSourceError: Error, Equatable, CustomStringConvertible {
    case unavailable(String)
    case commandFailed(String)
    case permissionDenied(bundleID: String)
    case noActivePlayer

    public var description: String {
        switch self {
        case .unavailable(let why): "sorgente non disponibile: \(why)"
        case .commandFailed(let why): "comando non riuscito: \(why)"
        case .permissionDenied(let id): "permesso Automazione negato per \(id)"
        case .noActivePlayer: "nessun player attivo"
        }
    }
}

/// Riceve i messaggi diagnostici delle sorgenti (mostrati nella finestra di debug).
public typealias SourceLogger = @Sendable (_ sourceID: String, _ message: String) -> Void

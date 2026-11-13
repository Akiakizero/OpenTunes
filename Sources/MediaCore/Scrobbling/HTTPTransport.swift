// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Esegue una richiesta HTTP. Nei test si sostituisce con risposte di esempio.
public typealias HTTPTransport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

public enum HTTP {
    /// Trasporto reale su `URLSession.shared`.
    public static let live: HTTPTransport = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

    /// Corpo `application/x-www-form-urlencoded` (RFC 3986: solo i caratteri non riservati restano in chiaro).
    static func formBody(_ parameters: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let body = parameters.sorted { $0.key < $1.key }
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }
}

/// Errore comune dei servizi di scrobbling, già classificato per la coda.
public enum ScrobbleServiceError: Error, Equatable, CustomStringConvertible {
    /// Rete assente o server non raggiungibile: si riprova.
    case network(String)
    /// Il servizio chiede di riprovare più tardi (server occupato, rate limit).
    case temporary(String)
    /// La sessione o il token non valgono più: serve un nuovo accesso.
    case unauthorized(String)
    /// Richiesta rifiutata: riprovare non serve.
    case rejected(String)
    /// Manca la configurazione (API key, token).
    case notConfigured(String)

    public var isRetryable: Bool {
        switch self {
        case .network, .temporary: true
        case .unauthorized, .rejected, .notConfigured: false
        }
    }

    public var description: String {
        switch self {
        case .network(let m): "rete: \(m)"
        case .temporary(let m): "servizio temporaneamente non disponibile: \(m)"
        case .unauthorized(let m): "accesso non valido: \(m)"
        case .rejected(let m): "rifiutato: \(m)"
        case .notConfigured(let m): "non configurato: \(m)"
        }
    }
}

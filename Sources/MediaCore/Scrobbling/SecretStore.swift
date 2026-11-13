// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Security
import Synchronization

/// Dove si salvano session key e token. Mai in chiaro su disco: l'implementazione reale è il Portachiavi.
public protocol SecretStore: Sendable {
    func secret(for account: String) -> String?
    func setSecret(_ value: String?, for account: String) throws
}

/// Nomi degli elementi nel Portachiavi.
public enum SecretAccount {
    public static let lastFMSession = "lastfm.session"
    public static let lastFMUser = "lastfm.user"
    /// Secret della chiave personale dell'utente (la API key non è segreta e sta nelle preferenze).
    public static let lastFMCustomSecret = "lastfm.customSecret"
    public static let listenBrainzToken = "listenbrainz.token"
    public static let listenBrainzUser = "listenbrainz.user"
}

/// Password generiche nel Portachiavi di login (`kSecClassGenericPassword`).
public struct KeychainStore: SecretStore {
    public let service: String

    public init(service: String = "org.opentunes.OpenTunes") {
        self.service = service
    }

    public struct KeychainError: Error, CustomStringConvertible {
        public let status: OSStatus
        public var description: String {
            (SecCopyErrorMessageString(status, nil) as String?) ?? "errore del Portachiavi \(status)"
        }
    }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    public func secret(for account: String) -> String? {
        var query = query(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func setSecret(_ value: String?, for account: String) throws {
        let base = query(account)
        guard let value, !value.isEmpty else {
            let status = SecItemDelete(base as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
            return
        }
        let data = Data(value.utf8)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrLabel as String] = "OpenTunes (\(account))"
            let added = SecItemAdd(add as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }
}

/// Segreti in memoria: per test e anteprime.
public final class MemorySecretStore: SecretStore {
    private let values = Mutex<[String: String]>([:])

    public init(_ initial: [String: String] = [:]) {
        values.withLock { $0 = initial }
    }

    public func secret(for account: String) -> String? {
        values.withLock { $0[account] }
    }

    public func setSecret(_ value: String?, for account: String) throws {
        values.withLock { $0[account] = value?.isEmpty == false ? value : nil }
    }
}

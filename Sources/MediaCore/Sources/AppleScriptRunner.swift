// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Esegue gli AppleScript uno alla volta: `NSAppleScript` non è thread-safe.
actor AppleScriptRunner {
    static let shared = AppleScriptRunner()

    struct ScriptError: Error, Equatable {
        var number: Int
        var message: String

        var isPermissionDenied: Bool { number == Int(errAEEventNotPermitted) }
    }

    private var compiled: [String: NSAppleScript] = [:]

    /// Esegue `source` e trasforma il risultato in un valore `Sendable` dentro l'attore.
    func run<T: Sendable>(_ source: String, parse: @Sendable (NSAppleEventDescriptor) -> T) throws(ScriptError) -> T {
        let script: NSAppleScript
        if let cached = compiled[source] {
            script = cached
        } else {
            guard let created = NSAppleScript(source: source) else {
                throw ScriptError(number: -1, message: "script non valido")
            }
            script = created
            compiled[source] = created
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            throw ScriptError(
                number: error[NSAppleScript.errorNumber] as? Int ?? -1,
                message: error[NSAppleScript.errorMessage] as? String ?? "errore sconosciuto")
        }
        return parse(result)
    }
}

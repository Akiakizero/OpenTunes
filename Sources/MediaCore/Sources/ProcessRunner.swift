// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Synchronization

/// Esegue un processo breve e ne raccoglie l'output, con timeout.
enum ProcessRunner {
    struct Result: Sendable {
        var status: Int32
        var stdout: Data
        var stderr: Data
        var timedOut: Bool
    }

    static func run(_ executable: URL, arguments: [String], timeout: Duration) async throws -> Result {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice

        let outData = Mutex(Data()), errData = Mutex(Data())
        out.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            outData.withLock { $0.append(d) }
        }
        err.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            errData.withLock { $0.append(d) }
        }

        // Un riferimento Sendable (e non un `Mutex` locale) si può catturare nel task del timeout.
        let timedOut = TimeoutFlag()
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { p in continuation.resume(returning: p.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
                return
            }
            let pid = process.processIdentifier
            // Il task cattura solo il pid (`Process` non è Sendable): `terminate()` equivale a SIGTERM.
            Task.detached {
                try? await Task.sleep(for: timeout)
                if kill(pid, 0) == 0 {
                    timedOut.value.withLock { $0 = true }
                    kill(pid, SIGTERM)
                }
            }
        }

        out.fileHandleForReading.readabilityHandler = nil
        err.fileHandleForReading.readabilityHandler = nil
        let restOut = (try? out.fileHandleForReading.readToEnd()) ?? nil
        let restErr = (try? err.fileHandleForReading.readToEnd()) ?? nil
        if let restOut { outData.withLock { $0.append(restOut) } }
        if let restErr { errData.withLock { $0.append(restErr) } }
        return Result(
            status: status,
            stdout: outData.withLock { $0 },
            stderr: errData.withLock { $0 },
            timedOut: timedOut.value.withLock { $0 })
    }
}

private final class TimeoutFlag: Sendable {
    let value = Mutex(false)
}

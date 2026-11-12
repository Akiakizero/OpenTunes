// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Synchronization

/// Sorgente basata su mediaremote-adapter (`/usr/bin/perl mediaremote-adapter.pl … stream`).
///
/// Copre qualsiasi player che pubblica il Now Playing di sistema (Musica, Spotify, browser…).
/// Regole dal README dell'adapter: stderr = errori non fatali; dopo exit ≠ 0 **non** si
/// rilancia lo script — lo stream termina e lo store passa al fallback.
public final class MediaRemoteSource: MediaSource {
    public let id = "mediaremote"
    private let resources: AdapterResources?
    private let log: SourceLogger
    private let testTimeout: Duration
    private let testAttempts: Int
    private let availability = Mutex<Bool?>(nil)
    private let running = Mutex<Process?>(nil)

    /// Opzioni di `stream`: µs per un timestamp preciso, piccolo debounce contro le raffiche,
    /// fix sperimentale per TIDAL (applicato solo quando il player è `com.tidal.desktop`).
    public static let streamArguments = [
        "stream", "--micros", "--debounce=30",
        "--experimental-peculiar-debounce:com.tidal.desktop=1000",
    ]

    public init(
        resources: AdapterResources? = .inBundle(),
        testTimeout: Duration = .seconds(10),
        testAttempts: Int = 3,
        log: @escaping SourceLogger = { _, _ in }
    ) {
        self.resources = resources
        self.testTimeout = testTimeout
        self.testAttempts = max(1, testAttempts)
        self.log = log
    }

    deinit { stop() }

    /// Esegue `test` una volta e ricorda il risultato (il test può creare per un attimo
    /// una voce Now Playing fittizia, quindi non va ripetuto).
    public func isAvailable() async -> Bool {
        if let cached = availability.withLock({ $0 }) { return cached }
        guard let resources else {
            log(id, "risorse dell'adapter non trovate nel bundle")
            availability.withLock { $0 = false }
            return false
        }
        // Fino a 3 tentativi: su macOS 27.2.1 il primo `test` ad avvio a freddo può uscire con 4
        // (nessun dato dal test client) e i successivi con 0. Il retry vale solo per `test`,
        // lo stream non viene mai rilanciato.
        var ok = false
        for attempt in 1...testAttempts {
            do {
                let result = try await ProcessRunner.run(
                    AdapterResources.perl, arguments: resources.arguments(["test"]), timeout: testTimeout)
                ok = result.status == 0 && !result.timedOut
                let err = String(decoding: result.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                log(id, "test (tentativo \(attempt)/\(testAttempts)): exit \(result.status)\(result.timedOut ? " (timeout)" : "")\(err.isEmpty ? "" : " — \(err)")")
            } catch {
                log(id, "test: impossibile avviare perl — \(error)")
                ok = false
                break
            }
            if ok { break }
            if attempt < testAttempts { try? await Task.sleep(for: .seconds(1)) }
        }
        availability.withLock { $0 = ok }
        return ok
    }

    public func updates() -> AsyncStream<NowPlayingSnapshot> {
        let (stream, continuation) = AsyncStream<NowPlayingSnapshot>.makeStream(bufferingPolicy: .bufferingNewest(16))
        guard let resources else {
            continuation.finish()
            return stream
        }
        let (chunks, chunkContinuation) = AsyncStream<Data>.makeStream()
        let process = Process()
        process.executableURL = AdapterResources.perl
        process.arguments = resources.arguments(Self.streamArguments)
        process.standardInput = FileHandle.nullDevice
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err

        let id = self.id, log = self.log
        out.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                chunkContinuation.yield(data)
            }
        }
        let errLines = Mutex(LineBuffer())
        err.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            for line in errLines.withLock({ $0.append(data) }) {
                log(id, "stderr: \(String(decoding: line, as: UTF8.self))")
            }
        }
        process.terminationHandler = { p in
            log(id, "stream terminato (exit \(p.terminationStatus)); l'adapter non viene rilanciato")
            chunkContinuation.finish()
        }

        let consumer = Task {
            var decoder = AdapterStreamDecoder(sourceID: id)
            for await chunk in chunks {
                let (snapshots, errors) = decoder.consume(chunk)
                for e in errors { log(id, e) }
                for s in snapshots { continuation.yield(s) }
            }
            continuation.finish()
        }
        continuation.onTermination = { [weak self] _ in
            consumer.cancel()
            self?.stop()
        }

        do {
            try process.run()
            running.withLock { $0 = process }
            log(id, "stream avviato (pid \(process.processIdentifier))")
        } catch {
            log(id, "impossibile avviare lo stream: \(error)")
            chunkContinuation.finish()
        }
        return stream
    }

    public func send(_ command: MediaCommand) async throws {
        guard let resources else { throw MediaSourceError.unavailable("risorse dell'adapter mancanti") }
        let result = try await ProcessRunner.run(
            AdapterResources.perl, arguments: resources.arguments(Self.arguments(for: command)),
            timeout: .seconds(5))
        guard result.status == 0, !result.timedOut else {
            let err = String(decoding: result.stderr, as: UTF8.self)
            throw MediaSourceError.commandFailed("exit \(result.status) \(err)")
        }
    }

    /// Mappa i comandi sugli ID di `send` (tabella del README), su `seek` in µs o su `shuffle`/`repeat`.
    public static func arguments(for command: MediaCommand) -> [String] {
        switch command {
        case .play: ["send", "0"]
        case .pause: ["send", "1"]
        case .togglePlayPause: ["send", "2"]
        case .nextTrack: ["send", "4"]
        case .previousTrack: ["send", "5"]
        case .seek(let seconds): ["seek", String(Int64(max(0, seconds) * 1_000_000))]
        case .setShuffle(let mode): ["shuffle", String(mode.rawValue)]
        case .setRepeat(let mode): ["repeat", String(mode.rawValue)]
        }
    }

    public func stop() {
        if let process = running.withLock({ p -> Process? in defer { p = nil }; return p }), process.isRunning {
            process.terminate()
        }
    }
}

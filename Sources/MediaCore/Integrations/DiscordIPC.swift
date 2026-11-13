// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os

/// Discord Rich Presence tramite l'IPC locale del client Discord (socket Unix `discord-ipc-0…9` nella cartella
/// temporanea dell'utente). Niente rete e niente token: Discord mostra «Sta ascoltando …» solo se è aperto.
///
/// Protocollo (documentato da Discord per l'RPC): ogni messaggio è `opcode` (UInt32 LE) + lunghezza (UInt32 LE) + JSON.
/// Si apre con l'handshake (`opcode` 0, `client_id`), poi `SET_ACTIVITY` (`opcode` 1). Scritto da zero.
public enum DiscordFrame {
    public enum Opcode: UInt32, Sendable {
        case handshake = 0, frame = 1, close = 2, ping = 3, pong = 4
    }

    public static func encode(_ opcode: Opcode, json: Data) -> Data {
        var data = Data(capacity: 8 + json.count)
        withUnsafeBytes(of: opcode.rawValue.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(json.count).littleEndian) { data.append(contentsOf: $0) }
        data.append(json)
        return data
    }

    /// Primo messaggio completo in `buffer`: opcode, JSON e byte consumati. `nil` se mancano ancora dati.
    public static func decode(_ buffer: Data) -> (opcode: UInt32, json: Data, length: Int)? {
        guard buffer.count >= 8 else { return nil }
        let bytes = [UInt8](buffer.prefix(8))
        let opcode = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        let length = Int(UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24)
        guard buffer.count >= 8 + length else { return nil }
        let start = buffer.startIndex + 8
        return (opcode, buffer.subdata(in: start..<start + length), 8 + length)
    }

    public static func setActivity(_ activity: DiscordActivity?, pid: Int32) -> Data {
        var args: [String: Any] = ["pid": Int(pid)]
        args["activity"] = activity?.json ?? NSNull()
        let message: [String: Any] = ["cmd": "SET_ACTIVITY", "args": args, "nonce": UUID().uuidString]
        return (try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])) ?? Data()
    }

    public static func handshake(clientID: String) -> Data {
        (try? JSONSerialization.data(withJSONObject: ["v": 1, "client_id": clientID], options: [.sortedKeys])) ?? Data()
    }
}

/// Attività «Sta ascoltando» (tipo 2) con titolo, artista, album, tempi e copertina (URL https o chiave di un asset).
public struct DiscordActivity: Sendable, Equatable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var start: Date?
    public var end: Date?
    public var artworkURL: URL?
    public var link: URL?

    public init(title: String, artist: String?, album: String?, start: Date?, end: Date?, artworkURL: URL?, link: URL?) {
        self.title = title
        self.artist = artist
        self.album = album
        self.start = start
        self.end = end
        self.artworkURL = artworkURL
        self.link = link
    }

    /// Discord vuole stringhe di 2…128 caratteri.
    static func clip(_ text: String) -> String {
        let value = text.count < 2 ? text + "  " : text
        return String(value.prefix(128))
    }

    public var json: [String: Any] {
        var activity: [String: Any] = ["type": 2, "details": Self.clip(title)]
        if let artist, !artist.isEmpty { activity["state"] = Self.clip(artist) }
        var timestamps: [String: Any] = [:]
        if let start { timestamps["start"] = Int(start.timeIntervalSince1970 * 1000) }
        if let end { timestamps["end"] = Int(end.timeIntervalSince1970 * 1000) }
        if !timestamps.isEmpty { activity["timestamps"] = timestamps }
        var assets: [String: Any] = ["large_image": artworkURL?.absoluteString ?? "opentunes"]
        if let album, !album.isEmpty { assets["large_text"] = Self.clip(album) }
        activity["assets"] = assets
        if let link { activity["buttons"] = [["label": "song.link", "url": link.absoluteString]] }
        return activity
    }
}

/// Connessione al client Discord. Un attore: socket e stato non escono da qui.
public actor DiscordPresence {
    public enum State: Sendable, Equatable {
        case disconnected
        case connected
        case failed(String)
    }

    private let clientID: String
    private var socket: Int32 = -1
    public private(set) var state: State = .disconnected
    private let logger = Logger(subsystem: "org.opentunes.OpenTunes", category: "Discord")

    public init(clientID: String) {
        self.clientID = clientID
    }

    /// Mostra l'attività (o la toglie con `nil`). Si collega al primo uso e riprova se Discord è stato riaperto.
    public func update(_ activity: DiscordActivity?) {
        if socket < 0, !connect() { return }
        let payload = DiscordFrame.encode(.frame, json: DiscordFrame.setActivity(activity, pid: getpid()))
        if !write(payload) {
            // Discord chiuso nel frattempo: un nuovo tentativo con una connessione nuova.
            close()
            if connect() { _ = write(payload) }
        }
        drain()
    }

    public func clear() {
        if socket >= 0 { update(nil) }
    }

    public func close() {
        if socket >= 0 {
            _ = Darwin.close(socket)
            socket = -1
        }
        if state == .connected { state = .disconnected }
    }

    private func connect() -> Bool {
        for path in Self.socketPaths() {
            let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { continue }
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let capacity = MemoryLayout.size(ofValue: address.sun_path)
            guard path.utf8.count < capacity else {
                _ = Darwin.close(fd)
                continue
            }
            withUnsafeMutableBytes(of: &address.sun_path) { raw in
                raw.copyBytes(from: Array(path.utf8) + [0])
            }
            let length = socklen_t(MemoryLayout<sockaddr_un>.size)
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, length) }
            }
            guard result == 0 else {
                _ = Darwin.close(fd)
                continue
            }
            var noSigPipe: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            // Letture senza blocco: le risposte di Discord si scartano.
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
            socket = fd
            guard write(DiscordFrame.encode(.handshake, json: DiscordFrame.handshake(clientID: clientID))) else {
                close()
                continue
            }
            state = .connected
            logger.info("Discord collegato (\(path, privacy: .public))")
            return true
        }
        state = .failed(String(localized: "Discord non è aperto"))
        return false
    }

    private func write(_ data: Data) -> Bool {
        guard socket >= 0 else { return false }
        return data.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let sent = Darwin.send(socket, raw.baseAddress! + offset, raw.count - offset, 0)
                if sent <= 0 {
                    if errno == EAGAIN { usleep(2_000); continue }
                    return false
                }
                offset += sent
            }
            return true
        }
    }

    /// Scarta le risposte (READY, esiti di SET_ACTIVITY) per non riempire il buffer del socket.
    private func drain() {
        guard socket >= 0 else { return }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while Darwin.recv(socket, &buffer, buffer.count, 0) > 0 {}
    }

    /// `$TMPDIR/discord-ipc-N` (Discord, anche da Homebrew) e le varianti in sandbox note.
    static func socketPaths() -> [String] {
        let tmp = ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory()
        let base = tmp.hasSuffix("/") ? tmp : tmp + "/"
        return (0..<10).map { "\(base)discord-ipc-\($0)" }
    }
}

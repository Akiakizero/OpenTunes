// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Valore JSON semplice di un payload dell'adapter. `null` è distinto da "chiave assente".
public enum AdapterValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    /// Oggetti o array annidati: non usati dall'adapter, conservati come JSON grezzo.
    case other(String)

    init(_ any: Any) {
        switch any {
        case is NSNull: self = .null
        case let n as NSNumber where CFGetTypeID(n) == CFBooleanGetTypeID(): self = .bool(n.boolValue)
        case let n as NSNumber: self = .number(n.doubleValue)
        case let s as String: self = .string(s)
        default:
            let data = (try? JSONSerialization.data(withJSONObject: any, options: [.fragmentsAllowed])) ?? Data()
            self = .other(String(decoding: data, as: UTF8.self))
        }
    }

    var string: String? { if case .string(let s) = self { s } else { nil } }
    var double: Double? { if case .number(let n) = self { n } else { nil } }
    var bool: Bool? {
        switch self {
        case .bool(let b): b
        case .number(let n): n != 0
        default: nil
        }
    }
}

/// Payload "now playing" dell'adapter (chiavi documentate nel README di mediaremote-adapter).
public struct AdapterPayload: Sendable, Equatable {
    public private(set) var values: [String: AdapterValue]

    public init(_ values: [String: AdapterValue] = [:]) {
        self.values = values.filter { $0.value != .null }
    }

    public subscript(key: String) -> AdapterValue? { values[key] }

    public var isEmpty: Bool { values.isEmpty }

    /// Applica un diff: le chiavi presenti sovrascrivono, quelle a `null` vengono rimosse.
    public mutating func apply(diff: [String: AdapterValue]) {
        for (key, value) in diff {
            if value == .null { values.removeValue(forKey: key) } else { values[key] = value }
        }
    }
}

/// Un messaggio di `stream`: `{"type":"data","diff":Bool,"payload":{…}}`.
public struct AdapterMessage: Sendable, Equatable {
    public var type: String
    public var diff: Bool
    public var payload: [String: AdapterValue]

    public enum DecodeError: Error, Equatable {
        case notJSONObject
        case missingPayload
    }

    public init(type: String = "data", diff: Bool, payload: [String: AdapterValue]) {
        self.type = type
        self.diff = diff
        self.payload = payload
    }

    public static func decode(line: Data) throws -> AdapterMessage {
        guard let object = try JSONSerialization.jsonObject(with: line, options: [.fragmentsAllowed]) as? [String: Any] else {
            throw DecodeError.notJSONObject
        }
        guard let rawPayload = object["payload"] as? [String: Any] else {
            throw DecodeError.missingPayload
        }
        return AdapterMessage(
            type: object["type"] as? String ?? "data",
            diff: (object["diff"] as? Bool) ?? false,
            payload: rawPayload.mapValues(AdapterValue.init))
    }
}

/// Trasforma le righe di `stream` nello stato corrente, applicando i diff.
public struct AdapterStreamDecoder: Sendable {
    public private(set) var current = AdapterPayload()
    private var lines = LineBuffer()
    public let sourceID: String

    public init(sourceID: String) {
        self.sourceID = sourceID
    }

    /// Consuma un chunk di stdout e restituisce uno snapshot per ogni messaggio valido.
    /// Le righe non decodificabili sono restituite in `errors`.
    public mutating func consume(_ chunk: Data) -> (snapshots: [NowPlayingSnapshot], errors: [String]) {
        var snapshots: [NowPlayingSnapshot] = []
        var errors: [String] = []
        for line in lines.append(chunk) {
            do {
                snapshots.append(apply(try AdapterMessage.decode(line: line)))
            } catch {
                errors.append("riga non valida (\(line.count) byte): \(error)")
            }
        }
        return (snapshots, errors)
    }

    public mutating func apply(_ message: AdapterMessage) -> NowPlayingSnapshot {
        if message.diff {
            current.apply(diff: message.payload)
        } else {
            current = AdapterPayload(message.payload)
        }
        return Self.snapshot(from: current, sourceID: sourceID)
    }

    /// Converte un payload completo in snapshot. Accetta sia le chiavi normali sia quelle `--micros`.
    public static func snapshot(from payload: AdapterPayload, sourceID: String) -> NowPlayingSnapshot {
        guard let title = payload["title"]?.string, !title.isEmpty else {
            return .empty(sourceID: sourceID)
        }
        let bundleID = payload["parentApplicationBundleIdentifier"]?.string
            ?? payload["bundleIdentifier"]?.string ?? ""

        let duration = payload["durationMicros"]?.double.map { $0 / 1_000_000 }
            ?? payload["duration"]?.double
        let elapsed = payload["elapsedTimeMicros"]?.double.map { $0 / 1_000_000 }
            ?? payload["elapsedTime"]?.double ?? 0
        let timestamp: Date =
            payload["timestampEpochMicros"]?.double.map { Date(timeIntervalSince1970: $0 / 1_000_000) }
            ?? payload["timestamp"]?.string.flatMap(parseISODate)
            ?? .now

        let artwork = payload["artworkData"]?.string.flatMap {
            Data(base64Encoded: $0, options: .ignoreUnknownCharacters)
        }
        let track = Track(
            title: title,
            artist: payload["artist"]?.string,
            album: payload["album"]?.string,
            duration: (duration ?? 0) > 0 ? duration : nil,
            artworkData: artwork,
            playerBundleID: bundleID)

        let playing = payload["playing"]?.bool ?? false
        let rate = payload["playbackRate"]?.double
        let playback = PlaybackState(
            isPlaying: playing,
            elapsedTime: elapsed,
            timestamp: timestamp,
            playbackRate: (rate ?? 0) > 0 ? rate! : 1,
            shuffle: payload["shuffleMode"]?.double.flatMap { ShuffleMode(rawValue: Int($0)) },
            repeatMode: payload["repeatMode"]?.double.flatMap { RepeatMode(rawValue: Int($0)) })
        return NowPlayingSnapshot(track: track, playback: playback, sourceID: sourceID)
    }

    static func parseISODate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

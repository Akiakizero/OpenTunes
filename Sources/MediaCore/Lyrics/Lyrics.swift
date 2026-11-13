// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Testo di un brano: righe sincronizzate (LRC) se disponibili, altrimenti solo il testo semplice.
public struct Lyrics: Sendable, Equatable, Codable {
    public struct Line: Sendable, Equatable, Codable, Identifiable {
        /// Posizione nell'elenco (stabile per il brano: serve a `ScrollViewReader`).
        public var id: Int
        /// Istante d'inizio della riga in secondi.
        public var time: TimeInterval
        public var text: String

        public init(id: Int, time: TimeInterval, text: String) {
            self.id = id
            self.time = time
            self.text = text
        }
    }

    /// Righe ordinate per tempo; vuoto se il testo non è sincronizzato.
    public var lines: [Line]
    public var plain: String?
    public var isInstrumental: Bool

    public init(lines: [Line] = [], plain: String? = nil, isInstrumental: Bool = false) {
        self.lines = lines
        self.plain = plain
        self.isInstrumental = isInstrumental
    }

    public var isSynced: Bool { !lines.isEmpty }

    /// Indice della riga in corso a `position` secondi (`nil` prima della prima riga o senza sincronia).
    public func lineIndex(at position: TimeInterval) -> Int? {
        guard let first = lines.first, position >= first.time else { return nil }
        // Ricerca binaria: l'ultima riga con `time <= position`.
        var low = 0, high = lines.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lines[mid].time <= position { low = mid } else { high = mid - 1 }
        }
        return low
    }

    /// Testo della riga in corso (righe vuote = pausa strumentale, restituite come stringa vuota).
    public func line(at position: TimeInterval) -> String? {
        lineIndex(at: position).map { lines[$0].text }
    }
}

/// Parser del formato LRC: `[mm:ss.xx] testo`, più marcatori sulla stessa riga, tag `[offset:±ms]`.
///
/// Il formato è quello descritto su Wikipedia («LRC (file format)») e usato da LRCLIB; codice scritto da zero
/// (l'idea di un parser minimale viene da Mooziac, MIT).
public enum LRCParser {
    public static func parse(_ text: String) -> [Lyrics.Line] {
        var offset: TimeInterval = 0
        var stamped: [(TimeInterval, String)] = []
        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            var rest = Substring(rawLine).trimmingCharacters(in: .whitespaces)[...]
            var times: [TimeInterval] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                if let time = timestamp(tag) {
                    times.append(time)
                } else if tag.lowercased().hasPrefix("offset:"), let ms = Double(tag.dropFirst("offset:".count).trimmingCharacters(in: .whitespaces)) {
                    // Offset positivo = il testo arriva prima.
                    offset = ms / 1000
                }
                rest = rest[rest.index(after: close)...]
            }
            let lyric = rest.trimmingCharacters(in: .whitespaces)
            for time in times { stamped.append((time, lyric)) }
        }
        return stamped
            .map { (max(0, $0.0 - offset), $0.1) }
            .sorted { $0.0 < $1.0 }
            .enumerated()
            .map { Lyrics.Line(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }

    /// `mm:ss`, `mm:ss.xx` o `mm:ss.xxx`; `nil` per i tag di metadati (`ar:`, `ti:`…).
    static func timestamp(_ tag: Substring) -> TimeInterval? {
        let parts = tag.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let minutes = Int(parts[0]), let seconds = Double(parts[1].replacingOccurrences(of: ",", with: ".")),
            minutes >= 0, seconds >= 0, seconds < 60
        else { return nil }
        return TimeInterval(minutes * 60) + seconds
    }
}

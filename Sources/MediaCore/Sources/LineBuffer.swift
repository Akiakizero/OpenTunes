// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Accumula byte e restituisce le righe complete (separate da `\n`).
///
/// Lavora su `Data`: un carattere UTF-8 spezzato tra due chunk non viene perso.
public struct LineBuffer: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func append(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            var line = buffer[buffer.startIndex..<newline]
            if line.last == 0x0D { line = line.dropLast() }
            if !line.isEmpty { lines.append(Data(line)) }
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        return lines
    }

    /// Byte rimasti senza `\n` finale.
    public var pending: Int { buffer.count }
}

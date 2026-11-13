// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// JSON generico e `Sendable`, per le risposte irregolari di Last.fm
/// (es. un oggetto singolo al posto di un array con un solo elemento, numeri come stringhe).
public enum JSONValue: Sendable, Equatable, Decodable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public static func parse(_ data: Data) -> JSONValue? {
        try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let object) = self { return object[key] }
        return nil
    }

    /// Testo: stringhe, numeri e oggetti `{"#text": …}` di Last.fm.
    public var string: String? {
        switch self {
        case .string(let s): s
        case .number(let n): n.rounded() == n ? String(Int(n)) : String(n)
        case .bool(let b): b ? "1" : "0"
        case .object(let o): o["#text"]?.string
        default: nil
        }
    }

    /// Testo non vuoto.
    public var text: String? {
        string.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var int: Int? {
        switch self {
        case .number(let n): Int(n)
        case .string(let s): Int(s)
        case .bool(let b): b ? 1 : 0
        default: nil
        }
    }

    /// Elementi: un array resta tale, un valore singolo diventa un array di un elemento.
    public var list: [JSONValue] {
        switch self {
        case .array(let a): a
        case .null: []
        default: [self]
        }
    }
}

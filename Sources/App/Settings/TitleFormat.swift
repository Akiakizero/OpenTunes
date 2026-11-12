// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Formato del testo in menu bar, es. `{artist} — {title}`.
///
/// Segnaposto: `{title}`, `{artist}`, `{album}`. Un testo fisso tra due segnaposto compare solo
/// se entrambi hanno un valore, così `{artist} — {title}` senza artista diventa solo il titolo.
struct TitleFormat: Equatable, Sendable {
    enum Token: String, CaseIterable, Sendable {
        case title, artist, album
    }

    enum Part: Equatable, Sendable {
        case literal(String)
        case token(Token)
    }

    let template: String
    let parts: [Part]

    init(_ template: String) {
        self.template = template
        self.parts = Self.parse(template)
    }

    static let presets: [TitleFormat] = [
        TitleFormat("{artist} — {title}"),
        TitleFormat("{title} — {artist}"),
        TitleFormat("{title}"),
        TitleFormat("{title} · {album}"),
    ]

    func render(title: String, artist: String?, album: String?) -> String {
        func value(_ token: Token) -> String {
            let raw: String? = switch token {
            case .title: title
            case .artist: artist
            case .album: album
            }
            return raw?.trimmingCharacters(in: .whitespaces) ?? ""
        }
        var output = ""
        for (index, part) in parts.enumerated() {
            switch part {
            case .token(let token):
                output += value(token)
            case .literal(let text):
                // Il testo fisso resta solo se i segnaposto vicini (se esistono) sono pieni.
                let before = parts[..<index].last { if case .token = $0 { true } else { false } }
                let after = parts[(index + 1)...].first { if case .token = $0 { true } else { false } }
                let beforeOK = before.map { if case .token(let t) = $0 { !value(t).isEmpty } else { true } } ?? true
                let afterOK = after.map { if case .token(let t) = $0 { !value(t).isEmpty } else { true } } ?? true
                if beforeOK && afterOK { output += text }
            }
        }
        let trimmed = output.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? title : trimmed
    }

    static func parse(_ template: String) -> [Part] {
        var parts: [Part] = []
        var literal = ""
        var rest = Substring(template)
        while !rest.isEmpty {
            if rest.first == "{", let close = rest.firstIndex(of: "}"),
                let token = Token(rawValue: String(rest[rest.index(after: rest.startIndex)..<close]).lowercased())
            {
                if !literal.isEmpty { parts.append(.literal(literal)); literal = "" }
                parts.append(.token(token))
                rest = rest[rest.index(after: close)...]
            } else {
                literal.append(rest.removeFirst())
            }
        }
        if !literal.isEmpty { parts.append(.literal(literal)) }
        return parts
    }
}

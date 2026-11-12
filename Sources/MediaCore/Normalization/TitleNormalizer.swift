// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Ripulisce i titoli "sporchi" che arrivano dai browser (YouTube e simili).
///
/// Esempi: `Artista - Titolo (Official Video)` con artista = nome del canale diventa
/// titolo `Titolo`, artista `Artista`. Si applica solo ai browser: i player musicali
/// forniscono già metadati puliti.
public enum TitleNormalizer {
    /// Suffissi rumorosi tra parentesi tonde o quadre (confronto senza maiuscole).
    static let noisePatterns: [String] = [
        #"official\s+(music\s+)?(video|audio|lyric(s)?\s+video|visuali[sz]er)"#,
        #"(music|lyric(s)?)\s+video"#,
        #"lyrics?"#,
        #"audio(\s+ufficiale)?"#,
        #"video\s+ufficiale"#,
        #"official"#,
        #"hd|hq|4k"#,
        #"visuali[sz]er"#,
        #"remaster(ed)?(\s+\d{4})?"#,
    ]

    private static let noiseRegex: NSRegularExpression = {
        let alternatives = noisePatterns.joined(separator: "|")
        // Un gruppo tra () o [] che contiene solo una delle voci rumorose.
        let pattern = #"\s*[\(\[]\s*(?:"# + alternatives + #")\s*[\)\]]"#
        // Il pattern è costante: se non compila è un errore di programmazione.
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// Suffissi dei nomi dei canali che non sono il nome dell'artista.
    static let channelSuffixes = [" - Topic", "VEVO", " Official", " - Official"]

    /// Separatori "Artista - Titolo" accettati (trattino, en dash, em dash, barra verticale).
    static let separators = [" - ", " – ", " — ", " | "]

    public static func normalize(_ track: Track, isBrowser: Bool) -> Track {
        guard isBrowser else { return track }
        var result = track
        var title = stripNoise(track.title)
        var artist = track.artist.map(cleanChannel)

        if let (left, right) = split(title) {
            // "Artista - Titolo": l'artista dal titolo vince sul nome del canale.
            artist = left
            title = right
        }
        result.title = title.isEmpty ? track.title : title
        result.artist = (artist?.isEmpty ?? true) ? nil : artist
        return result
    }

    static func stripNoise(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let stripped = noiseRegex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanChannel(_ name: String) -> String {
        var value = name
        for suffix in channelSuffixes where value.hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count))
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Divide al primo separatore se entrambe le parti sono non vuote.
    static func split(_ title: String) -> (String, String)? {
        for separator in separators {
            guard let range = title.range(of: separator) else { continue }
            let left = title[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            let right = title[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if !left.isEmpty, !right.isEmpty { return (left, right) }
        }
        return nil
    }
}

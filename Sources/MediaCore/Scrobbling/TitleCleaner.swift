// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Pulisce titoli, album e album artist prima dell'invio a Last.fm/ListenBrainz ("scrobble puliti").
///
/// Esempi: `Let It Be (Remastered 2009)` → `Let It Be`, `Song - Radio Edit` → `Song`,
/// `Album - Single` → `Album`, album artist `Various Artists` → nessuno.
/// Regole scritte da zero, ispirate al comportamento di web-scrobbler (MIT).
public struct TitleCleaner: Sendable, Equatable {
    public struct Options: Sendable, Equatable {
        /// "(Remastered 2011)", "- 2011 Remaster", "[Remasterizzato]".
        public var removesRemaster: Bool
        /// "- Radio Edit", "(Single Version)", "(Album Version)", "(Mono)"…
        public var removesVersionTags: Bool
        /// "(Official Video)", "[Lyric Video]", "(Audio)".
        public var removesVideoTags: Bool
        /// "(feat. X)", "ft. X" nel titolo. Spento di default: per alcuni utenti fa parte del titolo.
        public var removesFeaturing: Bool
        /// "Various Artists" e simili come album artist vengono tolti; "Album - Single/EP" diventa "Album".
        public var fixesAlbumArtist: Bool

        public init(
            removesRemaster: Bool = true, removesVersionTags: Bool = true, removesVideoTags: Bool = true,
            removesFeaturing: Bool = false, fixesAlbumArtist: Bool = true
        ) {
            self.removesRemaster = removesRemaster
            self.removesVersionTags = removesVersionTags
            self.removesVideoTags = removesVideoTags
            self.removesFeaturing = removesFeaturing
            self.fixesAlbumArtist = fixesAlbumArtist
        }

        public static let none = Options(
            removesRemaster: false, removesVersionTags: false, removesVideoTags: false,
            removesFeaturing: false, fixesAlbumArtist: false)
    }

    public var options: Options

    public init(options: Options = Options()) {
        self.options = options
    }

    // MARK: Regole

    /// Contenuto di un gruppo "(…)" / "[…]" o di un suffisso " - …" che indica una rimasterizzazione.
    static let remasterPatterns = [
        #"(\d{4}\s+)?(digital(ly)?\s+)?remaster(ed|izzato|isé|izado)?(\s+(version|edition|versione))?(\s+\d{4})?"#,
        #"\d{4}\s+(digital\s+)?remaster(ed)?(\s+version)?"#,
        #"remastered\s+in\s+\d{4}"#,
    ]

    static let versionPatterns = [
        #"radio\s+(edit|version|mix)"#,
        #"(single|album|lp|mono|stereo|original)(\s+(version|edit|mix))?"#,
        #"edit"#,
    ]

    static let videoPatterns = TitleNormalizer.noisePatterns + [
        #"audio"#,
        #"video(\s+clip)?"#,
        #"clip\s+officiel"#,
    ]

    /// Nomi usati come album artist per le compilation.
    static let compilationArtists: Set<String> = [
        "various artists", "various", "va", "v.a.", "v/a", "artisti vari", "artistes divers", "varios artistas",
        "verschiedene interpreten", "multi-interprètes",
    ]

    /// Suffissi di Apple Music sui nomi degli album.
    static let albumSuffixes = [" - Single", " - EP"]

    private static func groupRegex(_ patterns: [String]) -> NSRegularExpression {
        let alternatives = patterns.joined(separator: "|")
        let pattern = #"\s*[\(\[]\s*(?:"# + alternatives + #")\s*[\)\]]"#
        // Pattern costanti: se non compilano è un errore di programmazione.
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func dashRegex(_ patterns: [String]) -> NSRegularExpression {
        let alternatives = patterns.joined(separator: "|")
        let pattern = #"\s+[-–—]\s+(?:"# + alternatives + #")\s*$"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static let remasterGroup = groupRegex(remasterPatterns)
    private static let remasterDash = dashRegex(remasterPatterns)
    private static let versionGroup = groupRegex(versionPatterns)
    private static let versionDash = dashRegex(versionPatterns)
    private static let videoGroup = groupRegex(videoPatterns)
    /// "(feat. X)", "[ft. X]", "(featuring X)", "(with X)" tra parentesi.
    private static let featuringGroup = try! NSRegularExpression(
        pattern: #"\s*[\(\[]\s*(feat\.?|ft\.?|featuring|with)\s+[^\)\]]+[\)\]]"#, options: [.caseInsensitive])
    /// "feat. X" senza parentesi, fino alla fine o a un'altra parentesi.
    private static let featuringBare = try! NSRegularExpression(
        pattern: #"\s+(feat\.|ft\.|featuring)\s+[^\(\[]+"#, options: [.caseInsensitive])

    // MARK: Pulizia

    public func clean(_ track: ScrobbleTrack) -> ScrobbleTrack {
        var result = track
        result.title = cleanTitle(track.title)
        if options.removesFeaturing {
            result.artist = Self.trim(Self.replace(Self.featuringBare, in: track.artist))
            if result.artist.isEmpty { result.artist = track.artist }
        }
        result.album = track.album.map(cleanAlbum).flatMap { $0.isEmpty ? nil : $0 }
        if options.fixesAlbumArtist, let albumArtist = track.albumArtist {
            let normalized = albumArtist.trimmingCharacters(in: .whitespaces).lowercased()
            if Self.compilationArtists.contains(normalized) || normalized.isEmpty {
                result.albumArtist = nil
            }
        }
        return result
    }

    public func cleanTitle(_ title: String) -> String {
        var value = title
        // Ripete finché cambia: "Song (Remastered) - Radio Edit" ha due suffissi.
        for _ in 0..<4 {
            let before = value
            if options.removesVideoTags { value = Self.replace(Self.videoGroup, in: value) }
            if options.removesRemaster {
                value = Self.replace(Self.remasterGroup, in: value)
                value = Self.replace(Self.remasterDash, in: value)
            }
            if options.removesVersionTags {
                value = Self.replace(Self.versionGroup, in: value)
                value = Self.replace(Self.versionDash, in: value)
            }
            if options.removesFeaturing {
                value = Self.replace(Self.featuringGroup, in: value)
                value = Self.replace(Self.featuringBare, in: value)
            }
            value = Self.trim(value)
            if value == before { break }
        }
        return value.isEmpty ? title : value
    }

    public func cleanAlbum(_ album: String) -> String {
        var value = album
        if options.removesRemaster {
            value = Self.replace(Self.remasterGroup, in: value)
            value = Self.replace(Self.remasterDash, in: value)
        }
        if options.fixesAlbumArtist {
            for suffix in Self.albumSuffixes where value.hasSuffix(suffix) {
                value = String(value.dropLast(suffix.count))
            }
        }
        value = Self.trim(value)
        return value.isEmpty ? album : value
    }

    private static func replace(_ regex: NSRegularExpression, in text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—")))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

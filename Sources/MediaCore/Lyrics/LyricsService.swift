// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

/// Testi da [LRCLIB](https://lrclib.net) (API pubblica, senza chiave): prima `/api/get` con artista, titolo,
/// album e durata, poi `/api/search` se non c'è una corrispondenza esatta.
///
/// I risultati, anche «non trovato», si salvano in una cache su disco (`~/Library/Caches/OpenTunes/lyrics/`):
/// i brani già ascoltati non rifanno la richiesta. Un «non trovato» si ritenta dopo una settimana.
public actor LyricsService {
    public static let shared = LyricsService(cacheDirectory: LyricsService.defaultCacheDirectory)

    public static var defaultCacheDirectory: URL {
        URL.cachesDirectory.appending(path: "OpenTunes/lyrics", directoryHint: .isDirectory)
    }

    public struct Query: Sendable, Hashable {
        public var artist: String
        public var title: String
        public var album: String?
        public var duration: TimeInterval?

        public init(artist: String, title: String, album: String? = nil, duration: TimeInterval? = nil) {
            self.artist = artist
            self.title = title
            self.album = album
            self.duration = duration
        }

        /// Chiave della cache: artista, titolo e durata arrotondata (l'album varia tra player).
        var cacheKey: String {
            let base = "\(artist.lowercased())\u{1F}\(title.lowercased())\u{1F}\(Int((duration ?? 0).rounded()))"
            return SHA256.hash(data: Data(base.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
        }
    }

    /// Voce della cache su disco.
    struct CacheEntry: Codable {
        var lyrics: Lyrics?
        var fetchedAt: Date
    }

    static let notFoundRetry: TimeInterval = 7 * 24 * 3600
    /// Tolleranza sulla durata nei risultati di `/api/search`.
    static let durationTolerance: TimeInterval = 3

    private let cacheDirectory: URL?
    private let transport: HTTPTransport
    private var memory: [String: CacheEntry] = [:]

    public init(cacheDirectory: URL?, transport: @escaping HTTPTransport = HTTP.live) {
        self.cacheDirectory = cacheDirectory
        self.transport = transport
    }

    /// Testo del brano, `nil` se LRCLIB non lo ha. Lancia solo per errori di rete (da non mettere in cache).
    public func lyrics(for query: Query, now: Date = .now) async throws -> Lyrics? {
        let key = query.cacheKey
        if let entry = memory[key] ?? readCache(key), entry.lyrics != nil || now.timeIntervalSince(entry.fetchedAt) < Self.notFoundRetry {
            memory[key] = entry
            return entry.lyrics
        }
        let lyrics = try await fetch(query)
        let entry = CacheEntry(lyrics: lyrics, fetchedAt: now)
        memory[key] = entry
        writeCache(entry, key)
        return lyrics
    }

    /// Svuota la cache (memoria e disco).
    public func clearCache() {
        memory = [:]
        if let cacheDirectory { try? FileManager.default.removeItem(at: cacheDirectory) }
    }

    // MARK: Rete

    private func fetch(_ query: Query) async throws -> Lyrics? {
        if let url = Self.getURL(query) {
            let (data, response) = try await send(url)
            if response.statusCode == 200, let lyrics = Self.parseRecord(data) { return lyrics }
            guard response.statusCode == 404 || response.statusCode == 200 else {
                throw ScrobbleServiceError.temporary("LRCLIB HTTP \(response.statusCode)")
            }
        }
        guard let url = Self.searchURL(query) else { return nil }
        let (data, response) = try await send(url)
        guard response.statusCode == 200 else {
            if response.statusCode == 404 { return nil }
            throw ScrobbleServiceError.temporary("LRCLIB HTTP \(response.statusCode)")
        }
        return Self.bestMatch(in: data, duration: query.duration)
    }

    private func send(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        // LRCLIB chiede un User-Agent che identifichi l'app.
        request.setValue("\(LastFMClient.userAgent) (https://github.com/Akiakizero/OpenTunes)", forHTTPHeaderField: "User-Agent")
        do {
            return try await transport(request)
        } catch {
            throw ScrobbleServiceError.network(error.localizedDescription)
        }
    }

    static func getURL(_ query: Query) -> URL? {
        // `/api/get` vuole tutti e quattro i campi.
        guard let album = query.album, !album.isEmpty, let duration = query.duration, duration > 0 else { return nil }
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "artist_name", value: query.artist),
            URLQueryItem(name: "track_name", value: query.title),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(Int(duration.rounded()))),
        ]
        return components?.url
    }

    static func searchURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: query.title),
            URLQueryItem(name: "artist_name", value: query.artist),
        ]
        return components?.url
    }

    /// Un record di LRCLIB (`syncedLyrics`, `plainLyrics`, `instrumental`).
    static func parseRecord(_ data: Data) -> Lyrics? {
        JSONValue.parse(data).flatMap(lyrics(from:))
    }

    static func lyrics(from record: JSONValue) -> Lyrics? {
        let instrumental = record["instrumental"]?.bool ?? false
        let synced = record["syncedLyrics"]?.text.map(LRCParser.parse) ?? []
        let plain = record["plainLyrics"]?.text.flatMap { $0.isEmpty ? nil : $0 }
        guard instrumental || !synced.isEmpty || plain != nil else { return nil }
        return Lyrics(lines: synced, plain: plain, isInstrumental: instrumental)
    }

    /// Dai risultati di `/api/search`: durata entro la tolleranza, preferendo i testi sincronizzati.
    static func bestMatch(in data: Data, duration: TimeInterval?) -> Lyrics? {
        let records = JSONValue.parse(data)?.list ?? []
        let candidates = records.filter { record in
            guard let duration, let other = record["duration"]?.number else { return true }
            return abs(other - duration) <= durationTolerance
        }
        let ranked = candidates.sorted { a, b in
            (a["syncedLyrics"]?.text != nil ? 0 : 1) < (b["syncedLyrics"]?.text != nil ? 0 : 1)
        }
        return ranked.lazy.compactMap(lyrics(from:)).first
    }

    // MARK: Cache su disco

    private func fileURL(_ key: String) -> URL? {
        cacheDirectory?.appending(path: "\(key).json")
    }

    private func readCache(_ key: String) -> CacheEntry? {
        guard let url = fileURL(key), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CacheEntry.self, from: data)
    }

    private func writeCache(_ entry: CacheEntry, _ key: String) {
        guard let cacheDirectory, let url = fileURL(key), let data = try? JSONEncoder().encode(entry) else { return }
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

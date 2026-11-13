// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Periodo dei grafici di Last.fm (`period` di `user.getTopAlbums`).
public enum LastFMPeriod: String, CaseIterable, Identifiable, Sendable {
    case week = "7day"
    case month = "1month"
    case year = "12month"
    case overall

    public var id: String { rawValue }
}

/// Un album dei top di Last.fm.
public struct LastFMAlbum: Sendable, Equatable, Identifiable {
    public var id: String { "\(artist)\u{1F}\(name)" }
    public var name: String
    public var artist: String
    public var playCount: Int
    public var imageURL: URL?
    public var url: URL?

    public init(name: String, artist: String, playCount: Int, imageURL: URL? = nil, url: URL? = nil) {
        self.name = name
        self.artist = artist
        self.playCount = playCount
        self.imageURL = imageURL
        self.url = url
    }
}

/// Un artista o un brano simile (`artist.getSimilar`, `track.getSimilar`).
public struct LastFMSimilarItem: Sendable, Equatable, Identifiable {
    public var id: String { "\(artist ?? "")\u{1F}\(name)" }
    /// Nome dell'artista o titolo del brano.
    public var name: String
    /// Artista del brano (`nil` per gli artisti simili).
    public var artist: String?
    /// Somiglianza 0…1 secondo Last.fm.
    public var match: Double
    public var url: URL?

    public init(name: String, artist: String? = nil, match: Double, url: URL? = nil) {
        self.name = name
        self.artist = artist
        self.match = match
        self.url = url
    }
}

extension LastFMClient {
    /// Album più ascoltati dall'utente nel periodo.
    public func topAlbums(user: String, period: LastFMPeriod, limit: Int = 25) async throws -> [LastFMAlbum] {
        let json = try await call(
            "user.getTopAlbums", ["user": user, "period": period.rawValue, "limit": "\(limit)"], signed: false, post: false)
        return Self.parseTopAlbums(json)
    }

    public func similarArtists(artist: String, limit: Int = 12) async throws -> [LastFMSimilarItem] {
        let json = try await call(
            "artist.getSimilar", ["artist": artist, "limit": "\(limit)", "autocorrect": "1"], signed: false, post: false)
        return Self.parseSimilarArtists(json)
    }

    public func similarTracks(artist: String, title: String, limit: Int = 12) async throws -> [LastFMSimilarItem] {
        let json = try await call(
            "track.getSimilar", ["artist": artist, "track": title, "limit": "\(limit)", "autocorrect": "1"], signed: false, post: false)
        return Self.parseSimilarTracks(json)
    }

    static func parseTopAlbums(_ json: JSONValue) -> [LastFMAlbum] {
        (json["topalbums"]?["album"]?.list ?? []).compactMap { album in
            guard let name = album["name"]?.text, let artist = album["artist"]?["name"]?.text ?? album["artist"]?.text else { return nil }
            return LastFMAlbum(
                name: name, artist: artist, playCount: album["playcount"]?.int ?? 0,
                imageURL: largestImage(album["image"]), url: album["url"]?.text.flatMap(URL.init(string:)))
        }
    }

    static func parseSimilarArtists(_ json: JSONValue) -> [LastFMSimilarItem] {
        (json["similarartists"]?["artist"]?.list ?? []).compactMap { artist in
            guard let name = artist["name"]?.text else { return nil }
            return LastFMSimilarItem(
                name: name, match: artist["match"]?.number ?? 0, url: artist["url"]?.text.flatMap(URL.init(string:)))
        }
    }

    static func parseSimilarTracks(_ json: JSONValue) -> [LastFMSimilarItem] {
        (json["similartracks"]?["track"]?.list ?? []).compactMap { track in
            guard let name = track["name"]?.text, let artist = track["artist"]?["name"]?.text else { return nil }
            return LastFMSimilarItem(
                name: name, artist: artist, match: track["match"]?.number ?? 0,
                url: track["url"]?.text.flatMap(URL.init(string:)))
        }
    }

    /// L'immagine più grande con un URL (Last.fm le elenca dalla più piccola; quelle vuote si saltano).
    static func largestImage(_ value: JSONValue?) -> URL? {
        value?.list.compactMap { $0.text }.last.flatMap(URL.init(string:))
    }
}

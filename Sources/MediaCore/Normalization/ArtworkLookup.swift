// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Cerca una copertina sull'iTunes Search API quando il player non ne fornisce una
/// (tipico dei browser). Idea vista in PlayStatus; implementazione scritta da zero.
public actor ArtworkLookup {
    public static let shared = ArtworkLookup()

    private var cache: [String: Data?] = [:]
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Restituisce i dati dell'immagine (600×600) o `nil`. I risultati, anche negativi, restano in cache.
    public func artwork(artist: String, title: String) async -> Data? {
        let key = "\(artist)\u{1F}\(title)".lowercased()
        if let cached = cache[key] { return cached }
        let data = await fetch(artist: artist, title: title)
        cache[key] = data
        return data
    }

    static func searchURL(artist: String, title: String) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(title)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        return components?.url
    }

    /// Estrae `artworkUrl100` dal primo risultato e chiede la variante 600×600.
    static func artworkURL(fromSearchResponse data: Data) -> URL? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = object["results"] as? [[String: Any]],
            let small = results.first?["artworkUrl100"] as? String
        else { return nil }
        return URL(string: small.replacingOccurrences(of: "100x100bb", with: "600x600bb"))
    }

    private func fetch(artist: String, title: String) async -> Data? {
        guard let url = Self.searchURL(artist: artist, title: title),
            let (body, _) = try? await session.data(from: url),
            let imageURL = Self.artworkURL(fromSearchResponse: body),
            let (image, response) = try? await session.data(from: imageURL),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return image
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Link universale del brano: una pagina di [song.link / Odesli](https://odesli.co) che si apre nel servizio
/// di chi la riceve (Apple Music, Spotify, YouTube Music…).
///
/// Odesli parte da un link a un servizio: se il player non ne fornisce uno, si cerca il brano sull'iTunes
/// Search API (come per le copertine) e si passa a Odesli il link di Apple Music. Se Odesli non risponde
/// si usa il link di Apple Music così com'è. I risultati restano in memoria per la sessione.
public actor ShareLinkService {
    public static let shared = ShareLinkService()

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case notFound
        case network(String)

        public var description: String {
            switch self {
            case .notFound: "brano non trovato"
            case .network(let message): "rete: \(message)"
            }
        }
    }

    private var cache: [String: URL] = [:]
    private let transport: HTTPTransport

    public init(transport: @escaping HTTPTransport = HTTP.live) {
        self.transport = transport
    }

    /// Link song.link per artista e titolo.
    public func link(artist: String, title: String, country: String? = nil) async throws -> URL {
        let key = "\(artist)\u{1F}\(title)".lowercased()
        if let cached = cache[key] { return cached }
        guard let search = Self.searchURL(artist: artist, title: title, country: country) else {
            throw Failure.notFound
        }
        let storeURL: URL
        do {
            let (data, _) = try await transport(URLRequest(url: search))
            guard let found = Self.storeURL(fromSearchResponse: data) else { throw Failure.notFound }
            storeURL = found
        } catch let failure as Failure {
            throw failure
        } catch {
            throw Failure.network(error.localizedDescription)
        }
        var result = storeURL
        if let odesli = Self.odesliURL(for: storeURL, country: country),
            let (data, response) = try? await transport(URLRequest(url: odesli)), response.statusCode == 200,
            let page = Self.pageURL(fromOdesliResponse: data)
        {
            result = page
        }
        cache[key] = result
        return result
    }

    static func searchURL(artist: String, title: String, country: String?) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        var items = [
            URLQueryItem(name: "term", value: "\(artist) \(title)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        if let country, !country.isEmpty { items.append(URLQueryItem(name: "country", value: country)) }
        components?.queryItems = items
        return components?.url
    }

    /// `trackViewUrl` del primo risultato (senza i parametri di tracciamento `uo`).
    static func storeURL(fromSearchResponse data: Data) -> URL? {
        guard let json = JSONValue.parse(data),
            let first = json["results"]?.list.first,
            let raw = first["trackViewUrl"]?.text,
            var components = URLComponents(string: raw)
        else { return nil }
        components.queryItems = components.queryItems?.filter { $0.name == "i" }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }
        return components.url
    }

    static func odesliURL(for url: URL, country: String?) -> URL? {
        // Il link va codificato per intero (`?`, `=` e `&` compresi): `queryItems` lascerebbe `=` in chiaro.
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        var query = "url=\(encoded)"
        if let country, !country.isEmpty { query += "&userCountry=\(country)" }
        return URL(string: "https://api.song.link/v1-alpha.1/links?\(query)")
    }

    static func pageURL(fromOdesliResponse data: Data) -> URL? {
        JSONValue.parse(data)?["pageUrl"]?.text.flatMap(URL.init(string:))
    }
}

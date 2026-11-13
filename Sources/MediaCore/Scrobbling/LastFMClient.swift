// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

/// Credenziali dell'applicazione Last.fm (API key e secret).
///
/// In un'app open source la secret è di fatto pubblica: chi vuole può usare la propria chiave
/// (impostazioni › Scrobbling). Vedi il README.
public struct LastFMCredentials: Sendable, Equatable {
    public var apiKey: String
    public var secret: String

    public init(apiKey: String, secret: String) {
        self.apiKey = apiKey
        self.secret = secret
    }

    public var isValid: Bool { !apiKey.isEmpty && !secret.isEmpty }

    /// Chiave del progetto, iniettata in build (`LASTFM_API_KEY`, `LASTFM_API_SECRET` → Info.plist).
    public static func bundled(in bundle: Bundle = .main) -> LastFMCredentials? {
        let key = bundle.object(forInfoDictionaryKey: "LastFMAPIKey") as? String ?? ""
        let secret = bundle.object(forInfoDictionaryKey: "LastFMAPISecret") as? String ?? ""
        let credentials = LastFMCredentials(apiKey: key, secret: secret)
        return credentials.isValid ? credentials : nil
    }
}

/// Client dell'API 2.0 di Last.fm: autenticazione desktop, `updateNowPlaying`, `scrobble`
/// (a blocchi di 50), love/unlove e dati del profilo.
///
/// Firma `api_sig` secondo la documentazione di Last.fm (MD5 dei parametri ordinati + secret);
/// struttura delle chiamate studiata da `WebService.swift` di Audioscrobbler (MIT), codice scritto da zero.
public struct LastFMClient: Sendable {
    public static let endpoint = URL(string: "https://ws.audioscrobbler.com/2.0/")!
    /// Last.fm accetta fino a 50 scrobble per richiesta.
    public static let maxBatch = 50

    public var credentials: LastFMCredentials
    public var sessionKey: String?
    private let transport: HTTPTransport

    public init(credentials: LastFMCredentials, sessionKey: String? = nil, transport: @escaping HTTPTransport = HTTP.live) {
        self.credentials = credentials
        self.sessionKey = sessionKey
        self.transport = transport
    }

    /// Errore restituito dall'API (`{"error": 9, "message": "…"}`).
    public struct APIError: Error, Equatable, Sendable {
        public var code: Int
        public var message: String

        /// 14: token non ancora autorizzato dall'utente (si continua ad aspettare).
        public var isTokenPending: Bool { code == 14 }

        var serviceError: ScrobbleServiceError {
            switch code {
            case 9, 4, 14, 15: .unauthorized("\(message) (\(code))")
            case 10, 26: .notConfigured("\(message) (\(code))")
            case 8, 11, 16, 29: .temporary("\(message) (\(code))")
            default: .rejected("\(message) (\(code))")
            }
        }
    }

    // MARK: Autenticazione desktop

    /// Passo 1: token da far approvare all'utente nel browser.
    public func getToken() async throws -> String {
        let json = try await call("auth.getToken", [:], signed: true, post: false)
        guard let token = json["token"]?.text else { throw ScrobbleServiceError.rejected("token mancante") }
        return token
    }

    /// Pagina di Last.fm in cui l'utente approva il token.
    public func authorizationURL(token: String) -> URL {
        var components = URLComponents(string: "https://www.last.fm/api/auth/")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: credentials.apiKey),
            URLQueryItem(name: "token", value: token),
        ]
        return components.url!
    }

    /// Passo 2: session key (senza scadenza) dopo l'approvazione. Lancia `APIError` 14 finché l'utente non approva.
    public func getSession(token: String) async throws -> (user: String, key: String) {
        let json = try await callRaw("auth.getSession", ["token": token], signed: true, post: false)
        guard let session = json["session"], let name = session["name"]?.text, let key = session["key"]?.text else {
            throw ScrobbleServiceError.rejected("sessione mancante")
        }
        return (name, key)
    }

    // MARK: Brani

    public func updateNowPlaying(_ track: ScrobbleTrack) async throws {
        var params = ["artist": track.artist, "track": track.title]
        if let album = track.album { params["album"] = album }
        if let albumArtist = track.albumArtist { params["albumArtist"] = albumArtist }
        if let duration = track.duration { params["duration"] = String(Int(duration.rounded())) }
        _ = try await call("track.updateNowPlaying", params, authenticated: true)
    }

    /// Esito di un blocco di scrobble.
    public struct ScrobbleResult: Sendable, Equatable {
        public struct Ignored: Sendable, Equatable {
            /// Posizione nel blocco inviato.
            public var index: Int
            /// 1 artista ignorato, 2 brano ignorato, 3 timestamp troppo vecchio, 4 troppo nuovo, 5 limite giornaliero.
            public var code: Int
            public var message: String

            /// Il limite giornaliero si supera ogni tanto: quegli scrobble vanno ritentati.
            public var isRetryable: Bool { code == 5 }
        }

        public var accepted: Int
        public var ignored: [Ignored]
    }

    /// Invia fino a 50 scrobble in una richiesta.
    public func scrobble(_ tracks: [ScrobbleTrack]) async throws -> ScrobbleResult {
        precondition(tracks.count <= Self.maxBatch, "Last.fm accetta al massimo \(Self.maxBatch) scrobble per richiesta")
        var params: [String: String] = [:]
        for (i, track) in tracks.enumerated() {
            params["artist[\(i)]"] = track.artist
            params["track[\(i)]"] = track.title
            params["timestamp[\(i)]"] = String(Int(track.startedAt.timeIntervalSince1970))
            if let album = track.album { params["album[\(i)]"] = album }
            if let albumArtist = track.albumArtist { params["albumArtist[\(i)]"] = albumArtist }
            if let duration = track.duration { params["duration[\(i)]"] = String(Int(duration.rounded())) }
        }
        let json = try await call("track.scrobble", params, authenticated: true)
        return Self.parseScrobbleResult(json, count: tracks.count)
    }

    static func parseScrobbleResult(_ json: JSONValue, count: Int) -> ScrobbleResult {
        let scrobbles = json["scrobbles"]
        let items = scrobbles?["scrobble"]?.list ?? []
        var ignored: [ScrobbleResult.Ignored] = []
        for (index, item) in items.enumerated() {
            let code = item["ignoredMessage"]?["code"]?.int ?? 0
            if code != 0 {
                ignored.append(.init(index: index, code: code, message: item["ignoredMessage"]?.string ?? ""))
            }
        }
        let accepted = scrobbles?["@attr"]?["accepted"]?.int ?? (count - ignored.count)
        return ScrobbleResult(accepted: accepted, ignored: ignored)
    }

    public func setLoved(_ loved: Bool, artist: String, title: String) async throws {
        _ = try await call(loved ? "track.love" : "track.unlove", ["artist": artist, "track": title], authenticated: true)
    }

    /// `true` se l'utente ha già amato il brano (`track.getInfo` con `username`).
    public func isLoved(artist: String, title: String, user: String) async throws -> Bool {
        let json = try await call(
            "track.getInfo", ["artist": artist, "track": title, "username": user, "autocorrect": "1"],
            signed: false, post: false)
        return json["track"]?["userloved"]?.int == 1
    }

    // MARK: Profilo

    public func profile(user: String, limit: Int = 10) async throws -> LastFMProfile {
        async let info = call("user.getInfo", ["user": user], signed: false, post: false)
        async let recent = call("user.getRecentTracks", ["user": user, "limit": "\(limit)", "extended": "0"], signed: false, post: false)
        async let loved = call("user.getLovedTracks", ["user": user, "limit": "\(limit)"], signed: false, post: false)
        async let top = call("user.getTopArtists", ["user": user, "limit": "\(limit)", "period": "1month"], signed: false, post: false)
        return try await LastFMProfile.parse(info: info, recent: recent, loved: loved, topArtists: top)
    }

    // MARK: Richieste

    /// Firma: parametri ordinati per nome, concatenati come `nomevalore`, più la secret; MD5 esadecimale.
    /// `format` e `callback` non entrano nella firma.
    public static func signature(_ params: [String: String], secret: String) -> String {
        let base = params.filter { $0.key != "format" && $0.key != "callback" }
            .sorted { $0.key < $1.key }
            .map { $0.key + $0.value }
            .joined()
        return Insecure.MD5.hash(data: Data((base + secret).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func request(_ method: String, _ params: [String: String], signed: Bool, post: Bool, authenticated: Bool) throws -> URLRequest {
        guard credentials.isValid else { throw ScrobbleServiceError.notConfigured("API key Last.fm mancante") }
        var all = params
        all["method"] = method
        all["api_key"] = credentials.apiKey
        if authenticated {
            guard let sessionKey else { throw ScrobbleServiceError.unauthorized("nessuna sessione Last.fm") }
            all["sk"] = sessionKey
        }
        if signed || authenticated { all["api_sig"] = Self.signature(all, secret: credentials.secret) }
        all["format"] = "json"
        var request: URLRequest
        if post {
            request = URLRequest(url: Self.endpoint)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = HTTP.formBody(all)
        } else {
            var components = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false)!
            components.queryItems = all.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            // `+` nei valori va codificato: Last.fm lo leggerebbe come spazio.
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            request = URLRequest(url: components.url!)
        }
        request.timeoutInterval = 20
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        return "OpenTunes/\(version)"
    }()

    /// Chiamata con gli errori dell'API già convertiti in `ScrobbleServiceError`.
    private func call(
        _ method: String, _ params: [String: String], signed: Bool = true, post: Bool = true, authenticated: Bool = false
    ) async throws -> JSONValue {
        do {
            return try await callRaw(method, params, signed: signed, post: post, authenticated: authenticated)
        } catch let error as APIError {
            throw error.serviceError
        }
    }

    /// Chiamata che lascia passare `APIError` (serve al polling di `auth.getSession`).
    private func callRaw(
        _ method: String, _ params: [String: String], signed: Bool, post: Bool, authenticated: Bool = false
    ) async throws -> JSONValue {
        let request = try request(method, params, signed: signed, post: post, authenticated: authenticated)
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport(request)
        } catch {
            throw ScrobbleServiceError.network(error.localizedDescription)
        }
        let json = JSONValue.parse(data)
        if let code = json?["error"]?.int {
            throw APIError(code: code, message: json?["message"]?.string ?? "errore \(code)")
        }
        switch response.statusCode {
        case 200..<300:
            guard let json else { throw ScrobbleServiceError.temporary("risposta non valida") }
            return json
        case 429, 500...599: throw ScrobbleServiceError.temporary("HTTP \(response.statusCode)")
        default: throw ScrobbleServiceError.rejected("HTTP \(response.statusCode)")
        }
    }
}

/// Dati del profilo Last.fm mostrati nel popover (salvati in cache su disco).
public struct LastFMProfile: Sendable, Equatable, Codable {
    public struct User: Sendable, Equatable, Codable {
        public var name: String
        public var realName: String?
        public var playCount: Int
        public var registered: Date?
        public var imageURL: URL?
        public var url: URL?
    }

    public struct TrackEntry: Sendable, Equatable, Codable, Identifiable {
        public var id: String { "\(artist)\u{1F}\(title)\u{1F}\(date?.timeIntervalSince1970 ?? 0)" }
        public var artist: String
        public var title: String
        public var imageURL: URL?
        /// `nil` se il brano è in riproduzione ora.
        public var date: Date?
        public var isNowPlaying: Bool
        public var url: URL?
    }

    public struct ArtistEntry: Sendable, Equatable, Codable, Identifiable {
        public var id: String { name }
        public var name: String
        public var playCount: Int
        public var url: URL?
    }

    public var user: User
    public var recent: [TrackEntry]
    public var loved: [TrackEntry]
    public var topArtists: [ArtistEntry]
    public var fetchedAt: Date

    static func parse(info: JSONValue, recent: JSONValue, loved: JSONValue, topArtists: JSONValue, now: Date = .now) throws -> LastFMProfile {
        guard let u = info["user"], let name = u["name"]?.text else { throw ScrobbleServiceError.rejected("profilo mancante") }
        let user = User(
            name: name, realName: u["realname"]?.text, playCount: u["playcount"]?.int ?? 0,
            registered: u["registered"]?["unixtime"]?.int.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            imageURL: image(u["image"]), url: u["url"]?.text.flatMap(URL.init(string:)))
        return LastFMProfile(
            user: user,
            recent: (recent["recenttracks"]?["track"]?.list ?? []).compactMap(trackEntry),
            loved: (loved["lovedtracks"]?["track"]?.list ?? []).compactMap(trackEntry),
            topArtists: (topArtists["topartists"]?["artist"]?.list ?? []).compactMap { a in
                a["name"]?.text.map { ArtistEntry(name: $0, playCount: a["playcount"]?.int ?? 0, url: a["url"]?.text.flatMap(URL.init(string:))) }
            },
            fetchedAt: now)
    }

    private static func trackEntry(_ t: JSONValue) -> TrackEntry? {
        // `recenttracks` usa artist.#text, `lovedtracks` usa artist.name.
        guard let title = t["name"]?.text, let artist = t["artist"]?["name"]?.text ?? t["artist"]?.text else { return nil }
        return TrackEntry(
            artist: artist, title: title, imageURL: image(t["image"]),
            date: t["date"]?["uts"]?.int.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            isNowPlaying: t["@attr"]?["nowplaying"]?.string == "true",
            url: t["url"]?.text.flatMap(URL.init(string:)))
    }

    /// L'immagine più grande tra quelle con URL (Last.fm le elenca dalla più piccola).
    private static func image(_ value: JSONValue?) -> URL? {
        value?.list.compactMap { $0.text }.last.flatMap(URL.init(string:))
    }
}

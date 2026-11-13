// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Client dell'API di ListenBrainz (`submit-listens`, `validate-token`), autenticato con il token utente.
public struct ListenBrainzClient: Sendable {
    public static let baseURL = URL(string: "https://api.listenbrainz.org/1/")!
    /// Blocco usato dalla coda (il servizio ne accetta di più, ma 50 resta allineato a Last.fm).
    public static let maxBatch = 50

    public var token: String
    private let transport: HTTPTransport

    public init(token: String, transport: @escaping HTTPTransport = HTTP.live) {
        self.token = token
        self.transport = transport
    }

    /// Nome utente associato al token, o errore `.unauthorized` se il token non vale.
    public func validateToken() async throws -> String {
        var request = URLRequest(url: Self.baseURL.appending(path: "validate-token"))
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        let json = try await send(request)
        guard json["valid"] == .bool(true), let user = json["user_name"]?.text else {
            throw ScrobbleServiceError.unauthorized(json["message"]?.string ?? "token non valido")
        }
        return user
    }

    public func playingNow(_ track: ScrobbleTrack) async throws {
        _ = try await send(submitRequest(type: "playing_now", tracks: [track]))
    }

    /// Un ascolto = `single`, più ascolti (coda offline) = `import`.
    public func submit(_ tracks: [ScrobbleTrack]) async throws {
        guard !tracks.isEmpty else { return }
        precondition(tracks.count <= Self.maxBatch)
        _ = try await send(submitRequest(type: tracks.count == 1 ? "single" : "import", tracks: tracks))
    }

    func submitRequest(type: String, tracks: [ScrobbleTrack]) throws -> URLRequest {
        guard !token.isEmpty else { throw ScrobbleServiceError.notConfigured("token ListenBrainz mancante") }
        var request = URLRequest(url: Self.baseURL.appending(path: "submit-listens"))
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(
            withJSONObject: Self.payload(type: type, tracks: tracks), options: [.sortedKeys])
        return request
    }

    static func payload(type: String, tracks: [ScrobbleTrack]) -> [String: Any] {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let listens: [[String: Any]] = tracks.map { track in
            var info: [String: Any] = [
                "media_player": PlayerApp.resolve(bundleID: track.playerBundleID).name,
                "submission_client": "OpenTunes",
                "submission_client_version": version,
            ]
            if let duration = track.duration { info["duration_ms"] = Int((duration * 1000).rounded()) }
            if let albumArtist = track.albumArtist { info["release_artist_name"] = albumArtist }
            var metadata: [String: Any] = [
                "artist_name": track.artist, "track_name": track.title, "additional_info": info,
            ]
            if let album = track.album { metadata["release_name"] = album }
            var listen: [String: Any] = ["track_metadata": metadata]
            // `playing_now` non vuole `listened_at`.
            if type != "playing_now" { listen["listened_at"] = Int(track.startedAt.timeIntervalSince1970) }
            return listen
        }
        return ["listen_type": type, "payload": listens]
    }

    private func send(_ request: URLRequest) async throws -> JSONValue {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport(request)
        } catch {
            throw ScrobbleServiceError.network(error.localizedDescription)
        }
        let json = JSONValue.parse(data) ?? .null
        let message = json["error"]?.string ?? json["message"]?.string ?? "HTTP \(response.statusCode)"
        switch response.statusCode {
        case 200..<300: return json
        case 401, 403: throw ScrobbleServiceError.unauthorized(message)
        case 429, 500...599: throw ScrobbleServiceError.temporary(message)
        default: throw ScrobbleServiceError.rejected(message)
        }
    }
}

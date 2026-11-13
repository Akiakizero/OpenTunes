// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Synchronization
import Testing
@testable import MediaCore

/// Trasporto finto: registra le richieste e risponde con la closure data (che può cambiare nel test).
final class FakeTransport: Sendable {
    typealias Responder = @Sendable (URLRequest) throws -> (Int, Data)
    let requests = Mutex<[URLRequest]>([])
    private let responder: Mutex<Responder>

    init(_ responder: @escaping Responder) {
        self.responder = Mutex(responder)
    }

    func respond(_ responder: @escaping Responder) {
        self.responder.withLock { $0 = responder }
    }

    var transport: HTTPTransport {
        { [self] request in
            requests.withLock { $0.append(request) }
            let (status, data) = try responder.withLock { $0 }(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
    }

    /// Parametri di una richiesta (corpo form o query).
    static func parameters(_ request: URLRequest) -> [String: String] {
        let raw = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? request.url?.query ?? ""
        var result: [String: String] = [:]
        for pair in raw.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map { String($0).removingPercentEncoding ?? String($0) }
            if parts.count == 2 { result[parts[0]] = parts[1] }
        }
        return result
    }
}

func sampleTrack(_ i: Int = 0, start: Date = Date(timeIntervalSince1970: 1_762_900_000)) -> ScrobbleTrack {
    ScrobbleTrack(
        artist: "Artista \(i)", title: "Brano \(i)", album: "Album", duration: 200,
        startedAt: start.addingTimeInterval(TimeInterval(i) * 300), playerBundleID: "com.apple.Music")
}

@Suite("Client Last.fm")
struct LastFMClientTests {
    let credentials = LastFMCredentials(apiKey: "KEY", secret: "SECRET")

    @Test("Firma api_sig (MD5 dei parametri ordinati + secret, senza format)")
    func signature() {
        let sig = LastFMClient.signature(["token": "TOK", "method": "auth.getSession", "api_key": "KEY", "format": "json"], secret: "SECRET")
        #expect(sig == "0bf279e021f3a81b4553dd7e76cf72ad")
    }

    @Test("Scrobble a blocchi: parametri indicizzati, sessione e firma")
    func scrobbleRequest() async throws {
        let fake = FakeTransport { _ in (200, try Fixture.data("lastfm-scrobble-single.json")) }
        let client = LastFMClient(credentials: credentials, sessionKey: "SK", transport: fake.transport)
        _ = try await client.scrobble([sampleTrack(0), sampleTrack(1)])
        let request = try #require(fake.requests.withLock { $0.first })
        #expect(request.httpMethod == "POST")
        let params = FakeTransport.parameters(request)
        #expect(params["method"] == "track.scrobble")
        #expect(params["artist[1]"] == "Artista 1")
        #expect(params["timestamp[0]"] == "1762900000")
        #expect(params["duration[0]"] == "200")
        #expect(params["sk"] == "SK")
        #expect(params["format"] == "json")
        var signed = params
        signed.removeValue(forKey: "api_sig")
        #expect(params["api_sig"] == LastFMClient.signature(signed, secret: "SECRET"))
    }

    @Test("Esito con brani ignorati e limite giornaliero")
    func ignoredMessages() throws {
        let json = try #require(JSONValue.parse(try Fixture.data("lastfm-scrobble-mixed.json")))
        let result = LastFMClient.parseScrobbleResult(json, count: 3)
        #expect(result.accepted == 1)
        #expect(result.ignored.map(\.index) == [1, 2])
        #expect(result.ignored.map(\.isRetryable) == [false, true])
    }

    @Test("Un solo scrobble arriva come oggetto, non come array")
    func singleObject() throws {
        let json = try #require(JSONValue.parse(try Fixture.data("lastfm-scrobble-single.json")))
        #expect(LastFMClient.parseScrobbleResult(json, count: 1) == .init(accepted: 1, ignored: []))
    }

    @Test("Errore 9: la sessione non vale più")
    func invalidSession() async throws {
        let fake = FakeTransport { _ in (403, try Fixture.data("lastfm-error-session.json")) }
        let client = LastFMClient(credentials: credentials, sessionKey: "SK", transport: fake.transport)
        await #expect(throws: ScrobbleServiceError.unauthorized("Invalid session key - Please re-authenticate (9)")) {
            try await client.updateNowPlaying(sampleTrack())
        }
    }

    @Test("Server occupato e rete assente si possono ritentare")
    func retryable() async {
        let busy = LastFMClient(credentials: credentials, sessionKey: "SK", transport: FakeTransport { _ in
            (200, Data(#"{"error":11,"message":"Service Offline"}"#.utf8))
        }.transport)
        let offline = LastFMClient(credentials: credentials, sessionKey: "SK", transport: FakeTransport { _ in
            throw URLError(.notConnectedToInternet)
        }.transport)
        for client in [busy, offline] {
            do {
                _ = try await client.scrobble([sampleTrack()])
                Issue.record("doveva fallire")
            } catch let error as ScrobbleServiceError {
                #expect(error.isRetryable)
            } catch {
                Issue.record("errore inatteso \(error)")
            }
        }
    }

    @Test("Token non ancora approvato: errore 14 riconoscibile")
    func pendingToken() async {
        let client = LastFMClient(credentials: credentials, transport: FakeTransport { _ in
            (200, Data(#"{"error":14,"message":"Unauthorized Token"}"#.utf8))
        }.transport)
        await #expect(throws: LastFMClient.APIError(code: 14, message: "Unauthorized Token")) {
            _ = try await client.getSession(token: "TOK")
        }
        #expect(client.authorizationURL(token: "TOK").absoluteString == "https://www.last.fm/api/auth/?api_key=KEY&token=TOK")
    }

    @Test("Profilo: utente, recenti (con brano in corso), amati (oggetto singolo), top artisti")
    func profile() async throws {
        let fake = FakeTransport { request in
            let method = FakeTransport.parameters(request)["method"] ?? ""
            let file = switch method {
            case "user.getInfo": "lastfm-user-info.json"
            case "user.getRecentTracks": "lastfm-recent-tracks.json"
            case "user.getLovedTracks": "lastfm-loved-tracks.json"
            default: "lastfm-top-artists.json"
            }
            return (200, try Fixture.data(file))
        }
        let profile = try await LastFMClient(credentials: credentials, transport: fake.transport).profile(user: "utente")
        #expect(profile.user.name == "utente" && profile.user.playCount == 12345)
        #expect(profile.user.imageURL?.absoluteString.contains("174s") == true)
        #expect(profile.recent.count == 2)
        #expect(profile.recent[0].isNowPlaying && profile.recent[0].date == nil)
        #expect(profile.recent[1].artist == "Björk" && profile.recent[1].imageURL == nil)
        #expect(profile.loved.map(\.title) == ["Roads"])
        #expect(profile.topArtists.map(\.playCount) == [321, 120])
    }
}

@Suite("Client ListenBrainz")
struct ListenBrainzClientTests {
    @Test("Payload di submit-listens")
    func payload() throws {
        let request = try ListenBrainzClient(token: "TOKEN").submitRequest(type: "import", tracks: [sampleTrack(0), sampleTrack(1)])
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Token TOKEN")
        let body = try #require(request.httpBody)
        let json = try #require(JSONValue.parse(body))
        #expect(json["listen_type"]?.string == "import")
        let first = try #require(json["payload"]?.list.first)
        #expect(first["listened_at"]?.int == 1_762_900_000)
        #expect(first["track_metadata"]?["artist_name"]?.string == "Artista 0")
        #expect(first["track_metadata"]?["release_name"]?.string == "Album")
        #expect(first["track_metadata"]?["additional_info"]?["duration_ms"]?.int == 200_000)
    }

    @Test("playing_now senza listened_at")
    func playingNow() throws {
        let request = try ListenBrainzClient(token: "T").submitRequest(type: "playing_now", tracks: [sampleTrack()])
        let body = try #require(request.httpBody)
        let json = try #require(JSONValue.parse(body))
        #expect(json["payload"]?.list.first?["listened_at"] == nil)
    }

    @Test("Token validato o rifiutato")
    func validate() async throws {
        let ok = FakeTransport { _ in (200, Data(#"{"code":200,"message":"Token valid.","valid":true,"user_name":"utente"}"#.utf8)) }
        #expect(try await ListenBrainzClient(token: "T", transport: ok.transport).validateToken() == "utente")
        let bad = FakeTransport { _ in (200, Data(#"{"code":200,"message":"Token invalid.","valid":false}"#.utf8)) }
        await #expect(throws: ScrobbleServiceError.unauthorized("Token invalid.")) {
            _ = try await ListenBrainzClient(token: "T", transport: bad.transport).validateToken()
        }
    }
}

@Suite("Coda offline (SwiftData in memoria)")
struct ScrobbleQueueTests {
    func makeQueue() throws -> ScrobbleQueue {
        ScrobbleQueue(modelContainer: try Storage.makeContainer(inMemory: true))
    }

    @Test("Duplicati: stesso player, brano e inizio entro 30 s")
    func dedup() async throws {
        let queue = try makeQueue()
        let track = sampleTrack()
        #expect(try await queue.enqueue(track, services: [.lastFM]))
        var near = track
        near.startedAt += 10
        #expect(try await !queue.enqueue(near, services: [.lastFM]))
        var later = track
        later.startedAt += 400
        #expect(try await queue.enqueue(later, services: [.lastFM]))
        #expect(try await queue.pendingCount() == 2)
    }

    @Test("Blocchi dal più vecchio, invio per servizio")
    func batches() async throws {
        let queue = try makeQueue()
        for i in (0..<60).reversed() { try await queue.enqueue(sampleTrack(i), services: [.lastFM, .listenBrainz]) }
        let first = try await queue.due(for: .lastFM, limit: 50)
        #expect(first.count == 50)
        #expect(first.first?.track.title == "Brano 0")
        try await queue.markSent(first.map(\.id), for: .lastFM)
        #expect(try await queue.due(for: .lastFM, limit: 50).count == 10)
        #expect(try await queue.pendingCount(for: [.lastFM]) == 10)
        // Resta in attesa per ListenBrainz.
        #expect(try await queue.pendingCount() == 60)
    }

    @Test("Attesa crescente dopo un errore")
    func backoff() async throws {
        #expect(ScrobbleQueue.backoff(attempts: 1) == 30)
        #expect(ScrobbleQueue.backoff(attempts: 3) == 120)
        #expect(ScrobbleQueue.backoff(attempts: 20) == 3600)
        let queue = try makeQueue()
        let now = Date.now
        try await queue.enqueue(sampleTrack(), services: [.lastFM], now: now)
        let items = try await queue.due(for: .lastFM, limit: 50, now: now)
        try await queue.markFailed(items.map(\.id), for: .lastFM, error: "rete", now: now)
        #expect(try await queue.due(for: .lastFM, limit: 50, now: now + 10).isEmpty)
        #expect(try await queue.due(for: .lastFM, limit: 50, now: now + 31).count == 1)
        try await queue.retryNow(now: now + 1)
        #expect(try await queue.due(for: .lastFM, limit: 50, now: now + 1).count == 1)
    }

    @Test("Gli inviati restano per la deduplicazione, poi si cancellano")
    func purge() async throws {
        let queue = try makeQueue()
        let now = Date.now
        try await queue.enqueue(sampleTrack(), services: [.lastFM], now: now)
        try await queue.markSent(try await queue.due(for: .lastFM, limit: 1, now: now).map(\.id), for: .lastFM)
        #expect(try await !queue.enqueue(sampleTrack(), services: [.lastFM], now: now), "già inviato")
        try await queue.purge(now: now + 8 * 24 * 3600)
        #expect(try await queue.enqueue(sampleTrack(), services: [.lastFM], now: now))
    }
}

@MainActor
@Suite("Scrobbler: coda offline e invio")
struct ScrobblerTests {
    func makeScrobbler(_ fake: FakeTransport) throws -> (Scrobbler, ScrobbleQueue) {
        let queue = ScrobbleQueue(modelContainer: try Storage.makeContainer(inMemory: true))
        let secrets = MemorySecretStore([SecretAccount.lastFMSession: "SK", SecretAccount.lastFMUser: "utente"])
        let scrobbler = Scrobbler(
            store: NowPlayingStore(), queue: queue, secrets: secrets,
            configuration: .init(listenBrainzEnabled: false, credentials: LastFMCredentials(apiKey: "K", secret: "S")),
            transport: fake.transport)
        return (scrobbler, queue)
    }

    @Test("Senza rete gli ascolti restano in coda e partono quando la rete torna")
    func offlineThenOnline() async throws {
        let fake = FakeTransport { _ in throw URLError(.notConnectedToInternet) }
        let (scrobbler, queue) = try makeScrobbler(fake)
        await scrobbler.submit(sampleTrack(0))
        await scrobbler.submit(sampleTrack(1))
        await scrobbler.flush()
        #expect(scrobbler.pendingCount == 2)
        #expect(scrobbler.lastError != nil)

        fake.respond { request in
            let count = FakeTransport.parameters(request).keys.filter { $0.hasPrefix("artist[") }.count
            let items = Array(repeating: ##"{"ignoredMessage":{"code":"0","#text":""}}"##, count: count).joined(separator: ",")
            return (200, Data(#"{"scrobbles":{"scrobble":[\#(items)],"@attr":{"accepted":\#(count),"ignored":0}}}"#.utf8))
        }
        try await queue.retryNow()
        await scrobbler.flush()
        #expect(scrobbler.pendingCount == 0)
        let sent = fake.requests.withLock { $0 }.last.map(FakeTransport.parameters) ?? [:]
        #expect(sent["track[0]"] == "Brano 0" && sent["track[1]"] == "Brano 1", "inviati insieme, in un blocco")
    }

    @Test("Una coda lunga parte a blocchi di 50")
    func batchesOf50() async throws {
        let fake = FakeTransport { request in
            let count = FakeTransport.parameters(request).keys.filter { $0.hasPrefix("artist[") }.count
            return (200, Data(#"{"scrobbles":{"scrobble":[],"@attr":{"accepted":\#(count),"ignored":0}}}"#.utf8))
        }
        let (scrobbler, queue) = try makeScrobbler(fake)
        for i in 0..<120 { try await queue.enqueue(sampleTrack(i), services: [.lastFM]) }
        await scrobbler.flush()
        let sizes = fake.requests.withLock { $0 }.map { FakeTransport.parameters($0).keys.filter { $0.hasPrefix("artist[") }.count }
        #expect(sizes == [50, 50, 20])
        #expect(scrobbler.pendingCount == 0)
    }

    @Test("Un blocco rifiutato si riprova uno alla volta e si scarta solo l'ascolto non valido")
    func rejectedBatch() async throws {
        let fake = FakeTransport { request in
            let params = FakeTransport.parameters(request)
            if params["artist[1]"] != nil || params["track[0]"] == "Brano 1" {
                return (400, Data(#"{"error":6,"message":"Invalid parameters"}"#.utf8))
            }
            return (200, Data(#"{"scrobbles":{"scrobble":{"ignoredMessage":{"code":"0"}},"@attr":{"accepted":1,"ignored":0}}}"#.utf8))
        }
        let (scrobbler, queue) = try makeScrobbler(fake)
        for i in 0..<3 { try await queue.enqueue(sampleTrack(i), services: [.lastFM]) }
        await scrobbler.flush()
        #expect(scrobbler.pendingCount == 0)
        #expect(fake.requests.withLock { $0.count } == 4)
    }

    @Test("Sessione revocata: la coda si ferma e chiede un nuovo accesso")
    func revokedSession() async throws {
        let fake = FakeTransport { _ in (403, try Fixture.data("lastfm-error-session.json")) }
        let (scrobbler, _) = try makeScrobbler(fake)
        await scrobbler.submit(sampleTrack())
        await scrobbler.flush()
        #expect(scrobbler.lastFMNeedsReconnect)
        #expect(scrobbler.pendingCount == 1)
        #expect(scrobbler.activeServices.isEmpty)
    }
}

@Suite("Cronologia persistente")
struct TrackHistoryTests {
    @Test("Salva, aggiorna la copertina e ricarica dal più recente")
    func roundTrip() async throws {
        let history = TrackHistory(modelContainer: try Storage.makeContainer(inMemory: true), maxEntries: 3)
        let base = Date(timeIntervalSince1970: 1_762_900_000)
        for i in 0..<5 {
            await history.record(StoredPlay(track: Track(title: "T\(i)", artist: "A", playerBundleID: "p"), playedAt: base + Double(i)))
        }
        let loaded = await history.load(limit: 10)
        #expect(loaded.map(\.track.title) == ["T4", "T3", "T2"])
        #expect(TrackHistory.thumbnail(Data("non è un'immagine".utf8)) == nil)
    }

    @Test("Lo store carica la cronologia salvata e ci aggiunge i brani nuovi")
    @MainActor
    func storeAttach() async throws {
        let history = TrackHistory(modelContainer: try Storage.makeContainer(inMemory: true))
        await history.record(StoredPlay(track: Track(title: "Vecchio", artist: "A", playerBundleID: "p"), playedAt: .now - 600))
        let store = NowPlayingStore()
        store.looksUpMissingArtwork = false
        await store.attachHistory(history)
        #expect(store.recentTracks.map(\.track.title) == ["Vecchio"])
        store.inject(NowPlayingSnapshot(track: Track(title: "Nuovo", artist: "A", playerBundleID: "p"), playback: .init(isPlaying: true), sourceID: "t"))
        #expect(store.recentTracks.map(\.track.title) == ["Nuovo", "Vecchio"])
        let deadline = ContinuousClock.now + .seconds(2)
        while await history.load(limit: 10).count < 2, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await history.load(limit: 10).map(\.track.title) == ["Nuovo", "Vecchio"])
    }
}

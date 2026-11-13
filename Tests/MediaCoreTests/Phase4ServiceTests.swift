// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MediaCore

@Suite("Parser LRC")
struct LRCParserTests {
    @Test("Marcatori multipli, metadati ignorati, righe ordinate per tempo")
    func parse() {
        let lines = LRCParser.parse("[ti:Titolo]\n[00:05.50][01:10.00] Ritornello\n[00:01.00]Inizio\n[00:09]\n")
        #expect(lines.map(\.time) == [1, 5.5, 9, 70])
        #expect(lines.map(\.text) == ["Inizio", "Ritornello", "", "Ritornello"])
        #expect(lines.map(\.id) == [0, 1, 2, 3])
    }

    @Test("Offset in millisecondi: positivo anticipa il testo")
    func offset() {
        let lines = LRCParser.parse("[offset:+500]\n[00:02.00] A\n[00:00.20] B")
        #expect(lines.map(\.time) == [0, 1.5])
    }

    @Test("Tag non temporali e testo senza marcatori")
    func invalid() {
        #expect(LRCParser.timestamp("ar:Artista") == nil)
        #expect(LRCParser.timestamp("01:75") == nil)
        #expect(LRCParser.timestamp("02:03,25") == 123.25)
        #expect(LRCParser.parse("solo testo\nsenza tempi").isEmpty)
    }

    @Test("Riga corrente: nessuna prima dell'inizio, poi l'ultima iniziata")
    func currentLine() {
        let lyrics = Lyrics(lines: LRCParser.parse("[00:01.00]A\n[00:05.00]B\n[00:09.00]C"))
        #expect(lyrics.lineIndex(at: 0.5) == nil)
        #expect(lyrics.lineIndex(at: 1) == 0)
        #expect(lyrics.lineIndex(at: 8.9) == 1)
        #expect(lyrics.line(at: 300) == "C")
        #expect(Lyrics(plain: "testo").lineIndex(at: 10) == nil)
    }
}

@Suite("Testi da LRCLIB")
struct LyricsServiceTests {
    let query = LyricsService.Query(artist: "Artista", title: "Brano di prova", album: "Album", duration: 200)

    @Test("`/api/get` con tutti i campi, poi cache su disco")
    func getAndCache() async throws {
        let directory = URL.temporaryDirectory.appending(path: "lyrics-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let fake = FakeTransport { _ in (200, try Fixture.data("lrclib-get.json")) }
        let service = LyricsService(cacheDirectory: directory, transport: fake.transport)
        let lyrics = try #require(try await service.lyrics(for: query))
        #expect(lyrics.isSynced)
        #expect(lyrics.lines.first?.text == "Prima riga")
        let request = try #require(fake.requests.withLock { $0.first })
        #expect(request.url?.path == "/api/get")
        let params = FakeTransport.parameters(request)
        #expect(params["album_name"] == "Album")
        #expect(params["duration"] == "200")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("OpenTunes/") == true)

        // Un nuovo servizio con la stessa cartella non rifà la richiesta.
        let offline = FakeTransport { _ in throw URLError(.notConnectedToInternet) }
        let cached = LyricsService(cacheDirectory: directory, transport: offline.transport)
        #expect(try await cached.lyrics(for: query) == lyrics)
        #expect(offline.requests.withLock { $0.isEmpty })
    }

    @Test("Senza corrispondenza esatta: ricerca, durata entro 3 s, sincronizzato preferito")
    func searchFallback() async throws {
        let fake = FakeTransport { request in
            request.url?.path == "/api/get" ? (404, Data("{}".utf8)) : (200, try Fixture.data("lrclib-search.json"))
        }
        let service = LyricsService(cacheDirectory: nil, transport: fake.transport)
        let lyrics = try #require(try await service.lyrics(for: query))
        #expect(lyrics.lines.map(\.text) == ["Sincronizzato"])
        #expect(fake.requests.withLock { $0.map { $0.url?.path } } == ["/api/get", "/api/search"])
    }

    @Test("Non trovato: risultato in cache, ritentato dopo una settimana")
    func notFound() async throws {
        let fake = FakeTransport { _ in (404, Data("{}".utf8)) }
        let service = LyricsService(cacheDirectory: nil, transport: fake.transport)
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(try await service.lyrics(for: query, now: now) == nil)
        #expect(try await service.lyrics(for: query, now: now.addingTimeInterval(3600)) == nil)
        #expect(fake.requests.withLock { $0.count } == 2)
        _ = try await service.lyrics(for: query, now: now.addingTimeInterval(LyricsService.notFoundRetry + 1))
        #expect(fake.requests.withLock { $0.count } == 4)
    }

    @Test("Errori di rete: si propagano e non finiscono in cache")
    func networkError() async throws {
        let fake = FakeTransport { _ in throw URLError(.timedOut) }
        let service = LyricsService(cacheDirectory: nil, transport: fake.transport)
        await #expect(throws: ScrobbleServiceError.self) { try await service.lyrics(for: query) }
        fake.respond { _ in (200, try Fixture.data("lrclib-get.json")) }
        #expect(try await service.lyrics(for: query) != nil)
    }

    @Test("Senza album o durata si usa subito la ricerca")
    func searchOnly() {
        #expect(LyricsService.getURL(.init(artist: "A", title: "T")) == nil)
        #expect(LyricsService.searchURL(.init(artist: "A", title: "T")) != nil)
    }
}

@Suite("Link universale")
struct ShareLinkTests {
    @Test("iTunes → Odesli: link song.link, senza parametri di tracciamento")
    func odesli() async throws {
        let fake = FakeTransport { request in
            request.url?.host == "itunes.apple.com"
                ? (200, try Fixture.data("itunes-search-song.json")) : (200, try Fixture.data("odesli-links.json"))
        }
        let service = ShareLinkService(transport: fake.transport)
        let url = try await service.link(artist: "Artista", title: "Brano di prova", country: "IT")
        #expect(url.absoluteString == "https://song.link/i/456")
        let odesliRequest = try #require(fake.requests.withLock { $0.last })
        #expect(FakeTransport.parameters(odesliRequest)["url"] == "https://music.apple.com/it/album/brano-di-prova/123?i=456")
        // Seconda richiesta dalla cache.
        _ = try await service.link(artist: "Artista", title: "Brano di prova")
        #expect(fake.requests.withLock { $0.count } == 2)
    }

    @Test("Odesli non risponde: link di Apple Music")
    func fallback() async throws {
        let fake = FakeTransport { request in
            request.url?.host == "itunes.apple.com" ? (200, try Fixture.data("itunes-search-song.json")) : (429, Data())
        }
        let url = try await ShareLinkService(transport: fake.transport).link(artist: "Artista", title: "Brano di prova")
        #expect(url.host == "music.apple.com")
    }

    @Test("Nessun risultato su iTunes")
    func notFound() async {
        let fake = FakeTransport { _ in (200, Data(#"{"resultCount":0,"results":[]}"#.utf8)) }
        await #expect(throws: ShareLinkService.Failure.notFound) {
            try await ShareLinkService(transport: fake.transport).link(artist: "X", title: "Y")
        }
    }
}

@Suite("Last.fm: top album e simili")
struct LastFMDiscoveryTests {
    @Test("Top album: copertina più grande, album senza copertina")
    func topAlbums() throws {
        let albums = LastFMClient.parseTopAlbums(try #require(JSONValue.parse(try Fixture.data("lastfm-top-albums.json"))))
        #expect(albums.count == 2)
        #expect(albums[0].imageURL?.absoluteString == "https://img/xl.png")
        #expect(albums[0].playCount == 42)
        #expect(albums[1].imageURL == nil)
    }

    @Test("Artisti e brani simili (anche un solo risultato)")
    func similar() throws {
        let artists = LastFMClient.parseSimilarArtists(try #require(JSONValue.parse(try Fixture.data("lastfm-similar-artists.json"))))
        #expect(artists.map(\.name) == ["Simile uno", "Simile due"])
        #expect(artists[1].match == 0.42)
        let tracks = LastFMClient.parseSimilarTracks(try #require(JSONValue.parse(try Fixture.data("lastfm-similar-tracks.json"))))
        #expect(tracks.count == 1)
        #expect(tracks[0].artist == "Altro artista")
    }

    @Test("Richiesta dei top album: periodo e utente, non firmata")
    func request() async throws {
        let fake = FakeTransport { _ in (200, try Fixture.data("lastfm-top-albums.json")) }
        let client = LastFMClient(credentials: .init(apiKey: "KEY", secret: "SECRET"), transport: fake.transport)
        _ = try await client.topAlbums(user: "utente", period: .year)
        let params = FakeTransport.parameters(try #require(fake.requests.withLock { $0.first }))
        #expect(params["method"] == "user.getTopAlbums")
        #expect(params["period"] == "12month")
        #expect(params["api_sig"] == nil)
    }
}

@Suite("Volume del player")
struct PlayerVolumeTests {
    @Test("Script di lettura e scrittura limitati a 0…100")
    func scripts() {
        #expect(AppleScriptPlayer.spotify.setVolumeScript(150).contains("set sound volume to 100"))
        #expect(AppleScriptPlayer.music.setVolumeScript(-3).contains("set sound volume to 0"))
        #expect(AppleScriptPlayer.parseVolume(NSAppleEventDescriptor(int32: 40)) == 0.4)
        #expect(AppleScriptPlayer.parseVolume(NSAppleEventDescriptor(int32: -1)) == nil)
    }
}

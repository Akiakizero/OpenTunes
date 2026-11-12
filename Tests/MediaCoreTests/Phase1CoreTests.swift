// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MediaCore

@Suite("Normalizzazione dei titoli dei browser")
struct TitleNormalizerTests {
    func track(_ title: String, artist: String? = nil) -> Track {
        Track(title: title, artist: artist, playerBundleID: "com.apple.Safari")
    }

    @Test("Divide «Artista - Titolo» e toglie «(Official Video)»")
    func splitsAndStrips() {
        let result = TitleNormalizer.normalize(track("Daft Punk - One More Time (Official Video)", artist: "Daft Punk"), isBrowser: true)
        #expect(result.title == "One More Time")
        #expect(result.artist == "Daft Punk")
    }

    @Test("Toglie il suffisso « - Topic» dal canale")
    func cleansTopicChannel() {
        let result = TitleNormalizer.normalize(track("Clair de Lune", artist: "Claude Debussy - Topic"), isBrowser: true)
        #expect(result.title == "Clair de Lune")
        #expect(result.artist == "Claude Debussy")
    }

    @Test("Rumore tra quadre e varianti", arguments: [
        ("Song [Official Music Video]", "Song"),
        ("Song (Lyrics)", "Song"),
        ("Song (HD)", "Song"),
        ("Song (Remastered 2011)", "Song"),
        ("Song (Live)", "Song (Live)"),
    ])
    func stripsNoise(input: String, expected: String) {
        #expect(TitleNormalizer.normalize(track(input), isBrowser: true).title == expected)
    }

    @Test("I player musicali non vengono toccati")
    func leavesMusicPlayersAlone() {
        let original = Track(title: "A - B (Official Video)", artist: "X", playerBundleID: "com.apple.Music")
        #expect(TitleNormalizer.normalize(original, isBrowser: false) == original)
    }
}

@Suite("Lookup copertine iTunes")
struct ArtworkLookupTests {
    @Test("Estrae l'URL 600×600 dalla risposta")
    func parsesResponse() {
        let json = #"{"resultCount":1,"results":[{"artworkUrl100":"https://is1.mzstatic.com/a/100x100bb.jpg"}]}"#
        #expect(ArtworkLookup.artworkURL(fromSearchResponse: Data(json.utf8))?.absoluteString == "https://is1.mzstatic.com/a/600x600bb.jpg")
    }

    @Test("Nessun risultato → nil")
    func emptyResponse() {
        #expect(ArtworkLookup.artworkURL(fromSearchResponse: Data(#"{"resultCount":0,"results":[]}"#.utf8)) == nil)
    }

    @Test("La query contiene artista e titolo")
    func buildsQuery() throws {
        let url = try #require(ArtworkLookup.searchURL(artist: "AC/DC", title: "T.N.T."))
        #expect(url.host == "itunes.apple.com")
        #expect(url.query?.contains("entity=song") == true)
    }
}

@Suite("Comandi shuffle e repeat")
struct ShuffleRepeatCommandTests {
    @Test("Argomenti dell'adapter")
    func adapterArguments() {
        #expect(MediaRemoteSource.arguments(for: .setShuffle(.tracks)) == ["shuffle", "3"])
        #expect(MediaRemoteSource.arguments(for: .setShuffle(.off)) == ["shuffle", "1"])
        #expect(MediaRemoteSource.arguments(for: .setRepeat(.one)) == ["repeat", "2"])
    }

    @Test("Script AppleScript per Musica e Spotify")
    func appleScripts() {
        #expect(AppleScriptPlayer.music.commandScript(.setRepeat(.one)).contains("set song repeat to one"))
        #expect(AppleScriptPlayer.music.commandScript(.setShuffle(.tracks)).contains("set shuffle enabled to true"))
        #expect(AppleScriptPlayer.spotify.commandScript(.setShuffle(.off)).contains("set shuffling to false"))
        #expect(AppleScriptPlayer.spotify.commandScript(.setRepeat(.all)).contains("set repeating to true"))
    }
}

/// Sorgente che emette gli snapshot uno per volta su richiesta.
final class ManualSource: MediaSource, @unchecked Sendable {
    let id = "manual"
    let stream: AsyncStream<NowPlayingSnapshot>
    let continuation: AsyncStream<NowPlayingSnapshot>.Continuation

    init() {
        (stream, continuation) = AsyncStream<NowPlayingSnapshot>.makeStream()
    }

    func isAvailable() async -> Bool { true }
    func updates() -> AsyncStream<NowPlayingSnapshot> { stream }
    func send(_ command: MediaCommand) async throws {}

    func emit(_ title: String, bundleID: String = "com.apple.Music", artist: String? = "A") {
        continuation.yield(NowPlayingSnapshot(
            track: Track(title: title, artist: artist, playerBundleID: bundleID),
            playback: .init(isPlaying: true), sourceID: id))
    }
}

@MainActor
@Suite("Store: blacklist e cronologia")
struct StoreFilteringTests {
    func waitFor(_ condition: @MainActor () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func makeStore() -> NowPlayingStore {
        let store = NowPlayingStore()
        store.looksUpMissingArtwork = false
        return store
    }

    @Test("Un player ignorato vale «niente in riproduzione», e torna visibile se lo si toglie")
    func blacklist() async {
        let store = makeStore()
        store.ignoredBundleIDs = ["us.zoom.xos"]
        let source = ManualSource()
        store.start(sources: [source])
        source.emit("Riunione", bundleID: "us.zoom.xos")
        await waitFor { store.activeSourceID == "manual" }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(store.track == nil)
        store.ignoredBundleIDs = []
        #expect(store.track?.title == "Riunione")
        store.stop()
    }

    @Test("La cronologia mette in cima il brano più recente, senza duplicati")
    func history() async {
        let store = makeStore()
        let source = ManualSource()
        store.start(sources: [source])
        for title in ["Uno", "Due", "Uno"] {
            source.emit(title)
            await waitFor { store.track?.title == title }
        }
        #expect(store.recentTracks.map(\.track.title) == ["Uno", "Due"])
        #expect(store.trackChangeCount == 3)
        store.stop()
    }

    @Test("I titoli dei browser vengono normalizzati")
    func normalizesBrowser() async {
        let store = makeStore()
        let source = ManualSource()
        store.start(sources: [source])
        source.emit("Artista - Brano (Official Video)", bundleID: "com.google.Chrome", artist: "Canale")
        await waitFor { store.track != nil }
        #expect(store.track?.title == "Brano")
        #expect(store.track?.artist == "Artista")
        store.normalizesBrowserTitles = false
        #expect(store.track?.title == "Artista - Brano (Official Video)")
        store.stop()
    }
}

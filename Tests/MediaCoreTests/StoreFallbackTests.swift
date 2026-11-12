// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Synchronization
import Testing
@testable import MediaCore

/// Sorgente finta: emette gli snapshot dati e poi termina (o resta aperta).
final class FakeSource: MediaSource {
    let id: String
    let available: Bool
    let snapshots: [NowPlayingSnapshot]
    let keepOpen: Bool
    let commands = Mutex<[MediaCommand]>([])

    init(id: String, available: Bool = true, titles: [String] = [], keepOpen: Bool = false) {
        self.id = id
        self.available = available
        self.keepOpen = keepOpen
        self.snapshots = titles.map {
            NowPlayingSnapshot(track: Track(title: $0, playerBundleID: "test"), playback: .init(isPlaying: true), sourceID: id)
        }
    }

    func isAvailable() async -> Bool { available }

    func updates() -> AsyncStream<NowPlayingSnapshot> {
        let (stream, continuation) = AsyncStream<NowPlayingSnapshot>.makeStream()
        for s in snapshots { continuation.yield(s) }
        if !keepOpen { continuation.finish() }
        return stream
    }

    func send(_ command: MediaCommand) async throws {
        commands.withLock { $0.append(command) }
    }
}

@MainActor
@Suite("NowPlayingStore e fallback")
struct StoreFallbackTests {
    func waitFor(_ condition: @MainActor () -> Bool, timeout: Duration = .seconds(2)) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("Se la prima sorgente smette di rispondere si passa alla seconda")
    func fallsBackWhenStreamEnds() async {
        let store = NowPlayingStore()
        let primary = FakeSource(id: "mediaremote", titles: ["A"])
        let fallback = FakeSource(id: "applescript", titles: ["B"], keepOpen: true)
        store.start(sources: [primary, fallback])
        await waitFor { store.activeSourceID == "applescript" && store.track?.title == "B" }
        #expect(store.activeSourceID == "applescript")
        #expect(store.track?.title == "B")
        #expect(store.events.contains { $0.sourceID == "mediaremote" && $0.message.contains("smesso di rispondere") })
        store.stop()
    }

    @Test("Una sorgente non disponibile viene saltata")
    func skipsUnavailable() async {
        let store = NowPlayingStore()
        store.start(sources: [FakeSource(id: "mediaremote", available: false), FakeSource(id: "applescript", titles: ["B"], keepOpen: true)])
        await waitFor { store.track?.title == "B" }
        #expect(store.activeSourceID == "applescript")
        #expect(store.events.contains { $0.sourceID == "mediaremote" && $0.message.contains("non disponibile") })
        store.stop()
    }

    @Test("La sorgente funzionante resta attiva")
    func staysOnHealthySource() async {
        let store = NowPlayingStore()
        let fallback = FakeSource(id: "applescript", titles: ["B"])
        store.start(sources: [FakeSource(id: "mediaremote", titles: ["A"], keepOpen: true), fallback])
        await waitFor { store.track?.title == "A" }
        try? await Task.sleep(for: .milliseconds(100))
        #expect(store.activeSourceID == "mediaremote")
        #expect(store.track?.title == "A")
        store.stop()
    }

    @Test("Tutte le sorgenti esaurite")
    func exhausted() async {
        let store = NowPlayingStore()
        store.start(sources: [FakeSource(id: "x", available: false), FakeSource(id: "y", titles: ["C"])])
        await store.waitUntilFinished()
        #expect(store.exhausted)
        #expect(store.activeSourceID == nil)
        #expect(store.track == nil)
    }

    @Test("I comandi vanno alla sorgente attiva")
    func commandsGoToActiveSource() async {
        let store = NowPlayingStore()
        let primary = FakeSource(id: "mediaremote", titles: ["A"], keepOpen: true)
        store.start(sources: [primary])
        await waitFor { store.activeSourceID == "mediaremote" }
        await store.send(.togglePlayPause)
        await store.send(.nextTrack)
        #expect(primary.commands.withLock { $0 } == [.togglePlayPause, .nextTrack])
        store.stop()
    }
}

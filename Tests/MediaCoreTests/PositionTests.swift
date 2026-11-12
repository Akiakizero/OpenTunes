// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MediaCore

@Suite("Calcolo della posizione")
struct PositionTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test("In riproduzione la posizione avanza col tempo")
    func advances() {
        let s = PlaybackState(isPlaying: true, elapsedTime: 10, timestamp: t0)
        #expect(s.position(at: t0.addingTimeInterval(5)) == 15)
    }

    @Test("In pausa la posizione resta ferma")
    func paused() {
        let s = PlaybackState(isPlaying: false, elapsedTime: 10, timestamp: t0)
        #expect(s.position(at: t0.addingTimeInterval(500)) == 10)
    }

    @Test("Velocità di riproduzione")
    func rate() {
        let s = PlaybackState(isPlaying: true, elapsedTime: 0, timestamp: t0, playbackRate: 2)
        #expect(s.position(at: t0.addingTimeInterval(3)) == 6)
    }

    @Test("Limitata alla durata e mai negativa")
    func clamped() {
        let s = PlaybackState(isPlaying: true, elapsedTime: 100, timestamp: t0)
        #expect(s.position(at: t0.addingTimeInterval(500), duration: 120) == 120)
        #expect(s.position(at: t0.addingTimeInterval(-50)) == 100)
        let negative = PlaybackState(isPlaying: false, elapsedTime: -4, timestamp: t0)
        #expect(negative.position(at: t0) == 0)
    }

    @Test("Dal payload dell'adapter: elapsedTime + timestamp")
    func fromAdapter() throws {
        var decoder = AdapterStreamDecoder(sourceID: "mr")
        let s = decoder.consume(try Fixture.data("stream-music-session.jsonl")).snapshots[1]
        let at = Date(timeIntervalSince1970: 1_762_944_058)  // 10 s dopo il timestamp
        #expect(s.playback.position(at: at, duration: s.track?.duration) == 70)
    }
}

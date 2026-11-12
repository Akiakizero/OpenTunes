// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MediaCore

@Suite("Parsing dell'adapter")
struct AdapterParsingTests {
    @Test("Payload completo con --micros")
    func fullPayload() throws {
        var decoder = AdapterStreamDecoder(sourceID: "mr")
        let data = try Fixture.data("stream-music-session.jsonl")
        let first = data.split(separator: 0x0A).first!
        let (snapshots, errors) = decoder.consume(Data(first) + Data([0x0A]))
        #expect(errors.isEmpty)
        let s = try #require(snapshots.first)
        let track = try #require(s.track)
        #expect(track.title == "Svegliarsi la mattina")
        #expect(track.artist == "Zero Assoluto")
        #expect(track.album == "Appena prima di partire")
        #expect(track.duration == 215)
        #expect(track.playerBundleID == "com.apple.Music")
        #expect(track.artworkData != nil)
        #expect(track.artworkHash?.count == 64)
        #expect(track.artwork != nil)
        #expect(s.playback.isPlaying)
        #expect(s.playback.elapsedTime == 12)
        #expect(s.playback.timestamp == Date(timeIntervalSince1970: 1_762_944_000))
        #expect(s.playback.shuffle == .off)
        #expect(s.playback.repeatMode == .all)
    }

    @Test("Riga spezzata in più chunk e UTF-8 tagliato a metà")
    func chunkedInput() throws {
        let data = try Fixture.data("stream-music-session.jsonl")
        var decoder = AdapterStreamDecoder(sourceID: "mr")
        var all: [NowPlayingSnapshot] = []
        // chunk di 7 byte: taglia anche i caratteri multibyte
        var i = data.startIndex
        while i < data.endIndex {
            let end = data.index(i, offsetBy: 7, limitedBy: data.endIndex) ?? data.endIndex
            let (s, e) = decoder.consume(data[i..<end])
            #expect(e.isEmpty)
            all += s
            i = end
        }
        #expect(all.count == 6)
    }

    @Test("Riga non JSON segnalata come errore senza interrompere lo stream")
    func invalidLine() {
        var decoder = AdapterStreamDecoder(sourceID: "mr")
        let input = Data("not json\n{\"type\":\"data\",\"diff\":false,\"payload\":{\"title\":\"A\",\"bundleIdentifier\":\"x\",\"playing\":true}}\n".utf8)
        let (s, e) = decoder.consume(input)
        #expect(e.count == 1)
        #expect(s.count == 1)
        #expect(s.first?.track?.title == "A")
    }

    @Test("Browser: si usa il bundle ID dell'app genitore")
    func browserParent() throws {
        var decoder = AdapterStreamDecoder(sourceID: "mr")
        let (s, _) = decoder.consume(try Fixture.data("stream-browser-youtube.jsonl"))
        let track = try #require(s.first?.track)
        #expect(track.playerBundleID == "com.apple.Safari")
        #expect(PlayerApp.resolve(bundleID: track.playerBundleID).isBrowser)
        #expect(track.artist == "Some Channel")
        #expect(track.album == nil)
    }

    @Test("Chiavi senza --micros e timestamp ISO-8601")
    func legacyKeys() throws {
        let line = #"{"type":"data","diff":false,"payload":{"title":"T","bundleIdentifier":"b","playing":false,"duration":100.5,"elapsedTime":3.25,"timestamp":"2026-11-12T10:00:00Z"}}"#
        let message = try AdapterMessage.decode(line: Data(line.utf8))
        var decoder = AdapterStreamDecoder(sourceID: "mr")
        let s = decoder.apply(message)
        #expect(s.track?.duration == 100.5)
        #expect(s.playback.elapsedTime == 3.25)
        #expect(s.playback.timestamp == ISO8601DateFormatter().date(from: "2026-11-12T10:00:00Z"))
    }

    @Test("Payload senza titolo = niente in riproduzione")
    func missingTitle() {
        let s = AdapterStreamDecoder.snapshot(from: AdapterPayload(["bundleIdentifier": .string("x")]), sourceID: "mr")
        #expect(s.track == nil)
    }

    @Test("Output null di get")
    func getNull() throws {
        #expect(throws: AdapterMessage.DecodeError.notJSONObject) {
            try AdapterMessage.decode(line: try Fixture.data("get-null.json"))
        }
    }

    @Test("Mappa dei comandi verso send/seek")
    func commandArguments() {
        #expect(MediaRemoteSource.arguments(for: .togglePlayPause) == ["send", "2"])
        #expect(MediaRemoteSource.arguments(for: .nextTrack) == ["send", "4"])
        #expect(MediaRemoteSource.arguments(for: .previousTrack) == ["send", "5"])
        #expect(MediaRemoteSource.arguments(for: .seek(to: 1.5)) == ["seek", "1500000"])
        #expect(MediaRemoteSource.arguments(for: .seek(to: -3)) == ["seek", "0"])
    }

    @Test("Opzioni di stream: micros e debounce TIDAL")
    func streamArguments() {
        #expect(MediaRemoteSource.streamArguments.contains("--micros"))
        #expect(MediaRemoteSource.streamArguments.contains("--experimental-peculiar-debounce:com.tidal.desktop=1000"))
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MediaCore

@Suite("Applicazione dei diff")
struct DiffTests {
    func session() throws -> [NowPlayingSnapshot] {
        var decoder = AdapterStreamDecoder(sourceID: "mr")
        return decoder.consume(try Fixture.data("stream-music-session.jsonl")).snapshots
    }

    @Test("Un diff aggiorna solo le chiavi presenti")
    func partialUpdate() throws {
        let s = try session()
        #expect(s[1].track?.title == "Svegliarsi la mattina")
        #expect(s[1].track?.artworkData == s[0].track?.artworkData)
        #expect(s[1].playback.elapsedTime == 60)
        #expect(s[1].playback.isPlaying)
    }

    @Test("Una chiave null nel diff viene rimossa")
    func nullRemovesKey() throws {
        let s = try session()
        #expect(s[1].track?.album == "Appena prima di partire")
        #expect(s[2].track?.album == nil)
        #expect(s[2].track?.artist == "Zero Assoluto")
    }

    @Test("Pausa via diff")
    func pause() throws {
        let s = try session()
        #expect(s[3].playback.isPlaying == false)
        #expect(s[3].playback.elapsedTime == 61.5)
    }

    @Test("Un payload completo sostituisce tutto, copertina inclusa")
    func fullReplaces() throws {
        let s = try session()
        #expect(s[4].track?.title == "Sei parte di me")
        #expect(s[4].track?.artworkData == nil)
        #expect(s[4].playback.shuffle == nil)
    }

    @Test("Payload vuoto = niente in riproduzione")
    func emptyPayload() throws {
        #expect(try session()[5].track == nil)
    }

    @Test("AdapterPayload.apply direttamente")
    func applyDirect() {
        var p = AdapterPayload(["a": .string("1"), "b": .number(2)])
        p.apply(diff: ["a": .null, "c": .bool(true), "b": .number(3)])
        #expect(p["a"] == nil)
        #expect(p["b"] == .number(3))
        #expect(p["c"] == .bool(true))
    }

    @Test("LineBuffer conserva la riga incompleta e ignora \\r")
    func lineBuffer() {
        var b = LineBuffer()
        #expect(b.append(Data("ab".utf8)).isEmpty)
        #expect(b.append(Data("c\r\nde".utf8)) == [Data("abc".utf8)])
        #expect(b.pending == 2)
        #expect(b.append(Data("\n\n".utf8)) == [Data("de".utf8)])
    }
}

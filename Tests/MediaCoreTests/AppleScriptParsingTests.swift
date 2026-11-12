// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Testing
@testable import MediaCore

@Suite("AppleScript: parsing e script")
struct AppleScriptParsingTests {
    func list(_ items: [NSAppleEventDescriptor]) -> NSAppleEventDescriptor {
        let d = NSAppleEventDescriptor.list()
        for (i, item) in items.enumerated() { d.insert(item, at: i + 1) }
        return d
    }

    @Test("Lettura di Spotify con URL della copertina")
    func spotifyReading() throws {
        let d = list([
            .init(string: "playing"), .init(string: "Song"), .init(string: "Artist"), .init(string: "Album"),
            .init(string: "Artist"), .init(double: 200), .init(double: 42.5), .init(boolean: true),
            .init(string: "all"), .init(string: "https://i.scdn.co/image/abc"),
        ])
        let r = AppleScriptPlayer.parseReading(d)
        #expect(r.state == "playing")
        #expect(r.duration == 200)
        #expect(r.position == 42.5)
        #expect(r.artworkURL == "https://i.scdn.co/image/abc")
        let s = try #require(AppleScriptPlayer.spotify.snapshot(from: r, sourceID: "as"))
        #expect(s.track?.playerBundleID == "com.spotify.client")
        #expect(s.track?.artworkURL?.host() == "i.scdn.co")
        #expect(s.playback.isPlaying)
        #expect(s.playback.shuffle == .tracks)
        #expect(s.playback.repeatMode == .all)
    }

    @Test("Stato stopped o player chiuso = nessuno snapshot")
    func stopped() {
        let r1 = AppleScriptPlayer.parseReading(list([.init(string: "stopped")]))
        #expect(AppleScriptPlayer.music.snapshot(from: r1, sourceID: "as") == nil)
        let r2 = AppleScriptPlayer.parseReading(list([.init(string: "notrunning")]))
        #expect(AppleScriptPlayer.music.snapshot(from: r2, sourceID: "as") == nil)
    }

    @Test("Gli script controllano che il player sia aperto e lo chiamano per bundle ID")
    func scriptsGuardRunning() {
        for p in AppleScriptPlayer.allSupported {
            #expect(p.readScript.contains("application id \"\(p.bundleID)\" is running"))
            #expect(p.commandScript(.nextTrack).contains("application id \"\(p.bundleID)\" is running"))
        }
        #expect(AppleScriptPlayer.music.commandScript(.seek(to: 12.5)).contains("set player position to 12.500"))
    }

    /// Compila solo per i player installati: senza l'app manca il dizionario AppleScript.
    @Test("Gli script compilano (player installati)")
    func scriptsCompile() {
        let installed = AppleScriptPlayer.allSupported.filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil
        }
        for p in installed {
            var error: NSDictionary?
            #expect(NSAppleScript(source: p.readScript)?.compileAndReturnError(&error) == true, "\(p.displayName): \(String(describing: error))")
            #expect(NSAppleScript(source: p.commandScript(.togglePlayPause))?.compileAndReturnError(&error) == true)
        }
    }

    @Test("Notifiche osservate")
    func notifications() {
        #expect(AppleScriptPlayer.music.notificationNames.contains("com.apple.Music.playerInfo"))
        #expect(AppleScriptPlayer.music.notificationNames.contains("com.apple.iTunes.playerInfo"))
        #expect(AppleScriptPlayer.spotify.notificationNames == ["com.spotify.client.PlaybackStateChanged"])
    }

    @Test("Differenze significative tra snapshot")
    func meaningfulDiff() {
        let base = NowPlayingSnapshot(track: Track(title: "A", playerBundleID: "x"), playback: .init(isPlaying: false, elapsedTime: 10), sourceID: "as")
        var drift = base
        drift.playback.elapsedTime = 10.5
        #expect(!AppleScriptSource.differsMeaningfully(base, drift))
        var jump = base
        jump.playback.elapsedTime = 30
        #expect(AppleScriptSource.differsMeaningfully(base, jump))
    }
}

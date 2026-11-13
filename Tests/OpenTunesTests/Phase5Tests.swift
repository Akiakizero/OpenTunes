// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import MediaCore
import Testing
@testable import OpenTunes

@Suite("Comandi via URL")
@MainActor
struct URLCommandTests {
    @Test("Nomi, alias e parametri")
    func parsing() {
        #expect(URLCommand(url: URL(string: "opentunes://next")!) == .next)
        #expect(URLCommand(url: URL(string: "opentunes://play-pause")!) == .playPause)
        #expect(URLCommand(url: URL(string: "opentunes:///prev")!) == .previous)
        #expect(URLCommand(url: URL(string: "opentunes://player")!) == .player)
        #expect(URLCommand(url: URL(string: "opentunes://volume?level=140")!) == .volume(100))
        #expect(URLCommand(url: URL(string: "opentunes://seek?by=-15")!) == .seek(-15))
        #expect(URLCommand(url: URL(string: "opentunes://volume")!) == nil)
        #expect(URLCommand(url: URL(string: "opentunes://boh")!) == nil)
        #expect(URLCommand(url: URL(string: "https://next")!) == nil)
    }

    @Test("Con i comandi spenti resta solo il clic sul widget")
    func disabled() {
        let model = AppModel.preview()
        model.settings.urlCommandsEnabled = false
        #expect(!model.run(.next))
        #expect(URLCommand.player.isAlwaysAllowed)
        model.settings.urlCommandsEnabled = true
        #expect(model.run(.next))
    }
}

@Suite("Interruttori delle funzioni")
@MainActor
struct FeatureToggleTests {
    @Test("Spente, le funzioni spariscono da modello e menu")
    func gates() {
        let model = AppModel.preview()
        #expect(model.canShare)
        model.settings.shareLinksEnabled = false
        #expect(!model.canShare)
        model.onOpenDiscover = {}
        #expect(model.discoverAction != nil)
        model.settings.discoverEnabled = false
        #expect(model.discoverAction == nil)
        model.settings.switchPlayerEnabled = false
        #expect(model.switchTarget == nil)
    }

    @Test("Le nuove preferenze partono con i valori previsti e si salvano")
    func defaultsAndPersistence() {
        let suite = "org.opentunes.tests.phase5.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.loveEnabled && settings.shareLinksEnabled && settings.hotkeysEnabled && settings.urlCommandsEnabled)
        #expect(!settings.discordEnabled && !settings.midiEnabled)
        settings.showsRecentTracks = false
        settings.midiMappings["next"] = 0x13C
        let reloaded = AppSettings(defaults: defaults)
        #expect(!reloaded.showsRecentTracks)
        #expect(reloaded.midiMappings["next"] == 0x13C)
    }
}

@Suite("Temi JSON")
@MainActor
struct CustomThemeTests {
    @Test("Un tema valido si legge, si riesporta uguale e si attiva")
    func roundTrip() throws {
        let json = ##"{"name":"Tramonto","glass":"clear","tint":"#FF7A45","tintOpacity":0.3,"accent":"#ffb000"}"##
        let theme = try CustomTheme.decode(Data(json.utf8))
        #expect(theme.glass == .clear)
        #expect(theme.fixedTint == RGB(r: 1, g: 122.0 / 255, b: 69.0 / 255))
        #expect(try CustomTheme.decode(theme.encoded()) == theme)
        let settings = AppSettings(persists: false)
        try settings.importTheme(Data(json.utf8))
        #expect(settings.theme == .custom)
        #expect(SurfaceTheme.custom.usesClearGlass)
        CustomTheme.active = .template
    }

    @Test("Colori e opacità non validi vengono rifiutati")
    func invalid() {
        #expect(throws: CustomTheme.ValidationError.self) { try CustomTheme.decode(Data(#"{"name":"x","tint":"rosso"}"#.utf8)) }
        #expect(throws: CustomTheme.ValidationError.self) { try CustomTheme.decode(Data(#"{"name":"x","tintOpacity":2}"#.utf8)) }
        #expect(throws: CustomTheme.ValidationError.self) { try CustomTheme.decode(Data(#"{"name":" "}"#.utf8)) }
    }
}

@Suite("MIDI")
struct MIDITests {
    @Test("Note-on e Control Change da parole UMP")
    func parse() {
        #expect(MIDITrigger.parse(ump: 0x2090_3C64) == MIDITrigger(kind: .note, number: 60))
        #expect(MIDITrigger.parse(ump: 0x2090_3C00) == nil)  // velocità 0 = note-off
        #expect(MIDITrigger.parse(ump: 0x2080_3C40) == nil)  // note-off
        #expect(MIDITrigger.parse(ump: 0x20B1_147F) == MIDITrigger(kind: .controlChange, number: 20))
        #expect(MIDITrigger.parse(ump: 0x1090_3C64) == nil)  // non è voce di canale MIDI 1.0
        #expect(MIDITrigger(code: MIDITrigger(kind: .note, number: 36).code) == MIDITrigger(kind: .note, number: 36))
    }
}

@Suite("Statistiche locali")
struct ListeningStatsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        calendar.firstWeekday = 2
        return calendar
    }()

    func play(_ title: String, _ artist: String, hoursAgo: Double, now: Date, duration: TimeInterval? = 180) -> StoredPlay {
        StoredPlay(
            track: Track(title: title, artist: artist, duration: duration, playerBundleID: "com.apple.Music"),
            playedAt: now.addingTimeInterval(-hoursAgo * 3600))
    }

    @Test("Totali, classifiche e periodi")
    func stats() {
        let now = Date(timeIntervalSince1970: 1_763_035_200)  // 13 novembre 2025, 13:00
        let plays = [
            play("A", "Uno", hoursAgo: 1, now: now), play("A", "uno", hoursAgo: 2, now: now),
            play("B", "Due", hoursAgo: 30, now: now, duration: nil), play("C", "Uno", hoursAgo: 24 * 20, now: now),
        ]
        let week = ListeningStats(plays: plays, now: now, period: 7 * 86_400, calendar: calendar)
        #expect(week.totalPlays == 3)
        #expect(week.distinctArtists == 2)
        #expect(week.topArtists.first == ListeningStats.Ranked(name: "Uno", detail: nil, plays: 2))
        #expect(week.topTracks.first?.name == "A")
        #expect(abs(week.totalMinutes - (3 + 3 + ListeningStats.defaultMinutes)) < 0.001)
        #expect(week.days.count == 7)
        #expect(week.days.last?.plays == 2)
        let all = ListeningStats(plays: plays, now: now, calendar: calendar)
        #expect(all.totalPlays == 4)
        #expect(all.weeks.count == 8)
        #expect(all.weeks.reduce(0) { $0 + $1.plays } == 4)
    }
}

@Suite("Discord Rich Presence")
struct DiscordTests {
    @Test("Frame: opcode e lunghezza little-endian, poi il JSON")
    func frames() throws {
        let json = Data(#"{"v":1}"#.utf8)
        let frame = DiscordFrame.encode(.handshake, json: json)
        #expect(Array(frame.prefix(8)) == [0, 0, 0, 0, 7, 0, 0, 0])
        let decoded = try #require(DiscordFrame.decode(frame + Data([1, 2])))
        #expect(decoded.opcode == 0)
        #expect(decoded.json == json)
        #expect(decoded.length == 15)
        #expect(DiscordFrame.decode(frame.prefix(10)) == nil)
    }

    @Test("Attività «Sta ascoltando» con tempi in millisecondi e testi di almeno 2 caratteri")
    func activity() throws {
        let start = Date(timeIntervalSince1970: 100)
        let activity = DiscordActivity(
            title: "X", artist: "Artista", album: nil, start: start, end: start.addingTimeInterval(60),
            artworkURL: URL(string: "https://example.com/a.jpg"), link: nil)
        let json = activity.json
        #expect(json["type"] as? Int == 2)
        #expect((json["details"] as? String)?.count ?? 0 >= 2)
        #expect((json["timestamps"] as? [String: Int])?["end"] == 160_000)
        #expect((json["assets"] as? [String: String])?["large_image"] == "https://example.com/a.jpg")
        let message = try #require(try JSONSerialization.jsonObject(with: DiscordFrame.setActivity(activity, pid: 42)) as? [String: Any])
        #expect(message["cmd"] as? String == "SET_ACTIVITY")
        #expect((message["args"] as? [String: Any])?["pid"] as? Int == 42)
    }
}

@Suite("Server ListenBrainz compatibili")
struct ListenBrainzServerTests {
    @Test("Maloja, istanze proprie e server ufficiale")
    func serverURL() {
        #expect(ListenBrainzClient.serverURL(from: "") == nil)
        #expect(ListenBrainzClient.serverURL(from: "maloja.example.com")?.absoluteString == "https://maloja.example.com/apis/listenbrainz/1/")
        #expect(ListenBrainzClient.serverURL(from: "http://pi.local:42010/")?.absoluteString == "http://pi.local:42010/apis/listenbrainz/1/")
        #expect(ListenBrainzClient.serverURL(from: "https://lb.example.org/1")?.absoluteString == "https://lb.example.org/1/")
    }
}

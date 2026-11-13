// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MediaCore

@Suite("Regole di scrobbling")
struct ScrobbleRulesTests {
    let rules = ScrobbleRules.lastFM

    @Test("Metà della durata o 4 minuti, quello che arriva prima")
    func standard() {
        #expect(rules.threshold(duration: 200) == 100)
        #expect(rules.threshold(duration: 600) == 240)
        #expect(rules.threshold(duration: 480) == 240)
    }

    @Test("I brani di 30 secondi o meno non si inviano")
    func tooShort() {
        #expect(rules.threshold(duration: 30) == nil)
        #expect(rules.threshold(duration: 31) == 15.5)
    }

    @Test("Senza durata si aspettano 4 minuti")
    func unknownDuration() {
        #expect(rules.threshold(duration: nil) == 240)
    }

    @Test("Soglia personalizzata, anche senza tetto dei 4 minuti")
    func custom() {
        #expect(ScrobbleRules(fraction: 0.8, maximumWait: nil).threshold(duration: 600) == 480)
        #expect(ScrobbleRules(fraction: 0.25).threshold(duration: 400) == 100)
    }
}

@Suite("ScrobbleEngine — sequenze di eventi simulate")
struct ScrobbleEngineTests {
    let t0 = Date(timeIntervalSince1970: 1_762_900_000)

    func track(_ title: String = "Something", duration: TimeInterval? = 180, player: String = "com.apple.Music") -> Track {
        Track(title: title, artist: "The Beatles", album: "Abbey Road", duration: duration, playerBundleID: player)
    }

    func playing(_ position: TimeInterval, at date: Date) -> PlaybackState {
        PlaybackState(isPlaying: true, elapsedTime: position, timestamp: date)
    }

    func paused(_ position: TimeInterval, at date: Date) -> PlaybackState {
        PlaybackState(isPlaying: false, elapsedTime: position, timestamp: date)
    }

    /// Avanza a passi di 10 s (come i tick reali) e raccoglie gli invii.
    func run(_ engine: inout ScrobbleEngine, from: TimeInterval, to: TimeInterval) -> [ScrobbleTrack] {
        stride(from: from + 10, through: to, by: 10).flatMap { scrobbles(engine.tick(at: t0 + $0)) }
    }

    func scrobbles(_ events: [ScrobbleEngine.Event]) -> [ScrobbleTrack] {
        events.compactMap { if case .scrobble(let t) = $0 { t } else { nil } }
    }

    @Test("Annuncia il brano all'inizio e lo invia a metà, con l'orario di inizio")
    func basic() throws {
        var engine = ScrobbleEngine()
        let start = engine.update(track: track(), playback: playing(0, at: t0), at: t0)
        #expect(start.count == 1)
        guard case .nowPlaying(let announced) = start.first else { Issue.record("manca nowPlaying"); return }
        #expect(announced.title == "Something" && announced.startedAt == t0)
        #expect(engine.tick(at: t0 + 60).isEmpty)
        let sent = scrobbles(engine.tick(at: t0 + 90))
        #expect(sent.count == 1)
        #expect(sent.first?.startedAt == t0)
        #expect(engine.tick(at: t0 + 170).isEmpty, "un solo invio per sessione")
    }

    @Test("La pausa ferma il conteggio ma non lo azzera")
    func pauseKeepsTime() {
        var engine = ScrobbleEngine()
        _ = engine.update(track: track(), playback: playing(0, at: t0), at: t0)
        _ = engine.update(track: track(), playback: paused(60, at: t0 + 60), at: t0 + 60)
        // 10 minuti in pausa: non contano.
        #expect(engine.tick(at: t0 + 660).isEmpty)
        #expect(engine.listened == 60)
        let resume = engine.update(track: track(), playback: playing(60, at: t0 + 660), at: t0 + 660)
        #expect(resume.contains { if case .nowPlaying = $0 { true } else { false } }, "si riannuncia alla ripresa")
        #expect(scrobbles(engine.tick(at: t0 + 680)).isEmpty)
        #expect(scrobbles(engine.tick(at: t0 + 690)).count == 1)
    }

    @Test("Il seek in avanti non conta come ascolto")
    func seekDoesNotCount() {
        var engine = ScrobbleEngine()
        _ = engine.update(track: track(), playback: playing(0, at: t0), at: t0)
        _ = engine.update(track: track(), playback: playing(170, at: t0 + 10), at: t0 + 10)
        #expect(scrobbles(engine.tick(at: t0 + 20)).isEmpty)
        #expect(engine.listened == 20)
    }

    @Test("Cambiare brano prima della soglia non invia niente")
    func skipped() {
        var engine = ScrobbleEngine()
        _ = engine.update(track: track("A"), playback: playing(0, at: t0), at: t0)
        let events = engine.update(track: track("B"), playback: playing(0, at: t0 + 30), at: t0 + 30)
        #expect(scrobbles(events).isEmpty)
        #expect(engine.current?.title == "B")
        #expect(engine.listened == 0)
    }

    @Test("Ripeti brano: una nuova sessione quando riparte dall'inizio")
    func repeatOne() {
        var engine = ScrobbleEngine()
        var sent = 0
        _ = engine.update(track: track(), playback: playing(0, at: t0), at: t0)
        sent += run(&engine, from: 0, to: 180).count
        // Fine del brano e ripartenza da zero.
        sent += scrobbles(engine.update(track: track(), playback: playing(0, at: t0 + 181), at: t0 + 181)).count
        sent += run(&engine, from: 181, to: 281).count
        #expect(sent == 2)
    }

    @Test("Lo stesso ascolto che ricompare dopo un cambio di sorgente non si reinvia")
    func sourceFallbackDoesNotDuplicate() {
        var engine = ScrobbleEngine()
        _ = engine.update(track: track(), playback: playing(0, at: t0), at: t0)
        #expect(run(&engine, from: 0, to: 100).count == 1)
        // La sorgente cade (niente in riproduzione) e la successiva rivede lo stesso brano.
        _ = engine.update(track: nil, playback: .stopped, at: t0 + 101)
        let again = engine.update(track: track(), playback: playing(105, at: t0 + 105), at: t0 + 105)
        #expect(scrobbles(again).isEmpty)
        #expect(scrobbles(engine.tick(at: t0 + 179)).isEmpty)
        #expect(engine.currentIsScrobbled)
    }

    @Test("Brani troppo corti o senza artista non si inviano")
    func notEligible() {
        var engine = ScrobbleEngine()
        _ = engine.update(track: track(duration: 25), playback: playing(0, at: t0), at: t0)
        #expect(scrobbles(engine.tick(at: t0 + 25)).isEmpty)
        let anonymous = Track(title: "Jingle", duration: 200, playerBundleID: "x")
        #expect(engine.update(track: anonymous, playback: playing(0, at: t0 + 30), at: t0 + 30).isEmpty)
        #expect(engine.current == nil)
    }

    @Test("Un Mac in stop conta al massimo un minuto")
    func sleepGap() {
        var engine = ScrobbleEngine()
        _ = engine.update(track: track(duration: 3600), playback: playing(0, at: t0), at: t0)
        _ = engine.tick(at: t0 + 3000)
        #expect(engine.listened == ScrobbleEngine.maxTickGap)
    }

    @Test("Aprendo l'app a metà brano l'inizio è calcolato dalla posizione")
    func lateStart() {
        var engine = ScrobbleEngine()
        _ = engine.update(track: track(), playback: playing(40, at: t0), at: t0)
        #expect(engine.current?.startedAt == t0 - 40)
    }

    @Test("Durata arrivata dopo il titolo")
    func durationLater() {
        var engine = ScrobbleEngine()
        _ = engine.update(track: track(duration: nil), playback: playing(0, at: t0), at: t0)
        #expect(engine.timeUntilScrobble() == 240)
        _ = engine.update(track: track(duration: 100), playback: playing(5, at: t0 + 5), at: t0 + 5)
        #expect(engine.timeUntilScrobble() == 45)
    }
}

@Suite("TitleCleaner — titoli reali")
struct TitleCleanerTests {
    let cleaner = TitleCleaner()

    @Test("Suffissi rimossi dal titolo", arguments: [
        ("Let It Be (Remastered 2009)", "Let It Be"),
        ("Here Comes the Sun - Remastered 2019", "Here Comes the Sun"),
        ("Bohemian Rhapsody - Remastered 2011", "Bohemian Rhapsody"),
        ("Heroes - 2017 Remaster", "Heroes"),
        ("Wish You Were Here (2011 Remastered Version)", "Wish You Were Here"),
        ("Purple Rain [Remastered]", "Purple Rain"),
        ("Blinding Lights - Radio Edit", "Blinding Lights"),
        ("Smells Like Teen Spirit (Single Version)", "Smells Like Teen Spirit"),
        ("Hey Jude - Remastered 2015 - Radio Edit", "Hey Jude"),
        ("Never Gonna Give You Up (Official Music Video)", "Never Gonna Give You Up"),
        ("Bad Guy [Official Video]", "Bad Guy"),
        ("Yesterday (Remastered 2009) [Official Audio]", "Yesterday"),
        ("Strobe (Radio Edit)", "Strobe"),
    ])
    func titles(original: String, expected: String) {
        #expect(cleaner.cleanTitle(original) == expected)
    }

    @Test("Titoli da lasciare com'è", arguments: [
        "Live and Let Die",
        "Remember the Time",
        "Edit the World",
        "Hurt (Live)",
        "Song 2",
        "Under Pressure (feat. David Bowie)",
        "(Don't Fear) The Reaper",
    ])
    func untouched(title: String) {
        #expect(cleaner.cleanTitle(title) == title)
    }

    @Test("feat. tolto solo se richiesto", arguments: [
        ("Under Pressure (feat. David Bowie)", "Under Pressure"),
        ("Stay [ft. Justin Bieber]", "Stay"),
        ("Señorita feat. Camila Cabello", "Señorita"),
        ("Peaches (feat. Daniel Caesar & Giveon) - Radio Edit", "Peaches"),
    ])
    func featuring(original: String, expected: String) {
        let cleaner = TitleCleaner(options: .init(removesFeaturing: true))
        #expect(cleaner.cleanTitle(original) == expected)
    }

    @Test("Album artist delle compilation e suffissi degli album")
    func albumArtist() {
        let track = ScrobbleTrack(
            artist: "Toto", title: "Africa", album: "Hits of the 80s - Single", albumArtist: "Various Artists",
            startedAt: .now, playerBundleID: "com.apple.Music")
        let cleaned = cleaner.clean(track)
        #expect(cleaned.albumArtist == nil)
        #expect(cleaned.album == "Hits of the 80s")
        #expect(cleaner.clean(ScrobbleTrack(artist: "A", title: "T", album: "Rumours (Remastered)", albumArtist: "Fleetwood Mac", startedAt: .now, playerBundleID: "x")).albumArtist == "Fleetwood Mac")
        #expect(cleaner.cleanAlbum("Rumours (Remastered)") == "Rumours")
        #expect(cleaner.cleanAlbum("Abbey Road (Super Deluxe Edition)") == "Abbey Road (Super Deluxe Edition)")
    }

    @Test("Senza opzioni non cambia niente")
    func disabled() {
        let cleaner = TitleCleaner(options: .none)
        #expect(cleaner.cleanTitle("Let It Be (Remastered 2009)") == "Let It Be (Remastered 2009)")
    }
}

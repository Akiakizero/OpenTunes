// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
@testable import MediaCore
import Testing
@testable import OpenTunes

@Suite("Stato dei widget WidgetKit")
struct WidgetStateTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    func state(playing: Bool, elapsed: TimeInterval, at date: Date, title: String = "T") -> WidgetState {
        var s = WidgetState()
        s.title = title
        s.isPlaying = playing
        s.elapsedTime = elapsed
        s.timestamp = date
        s.duration = 200
        return s
    }

    @Test("Intervallo dell'avanzamento dall'inizio del brano alla fine")
    func interval() throws {
        let interval = try #require(state(playing: true, elapsed: 50, at: now).playbackInterval)
        #expect(interval.lowerBound == now.addingTimeInterval(-50))
        #expect(interval.upperBound == now.addingTimeInterval(150))
        var noDuration = state(playing: true, elapsed: 50, at: now)
        noDuration.duration = nil
        #expect(noDuration.playbackInterval == nil)
    }

    @Test("Frazione: avanza solo in riproduzione")
    func fraction() {
        #expect(state(playing: true, elapsed: 50, at: now).fraction(at: now.addingTimeInterval(50)) == 0.5)
        #expect(state(playing: false, elapsed: 50, at: now).fraction(at: now.addingTimeInterval(50)) == 0.25)
        #expect(state(playing: true, elapsed: 190, at: now).fraction(at: now.addingTimeInterval(100)) == 1)
    }

    @Test("Si ricarica solo se cambia qualcosa di visibile")
    func reload() {
        let base = state(playing: true, elapsed: 50, at: now)
        #expect(WidgetBridge.needsReload(from: nil, to: base))
        // La posizione ripubblicata con lo stesso inizio del brano non conta.
        #expect(!WidgetBridge.needsReload(from: base, to: state(playing: true, elapsed: 60, at: now.addingTimeInterval(10.5))))
        // Seek: l'inizio del brano si sposta di 30 s.
        #expect(WidgetBridge.needsReload(from: base, to: state(playing: true, elapsed: 90, at: now.addingTimeInterval(10))))
        #expect(WidgetBridge.needsReload(from: base, to: state(playing: false, elapsed: 50, at: now)))
        #expect(WidgetBridge.needsReload(from: base, to: state(playing: true, elapsed: 50, at: now, title: "Altro")))
        var loved = base
        loved.isLoved = true
        #expect(WidgetBridge.needsReload(from: base, to: loved))
    }

    @Test("Stato dal brano e dal profilo Last.fm")
    func fromModel() {
        let track = Track(title: "Titolo", artist: "Artista", duration: 180, playerBundleID: "com.apple.Music")
        let playback = PlaybackState(isPlaying: true, elapsedTime: 20, timestamp: now)
        let profile = LastFMProfile(
            user: .init(name: "utente", playCount: 10),
            recent: (0..<8).map { .init(artist: "A\($0)", title: "T\($0)", date: nil, isNowPlaying: false) },
            loved: [], topArtists: [.init(name: "A", playCount: 5)], fetchedAt: now)
        let state = WidgetBridge.state(
            track: track, playback: playback, playerName: "Musica", tint: AccentTint(dominant: RGB(r: 1, g: 0, b: 0)),
            canLove: true, isLoved: false, profile: profile)
        #expect(state.title == "Titolo")
        #expect(state.elapsedTime == 20)
        #expect(state.tint == [1, 0, 0])
        #expect(state.recentTracks.count == 6)
        #expect(state.lastFMUser == "utente")
        let idle = WidgetBridge.state(track: nil, playback: .stopped, playerName: nil, tint: nil, canLove: false, isLoved: false, profile: nil)
        #expect(!idle.hasTrack)
        #expect(idle.recentTracks.isEmpty)
    }

    @Test("Lo stato sopravvive alla codifica JSON")
    func codable() throws {
        let original = state(playing: true, elapsed: 12, at: now)
        let decoded = try JSONDecoder().decode(WidgetState.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}

@Suite("Posizione del widget sulla scrivania")
struct DesktopWidgetPlacementTests {
    let main = DesktopWidgetPlacement.Screen(id: "A", visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
    let external = DesktopWidgetPlacement.Screen(id: "B", visibleFrame: CGRect(x: 1440, y: 0, width: 2560, height: 1415))
    let size = CGSize(width: 260, height: 420)

    @Test("Prima volta: in alto a sinistra del primo schermo")
    func firstTime() throws {
        let frame = try #require(DesktopWidgetPlacement().frame(size: size, screens: [main, external]))
        #expect(frame.size == size)
        #expect(frame.minX == DesignSystem.Spacing.xxl)
        #expect(frame.maxY == 875 - DesignSystem.Spacing.xxl)
    }

    @Test("Ricorda il frame per ogni monitor e preferisce l'ultimo usato")
    func perDisplay() throws {
        var placement = DesktopWidgetPlacement()
        placement.save(CGRect(x: 100, y: 100, width: 260, height: 420), display: "A")
        placement.save(CGRect(x: 2000, y: 500, width: 520, height: 840), display: "B")
        #expect(placement.frame(size: size, screens: [main, external]) == CGRect(x: 2000, y: 500, width: 520, height: 840))
        // Monitor esterno scollegato: torna la posizione salvata sul principale.
        #expect(placement.frame(size: size, screens: [main]) == CGRect(x: 100, y: 100, width: 260, height: 420))
    }

    @Test("Cambiando layout l'altezza segue le nuove proporzioni")
    func layoutChange() throws {
        var placement = DesktopWidgetPlacement()
        placement.save(CGRect(x: 100, y: 100, width: 260, height: 420), display: "A")
        let frame = try #require(placement.frame(size: CGSize(width: 380, height: 136), screens: [main]))
        #expect(frame.width == 260)
        #expect(abs(frame.height - 260 * 136 / 380) < 0.001)
        #expect(frame.maxY == 520)
    }

    @Test("Resta dentro lo schermo")
    func clamp() {
        let r = DesktopWidgetPlacement.clamp(CGRect(x: 1400, y: -50, width: 260, height: 420), to: main.visibleFrame)
        #expect(r == CGRect(x: 1180, y: 0, width: 260, height: 420))
    }
}

@Suite("Player nel notch")
@MainActor
struct NotchTests {
    // MacBook Pro 16": schermo 1728×1117, notch di 200×38 punti.
    let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let visible = CGRect(x: 0, y: 0, width: 1728, height: 1079)

    @Test("Misura del notch dalle aree ai lati")
    func notchSize() {
        let g = NotchGeometry(
            screenFrame: screen, visibleFrame: visible,
            leftArea: CGRect(x: 0, y: 1079, width: 764, height: 38), rightArea: CGRect(x: 964, y: 1079, width: 764, height: 38), safeTop: 38)
        #expect(g.hasNotch)
        #expect(g.notchSize == CGSize(width: 200, height: 38))
        #expect(g.menuBarHeight == 38)
        #expect(g.panelFrame.midX == screen.midX)
        #expect(g.panelFrame.maxY == screen.maxY)
    }

    @Test("Senza notch: capsula nella menu bar")
    func notchless() {
        let g = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1415),
            leftArea: nil, rightArea: nil, safeTop: 0)
        #expect(!g.hasNotch)
        #expect(g.notchSize.width == DesignSystem.Size.notchlessCapsuleWidth)
        #expect(g.notchSize.height <= 25)
    }

    @Test("Area del mouse in coordinate schermo")
    func hitRect() {
        let panel = CGRect(x: 600, y: 857, width: 528, height: 260)
        let rect = NotchGeometry.hitRect(local: CGRect(x: 100, y: 0, width: 328, height: 38), panelFrame: panel, margin: 0)
        #expect(rect == CGRect(x: 700, y: 1079, width: 328, height: 38))
    }

    @Test("A riposo si vede solo mentre suona")
    func resting() {
        #expect(NotchState.resting(hasTrack: true, isPlaying: true) == .closed)
        #expect(NotchState.resting(hasTrack: true, isPlaying: false) == .hidden)
        #expect(NotchState.resting(hasTrack: false, isPlaying: true) == .hidden)
    }

    @Test("Con il titolo a destra la forma si sposta per restare centrata sul notch")
    func peekOffset() {
        #expect(NotchPlayerView.horizontalOffset(for: .closed, notchHeight: 38) == 0)
        #expect(NotchPlayerView.horizontalOffset(for: .open, notchHeight: 38) == 0)
        #expect(NotchPlayerView.horizontalOffset(for: .peek, notchHeight: 38) == (DesignSystem.Size.notchPeekWidth - 38) / 2)
    }

    @Test("Nel notch chiuso la copertina ha lo stesso margine sopra, sotto e verso l'esterno")
    func closedArtworkInset() {
        let height: CGFloat = 38
        let wing = NotchPlayerView.wings(for: .closed, notchHeight: height).left
        let artwork = NotchPlayerView.closedArtworkSize(notchHeight: height)
        #expect(wing == height)
        #expect((wing - artwork) / 2 == (height - artwork) / 2)
        #expect(artwork < height)
    }
}

@Suite("Preferenze della fase 3")
@MainActor
struct Phase3SettingsTests {
    @Test("Valori predefiniti e salvataggio")
    func defaults() throws {
        let suite = "org.opentunes.tests.phase3.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.notchEnabled)
        #expect(!settings.desktopWidgetVisible)
        #expect(settings.desktopWidgetLayout == .card)
        #expect(!settings.dockShowsArtwork)
        settings.desktopWidgetLayout = .horizontal
        settings.notchEnabled = false
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.desktopWidgetLayout == .horizontal)
        #expect(!reloaded.notchEnabled)
    }

    @Test("Miniatura quadrata per widget e Dock")
    func thumbnail() throws {
        let image = PreviewData.makeArtwork(top: .systemRed, bottom: .systemBlue, side: 400)
        let thumb = try #require(image.squareThumbnail(side: 64, cornerFraction: 0.2, inset: 6))
        #expect(thumb.size == NSSize(width: 64, height: 64))
        #expect(thumb.pngData != nil)
    }
}

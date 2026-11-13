// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import MediaCore
import Testing
@testable import OpenTunes

@Suite("Superfici attivabili")
@MainActor
struct SurfaceSettingsTests {
    func makeSettings() -> (AppSettings, UserDefaults, String) {
        let suite = "org.opentunes.tests.phase4.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        return (AppSettings(defaults: defaults), defaults, suite)
    }

    @Test("Di default sono attive tutte tranne il widget sulla scrivania")
    func defaults() {
        let (settings, _, suite) = makeSettings()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        #expect(Surface.allCases.filter(settings.isEnabled) == [.menuBar, .notch, .floating, .systemWidget])
    }

    @Test("Una superficie spenta resta spenta dopo il riavvio")
    func persists() {
        let (settings, defaults, suite) = makeSettings()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        for surface in Surface.allCases { settings.setEnabled(surface, false) }
        let reloaded = AppSettings(defaults: defaults)
        #expect(Surface.allCases.allSatisfy { !reloaded.isEnabled($0) })
        #expect(!reloaded.hasInteractiveSurface)
    }

    @Test("Finestra flottante disattivata: non si mostra né con la scorciatoia")
    func floatingDisabled() {
        let model = AppModel.preview()
        model.settings.floatingVisible = true
        #expect(model.settings.showsFloatingWindow)
        model.settings.setEnabled(.floating, false)
        #expect(!model.settings.floatingVisible)
        model.toggleFloatingWindow()
        #expect(!model.settings.showsFloatingWindow)
        model.settings.setEnabled(.floating, true)
        model.toggleFloatingWindow()
        #expect(model.settings.showsFloatingWindow)
    }

    @Test("Temi: la vecchia opzione «tinta dalla copertina» spenta diventa il tema monocromo")
    func themeMigration() {
        let (_, defaults, suite) = makeSettings()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "tintsWithArtwork")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.theme == .monochrome)
        #expect(!settings.tintsWithArtwork)
        settings.theme = .transparent
        #expect(AppSettings(defaults: defaults).theme == .transparent)
    }

    @Test("Senza tinta la copertina non colora le superfici")
    func themeTint() {
        let model = AppModel.preview()
        #expect(model.tint != nil)
        model.settings.theme = .opaque
        model.updateArtwork(force: true)
        #expect(model.tint == nil)
    }
}

@Suite("Widget di macOS disattivati")
struct DisabledWidgetTests {
    @Test("Lo stato «disattivato» non contiene il brano e si decodifica")
    func disabledState() throws {
        let state = WidgetState.disabled
        #expect(state.isDisabled == true)
        #expect(!state.hasTrack)
        let decoded = try JSONDecoder().decode(WidgetState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
        // Gli stati salvati prima della fase 4 non hanno la chiave.
        let old = try JSONDecoder().decode(WidgetState.self, from: Data(#"{"isPlaying":false,"elapsedTime":0,"timestamp":0,"canLove":false,"isLoved":false,"recentTracks":[],"topArtists":[]}"#.utf8))
        #expect(old.isDisabled == nil)
    }
}

@Suite("Testi nel modello")
@MainActor
struct ModelLyricsTests {
    @Test("Riga corrente dalla posizione del brano")
    func currentLine() {
        let model = AppModel.preview()
        #expect(model.currentLyricLine() == nil)
        model.lyrics = .found(Lyrics(lines: LRCParser.parse("[00:00.00]Inizio\n[99:00.00]Fine")))
        #expect(model.currentLyricLine() == "Inizio")
    }

    @Test("Visualizer: altezze sempre tra 0.2 e 1")
    func visualizer() {
        for bar in 0..<6 {
            for step in 0..<200 {
                let level = VisualizerBars.level(bar: bar, time: Double(step) * 0.05)
                #expect((0.2...1).contains(level))
            }
        }
    }
}

@Suite("Spettro del visualizer")
struct SpectrumAnalyzerTests {
    func levels(frequency: Double, rate: Double = 48_000) -> [Float] {
        var analyzer = SpectrumAnalyzer(bands: 5)
        let samples = (0..<Int(rate / 2)).map { Float(sin(2 * .pi * frequency * Double($0) / rate)) * 0.5 }
        samples.withUnsafeBufferPointer { buffer in
            // Blocchi da 512 campioni, come arrivano da Core Audio.
            for start in stride(from: 0, to: buffer.count, by: 512) {
                analyzer.process(buffer.baseAddress! + start, frames: min(512, buffer.count - start), channels: 1, sampleRate: rate)
            }
        }
        #expect(analyzer.isReceivingAudio)
        return analyzer.levels
    }

    @Test("Un seno grave accende la prima banda, uno acuto l'ultima")
    func bands() {
        let low = levels(frequency: 80)
        #expect(low.firstIndex(of: low.max() ?? 0) == 0)
        let high = levels(frequency: 8_000)
        #expect(high.firstIndex(of: high.max() ?? 0) == 4)
        #expect(high.allSatisfy { (0...1).contains($0) })
    }

    @Test("Sensibilità automatica: un seno costante arriva in alto, poi nel silenzio la barra cade a zero")
    func autosensAndGravity() {
        var analyzer = SpectrumAnalyzer(bands: 6)
        let rate = 48_000.0
        let tone = (0..<Int(rate * 2)).map { Float(sin(2 * .pi * 440 * Double($0) / rate)) * 0.3 }
        tone.withUnsafeBufferPointer { buffer in
            for start in stride(from: 0, to: buffer.count, by: 512) {
                analyzer.process(buffer.baseAddress! + start, frames: min(512, buffer.count - start), channels: 1, sampleRate: rate)
            }
        }
        let loudest = analyzer.levels.max() ?? 0
        #expect(loudest > 0.6)
        // Le altre bande restano più basse di quella del seno.
        #expect(analyzer.levels.filter { $0 > loudest * 0.9 }.count <= 2)
        let zeros = [Float](repeating: 0, count: Int(rate))
        zeros.withUnsafeBufferPointer { buffer in
            for start in stride(from: 0, to: buffer.count, by: 512) {
                analyzer.process(buffer.baseAddress! + start, frames: 512, channels: 1, sampleRate: rate)
            }
        }
        #expect((analyzer.levels.max() ?? 1) < 0.05)
    }

    @Test("Bande senza sovrapposizioni e con almeno un bin")
    func layout() {
        let layout = SpectrumAnalyzer.layout(bands: 6, sampleRate: 48_000)
        for (a, b) in zip(layout.ranges, layout.ranges.dropFirst()) { #expect(a.upperBound < b.lowerBound) }
        #expect(layout.ranges.allSatisfy { !$0.isEmpty })
    }

    @Test("Palette della copertina: colori diversi tra loro")
    func palette() {
        let pixels = Array(repeating: RGB(r: 0.9, g: 0.1, b: 0.1), count: 300) + Array(repeating: RGB(r: 0.1, g: 0.2, b: 0.9), count: 200)
            + Array(repeating: RGB(r: 0.88, g: 0.12, b: 0.1), count: 50)
        let palette = AccentTint.palette(in: pixels)
        #expect(palette.count == 2)
        #expect(palette[0].r > 0.8)
        #expect(palette[1].b > 0.8)
        #expect(RGB(r: 0.1, g: 0.05, b: 0.02).vivid().brightness >= 0.7)
    }

    @Test("Il silenzio non conta come audio")
    func silence() {
        var analyzer = SpectrumAnalyzer(bands: 5)
        let zeros = [Float](repeating: 0, count: 48_000 * 2)
        zeros.withUnsafeBufferPointer { analyzer.process($0.baseAddress!, frames: $0.count, channels: 1, sampleRate: 48_000) }
        #expect(!analyzer.isReceivingAudio)
    }
}

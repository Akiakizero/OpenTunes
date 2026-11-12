// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Testing
@testable import OpenTunes

@Suite("Formato del titolo")
struct TitleFormatTests {
    @Test("Artista e titolo")
    func full() {
        #expect(TitleFormat("{artist} — {title}").render(title: "T", artist: "A", album: nil) == "A — T")
    }

    @Test("Senza artista sparisce anche il separatore")
    func missingArtist() {
        #expect(TitleFormat("{artist} — {title}").render(title: "T", artist: nil, album: nil) == "T")
        #expect(TitleFormat("{title} · {album}").render(title: "T", artist: nil, album: "") == "T")
    }

    @Test("Testo libero e segnaposto sconosciuti restano com'è")
    func literals() {
        #expect(TitleFormat("♪ {title} by {artist}").render(title: "T", artist: "A", album: nil) == "♪ T by A")
        #expect(TitleFormat("{foo} {title}").render(title: "T", artist: nil, album: nil) == "{foo} T")
    }

    @Test("Formato vuoto → titolo")
    func empty() {
        #expect(TitleFormat("").render(title: "T", artist: "A", album: nil) == "T")
    }
}

@Suite("Modalità compatta accanto al notch")
struct NotchLayoutTests {
    let notch: ClosedRange<CGFloat> = 660...850

    @Test("Senza notch non è mai compatta")
    func noNotch() {
        #expect(!NotchLayout.shouldBeCompact(itemFrame: CGRect(x: 100, y: 0, width: 300, height: 24), fullWidth: 300, notch: nil, isCompact: false))
    }

    @Test("Diventa compatta se l'elemento finisce sotto il notch")
    func overlapsNotch() {
        #expect(NotchLayout.shouldBeCompact(itemFrame: CGRect(x: 800, y: 0, width: 300, height: 24), fullWidth: 300, notch: notch, isCompact: false))
        #expect(!NotchLayout.shouldBeCompact(itemFrame: CGRect(x: 900, y: 0, width: 300, height: 24), fullWidth: 300, notch: notch, isCompact: false))
    }

    @Test("Torna piena solo se c'è spazio con margine")
    func hysteresis() {
        // Bordo destro a 1200: la versione piena (300) inizierebbe a 900 → c'è spazio.
        #expect(!NotchLayout.shouldBeCompact(itemFrame: CGRect(x: 1150, y: 0, width: 50, height: 24), fullWidth: 300, notch: notch, isCompact: true))
        // Inizierebbe a 855: oltre il notch ma dentro il margine → resta compatta.
        #expect(NotchLayout.shouldBeCompact(itemFrame: CGRect(x: 1105, y: 0, width: 50, height: 24), fullWidth: 300, notch: notch, isCompact: true))
    }
}

@Suite("Tinta dalla copertina")
struct AccentTintTests {
    @Test("Contrasto WCAG di riferimento")
    func contrast() {
        #expect(abs(RGB.contrast(.white, .black) - 21) < 0.01)
        #expect(abs(RGB.contrast(.white, .white) - 1) < 0.01)
    }

    @Test("La tinta rispetta il contrasto minimo in entrambi i temi", arguments: [
        RGB(r: 1, g: 0.85, b: 0.2), RGB(r: 0.1, g: 0.1, b: 0.5), RGB(r: 0.5, g: 0.5, b: 0.5),
    ])
    func adjusted(color: RGB) {
        let tint = AccentTint(dominant: color)
        #expect(RGB.contrast(tint.rgb(for: .dark), .white) >= AccentTint.minimumContrast)
        #expect(RGB.contrast(tint.rgb(for: .light), .black) >= AccentTint.minimumContrast)
    }

    @Test("Il colore dominante preferisce i pixel colorati a nero e bianco")
    func dominant() throws {
        let red = RGB(r: 0.9, g: 0.1, b: 0.1)
        let pixels = Array(repeating: RGB.black, count: 50) + Array(repeating: RGB.white, count: 30) + Array(repeating: red, count: 20)
        let result = try #require(AccentTint.dominant(in: pixels))
        #expect(abs(result.r - red.r) < 0.05 && result.g < 0.2)
    }

    @Test("Estrazione da un'immagine")
    @MainActor
    func fromImage() throws {
        let image = NSImage(size: NSSize(width: 40, height: 40), flipped: false) { rect in
            NSColor(srgbRed: 0.1, green: 0.6, blue: 0.2, alpha: 1).setFill()
            rect.fill()
            return true
        }
        let tint = try #require(AccentTint.from(image))
        #expect(tint.dominant.g > tint.dominant.r && tint.dominant.g > tint.dominant.b)
    }
}

@MainActor
@Suite("Preferenze")
struct AppSettingsTests {
    @Test("Gli elementi mancanti tornano in coda e le preferenze si salvano")
    func persistence() throws {
        let suite = "org.opentunes.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["controls"], forKey: "menuBarOrder")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.menuBarOrder == [.controls, .artwork, .title])
        settings.setVisible(.title, false)
        settings.leftClick = .playPause
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.visibleMenuBarElements == [.controls, .artwork])
        #expect(reloaded.leftClick == .playPause)
    }
}

@MainActor
@Suite("Preferenze predefinite")
struct DefaultSettingsTests {
    @Test("HUD e notifiche al cambio brano sono spenti di default")
    func trackChangeAlertsOffByDefault() throws {
        let suite = "org.opentunes.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.hudOnTrackChange)
        #expect(settings.notificationMode == .off)
    }
}

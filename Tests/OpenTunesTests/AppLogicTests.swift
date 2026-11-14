// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MediaCore
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

@Suite("Riduzione automatica dell'elemento in menu bar")
struct MenuBarFitTests {
    let notch: ClosedRange<CGFloat> = 660...850
    let widths: [MenuBarLevel: CGFloat] = [.full: 300, .compact: 70, .icon: 30]
    let start = Date(timeIntervalSinceReferenceDate: 0)

    func observe(_ fit: inout MenuBarFit, edge: CGFloat, notch: ClosedRange<CGFloat>?, hidden: Bool = false, at seconds: TimeInterval,
                 widths: [MenuBarLevel: CGFloat]? = nil) {
        fit.update(.init(rightEdge: edge, widths: widths ?? self.widths, notch: notch, isHidden: hidden, now: start + seconds))
    }

    @Test("Senza notch e con l'elemento visibile resta piena")
    func noNotch() {
        var fit = MenuBarFit()
        observe(&fit, edge: 400, notch: nil, at: 0)
        #expect(fit.level == .full)
    }

    @Test("Con il notch sceglie il livello più grande che sta a destra")
    func notchCap() {
        var fit = MenuBarFit()
        observe(&fit, edge: 1100, notch: notch, at: 0)   // 1100 - 300 = 800 < 850
        #expect(fit.level == .compact)
        var tight = MenuBarFit()
        observe(&tight, edge: 900, notch: notch, at: 0)  // 900 - 70 = 830 < 850, 900 - 30 = 870
        #expect(tight.level == .icon)
    }

    @Test("Con il notch risale solo con margine")
    func notchHysteresis() {
        var fit = MenuBarFit()
        observe(&fit, edge: 1100, notch: notch, at: 0)
        #expect(fit.level == .compact)
        observe(&fit, edge: 1165, notch: notch, at: 10)  // 865: fuori dal notch ma dentro il margine per salire
        #expect(fit.level == .compact)
        observe(&fit, edge: 1200, notch: notch, at: 20)  // 900
        #expect(fit.level == .full)
    }

    @Test("Senza notch: nascosto scende di un livello alla volta e non oscilla")
    func hiddenStepsDown() {
        var fit = MenuBarFit()
        observe(&fit, edge: 1200, notch: nil, hidden: true, at: 0)
        #expect(fit.level == .compact)
        // Ancora nascosto dopo il cambio: scende a icona.
        observe(&fit, edge: 1200, notch: nil, hidden: true, at: 2)
        #expect(fit.level == .icon)
        // Visibile come icona: compatta (70 pt) è già fallita, quindi non si riprova subito.
        observe(&fit, edge: 1200, notch: nil, at: 10)
        #expect(fit.level == .icon)
        // Dopo 5 minuti si riprova.
        observe(&fit, edge: 1200, notch: nil, at: 400)
        #expect(fit.level == .compact)
    }

    @Test("Senza notch risale subito se il titolo è più corto di quello che non stava")
    func shorterTitle() {
        var fit = MenuBarFit()
        observe(&fit, edge: 1200, notch: nil, hidden: true, at: 0)
        #expect(fit.level == .compact)
        observe(&fit, edge: 1200, notch: nil, at: 5)
        #expect(fit.level == .compact)
        observe(&fit, edge: 1200, notch: nil, at: 10, widths: [.full: 200, .compact: 70, .icon: 30])
        #expect(fit.level == .full)
    }

    @Test("Con il notch resta un margine anche per restare: a 6 punti dal notch il sistema lo nasconde")
    func notchMargin() {
        var fit = MenuBarFit()
        observe(&fit, edge: 1156, notch: notch, at: 0)  // 1156 - 300 = 856: 6 punti dal notch, troppo vicino
        #expect(fit.level == .compact)
    }

    @Test("Dopo un fallimento non riprova finché il bordo destro non si sposta davvero")
    func noFlapping() {
        var fit = MenuBarFit()
        observe(&fit, edge: 1235, notch: nil, hidden: true, at: 0)
        #expect(fit.level == .compact)
        observe(&fit, edge: 1243, notch: nil, at: 13)  // 8 punti: non basta
        #expect(fit.level == .compact)
        observe(&fit, edge: 1275, notch: nil, at: 23)
        #expect(fit.level == .full)
    }

    @Test("Reset torna alla versione piena")
    func reset() {
        var fit = MenuBarFit()
        observe(&fit, edge: 900, notch: notch, at: 0)
        fit.reset()
        #expect(fit.level == .full)
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
        #expect(settings.menuBarOrder == [.controls, .artwork, .title, .love])
        #expect(!settings.isVisible(.love), "gli elementi nuovi come il love partono nascosti")
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

@MainActor
@Suite("Preferenze dello scrobbling")
struct ScrobblingSettingsTests {
    func makeSettings() throws -> (AppSettings, UserDefaults, String) {
        let suite = "org.opentunes.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (AppSettings(defaults: defaults), defaults, suite)
    }

    @Test("Browser esclusi di default, i player nuovi fanno scrobbling")
    func playerFilter() throws {
        let (settings, defaults, suite) = try makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(!settings.scrobbles("com.apple.Safari"))
        #expect(settings.scrobbles("com.apple.Music"))
        #expect(settings.scrobbles("org.videolan.vlc"))
        settings.setScrobbles("com.apple.Safari", true)
        settings.setScrobbles("org.videolan.vlc", false)
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.scrobbles("com.apple.Safari") && !reloaded.scrobbles("org.videolan.vlc"))
    }

    @Test("Soglia e pulizia passano allo scrobbler")
    func configuration() throws {
        let (settings, defaults, suite) = try makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.scrobblePercent = 80
        settings.scrobbleCapsAtFourMinutes = false
        settings.cleansFeaturing = true
        let model = AppModel(settings: settings)
        let configuration = model.scrobblerConfiguration
        #expect(configuration.rules.threshold(duration: 600) == 480)
        #expect(configuration.cleaner.removesFeaturing)
        #expect(configuration.excludedBundleIDs.contains("com.google.Chrome"))
    }

    @Test("La chiave personale vale solo se completa; la secret va nel Portachiavi")
    func customKey() throws {
        let (settings, defaults, suite) = try makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let secrets = MemorySecretStore()
        let model = AppModel(settings: settings, secrets: secrets)
        settings.lastFMUsesCustomKey = true
        settings.lastFMCustomAPIKey = "KEY"
        #expect(model.lastFMCredentials == nil)
        model.setCustomLastFMSecret(" SECRET ")
        #expect(model.lastFMCredentials == LastFMCredentials(apiKey: "KEY", secret: "SECRET"))
        #expect(secrets.secret(for: SecretAccount.lastFMCustomSecret) == "SECRET")
        #expect(defaults.string(forKey: "lastFMCustomSecret") == nil, "mai in chiaro nelle preferenze")
    }
}

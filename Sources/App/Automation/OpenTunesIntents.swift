// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import Foundation

/// Collega gli App Intents di Comandi Rapidi, Siri e Spotlight al modello dell'app.
///
/// Gli intent girano nel processo dell'app (che il sistema avvia se è chiusa): `AppDelegate` imposta `model`
/// subito dopo l'avvio, gli intent aspettano al massimo 2 secondi.
@MainActor
enum AppIntentBridge {
    static weak var model: AppModel?

    static func current() async throws -> AppModel {
        for _ in 0..<20 where model == nil {
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard let model else { throw OpenTunesIntentError.notRunning }
        guard model.settings.appIntentsEnabled else { throw OpenTunesIntentError.disabled }
        return model
    }
}

enum OpenTunesIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notRunning, disabled, nothingPlaying, unavailable(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notRunning: "OpenTunes non è pronto."
        case .disabled: "Comandi Rapidi e Siri sono spenti nelle impostazioni di OpenTunes."
        case .nothingPlaying: "Niente in riproduzione."
        case .unavailable(let message): "\(message)"
        }
    }
}

/// «Che brano sta suonando?»: risponde con titolo e artista e restituisce il testo per altre azioni.
struct NowPlayingIntent: AppIntent {
    static let title: LocalizedStringResource = "Brano in riproduzione"
    static let description = IntentDescription("Dice quale brano sta suonando e con quale player.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = try await MainActor.run { () throws -> String in
            guard let model = AppIntentBridge.model, model.settings.appIntentsEnabled else { throw OpenTunesIntentError.disabled }
            guard let track = model.track else { throw OpenTunesIntentError.nothingPlaying }
            return [track.title, track.artist].compactMap { $0 }.joined(separator: " — ")
        }
        return .result(value: text, dialog: "\(text)")
    }
}

struct AppPlayPauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Play o pausa"
    static let description = IntentDescription("Mette in pausa o riprende il brano.")

    func perform() async throws -> some IntentResult {
        try await AppIntentBridge.current().perform(.playPause)
        return .result()
    }
}

struct AppNextTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Brano successivo"

    func perform() async throws -> some IntentResult {
        try await AppIntentBridge.current().perform(.next)
        return .result()
    }
}

struct AppPreviousTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Brano precedente"

    func perform() async throws -> some IntentResult {
        try await AppIntentBridge.current().perform(.previous)
        return .result()
    }
}

struct LoveTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Love del brano"
    static let description = IntentDescription("Aggiunge o toglie il love su Last.fm (o il preferito in Musica).")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try await AppIntentBridge.current()
        guard model.canLove else { throw OpenTunesIntentError.unavailable(String(localized: "Love non disponibile per questo brano.")) }
        let loved = !model.isLoved
        model.toggleLove(feedback: true)
        return .result(dialog: loved ? "Love aggiunto." : "Love tolto.")
    }
}

/// Link universale song.link del brano (copiato anche negli appunti).
struct CopyShareLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Copia il link universale"
    static let description = IntentDescription("Cerca il brano su song.link e copia il link che funziona con tutti i servizi.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<URL> & ProvidesDialog {
        let model = try await AppIntentBridge.current()
        guard model.canShare else { throw OpenTunesIntentError.nothingPlaying }
        do {
            let url = try await model.shareLink()
            model.copyToPasteboard(url)
            return .result(value: url, dialog: "Link copiato.")
        } catch {
            throw OpenTunesIntentError.unavailable(String(describing: error))
        }
    }
}

/// Mostra il testo nella finestra flottante grande.
struct ShowLyricsIntent: AppIntent {
    static let title: LocalizedStringResource = "Mostra il testo"
    static let description = IntentDescription("Apre la finestra flottante con il testo sincronizzato del brano.")

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = try await AppIntentBridge.current()
        guard model.settings.lyricsEnabled, model.settings.floatingEnabled else {
            throw OpenTunesIntentError.unavailable(String(localized: "Testi o finestra flottante spenti nelle impostazioni."))
        }
        model.showLyrics()
        return .result()
    }
}

/// Frasi per Siri e Spotlight, in italiano e in inglese.
struct OpenTunesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NowPlayingIntent(),
            phrases: [
                "Che brano sta suonando su \(.applicationName)?",
                "Cosa suona \(.applicationName)",
                "What's playing on \(.applicationName)",
            ],
            shortTitle: "In riproduzione", systemImageName: "music.note")
        AppShortcut(
            intent: LoveTrackIntent(),
            phrases: ["Love del brano con \(.applicationName)", "Love this song with \(.applicationName)"],
            shortTitle: "Love", systemImageName: "heart")
        AppShortcut(
            intent: CopyShareLinkIntent(),
            phrases: ["Copia il link del brano con \(.applicationName)", "Copy the song link with \(.applicationName)"],
            shortTitle: "Copia link", systemImageName: "link")
        AppShortcut(
            intent: ShowLyricsIntent(),
            phrases: ["Mostra il testo con \(.applicationName)", "Show lyrics in \(.applicationName)"],
            shortTitle: "Testo", systemImageName: "quote.bubble")
        AppShortcut(
            intent: AppPlayPauseIntent(),
            phrases: ["Pausa con \(.applicationName)", "Play or pause with \(.applicationName)"],
            shortTitle: "Play/pausa", systemImageName: "playpause")
        AppShortcut(
            intent: AppNextTrackIntent(),
            phrases: ["Brano successivo con \(.applicationName)", "Next song with \(.applicationName)"],
            shortTitle: "Successivo", systemImageName: "forward")
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents

/// Comandi che i pulsanti dei widget chiedono all'app.
enum WidgetCommand: String, Sendable {
    case playPause, next, previous, toggleLove
}

/// Collega gli intent all'app. Nell'estensione resta `nil`: gli intent `AudioPlaybackIntent`
/// vengono eseguiti dal sistema nel processo dell'app (che viene avviata se non è aperta).
@MainActor
enum WidgetCommandBridge {
    static var handler: ((WidgetCommand) async -> Void)?

    static func run(_ command: WidgetCommand) async {
        // All'avvio a freddo l'app imposta il gestore subito dopo `applicationDidFinishLaunching`.
        for _ in 0..<20 where handler == nil {
            try? await Task.sleep(for: .milliseconds(100))
        }
        await handler?(command)
    }
}

struct PlayPauseIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play/pausa"
    static let description = IntentDescription("Mette in pausa o riprende il brano in riproduzione.")

    func perform() async throws -> some IntentResult {
        await WidgetCommandBridge.run(.playPause)
        return .result()
    }
}

struct NextTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Brano successivo"

    func perform() async throws -> some IntentResult {
        await WidgetCommandBridge.run(.next)
        return .result()
    }
}

struct PreviousTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Brano precedente"

    func perform() async throws -> some IntentResult {
        await WidgetCommandBridge.run(.previous)
        return .result()
    }
}

/// Love del brano. È un `AudioPlaybackIntent` solo per girare nel processo dell'app,
/// dove ci sono la sessione Last.fm e AppleScript (l'estensione è in sandbox).
struct ToggleLoveIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Love del brano"
    static let description = IntentDescription("Aggiunge o toglie il love su Last.fm (o il preferito in Musica).")

    func perform() async throws -> some IntentResult {
        await WidgetCommandBridge.run(.toggleLove)
        return .result()
    }
}

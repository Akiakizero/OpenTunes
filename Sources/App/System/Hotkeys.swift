// SPDX-License-Identifier: GPL-3.0-or-later

import KeyboardShortcuts

/// Scorciatoie globali, configurabili nelle impostazioni. Nessuna combinazione predefinita:
/// così non si rubano tasti ad altre app finché l'utente non li sceglie.
extension KeyboardShortcuts.Name {
    static let togglePlayPause = Self("togglePlayPause")
    static let nextTrack = Self("nextTrack")
    static let previousTrack = Self("previousTrack")
    static let volumeUp = Self("volumeUp")
    static let volumeDown = Self("volumeDown")
    static let toggleFloatingWindow = Self("toggleFloatingWindow")
    static let love = Self("love")
    static let addToLibrary = Self("addToLibrary")
    static let switchPlayer = Self("switchPlayer")
}

@MainActor
enum Hotkeys {
    /// Le scorciatoie nell'ordine in cui compaiono nelle impostazioni.
    static let all: [(name: KeyboardShortcuts.Name, label: String)] = [
        (.togglePlayPause, String(localized: "Play/pausa")),
        (.nextTrack, String(localized: "Brano successivo")),
        (.previousTrack, String(localized: "Brano precedente")),
        (.volumeUp, String(localized: "Alza il volume")),
        (.volumeDown, String(localized: "Abbassa il volume")),
        (.toggleFloatingWindow, String(localized: "Mostra/nascondi finestra flottante")),
        (.love, String(localized: "Love / preferito")),
        (.addToLibrary, String(localized: "Aggiungi alla libreria di Musica")),
        (.switchPlayer, String(localized: "Cambia player attivo")),
    ]

    static func register(model: AppModel) {
        KeyboardShortcuts.onKeyUp(for: .togglePlayPause) { model.perform(.playPause) }
        KeyboardShortcuts.onKeyUp(for: .nextTrack) { model.perform(.next) }
        KeyboardShortcuts.onKeyUp(for: .previousTrack) { model.perform(.previous) }
        // Volume su keyDown: risponde subito, senza aspettare il rilascio.
        KeyboardShortcuts.onKeyDown(for: .volumeUp) { model.changeVolume(by: SystemVolume.step) }
        KeyboardShortcuts.onKeyDown(for: .volumeDown) { model.changeVolume(by: -SystemVolume.step) }
        KeyboardShortcuts.onKeyUp(for: .toggleFloatingWindow) { model.toggleFloatingWindow() }
        // Le azioni da scorciatoia danno un riscontro con l'HUD.
        KeyboardShortcuts.onKeyUp(for: .love) { model.toggleLove(feedback: true) }
        KeyboardShortcuts.onKeyUp(for: .addToLibrary) { model.addToLibrary(feedback: true) }
        KeyboardShortcuts.onKeyUp(for: .switchPlayer) { model.switchPlayer() }
        // Interruttore generale nelle impostazioni (Funzioni): spente, nessuna combinazione viene intercettata.
        model.tasks.append(observeChanges({ model.settings.hotkeysEnabled }) { KeyboardShortcuts.isEnabled = $0 })
    }
}

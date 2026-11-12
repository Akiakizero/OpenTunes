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
}

@MainActor
enum Hotkeys {
    /// Le scorciatoie nell'ordine in cui compaiono nelle impostazioni.
    static let all: [(name: KeyboardShortcuts.Name, label: String)] = [
        (.togglePlayPause, "Play/pausa"),
        (.nextTrack, "Brano successivo"),
        (.previousTrack, "Brano precedente"),
        (.volumeUp, "Alza il volume"),
        (.volumeDown, "Abbassa il volume"),
        (.toggleFloatingWindow, "Mostra/nascondi finestra flottante"),
    ]

    static func register(model: AppModel) {
        KeyboardShortcuts.onKeyUp(for: .togglePlayPause) { model.perform(.playPause) }
        KeyboardShortcuts.onKeyUp(for: .nextTrack) { model.perform(.next) }
        KeyboardShortcuts.onKeyUp(for: .previousTrack) { model.perform(.previous) }
        // Volume su keyDown: risponde subito, senza aspettare il rilascio.
        KeyboardShortcuts.onKeyDown(for: .volumeUp) { model.changeVolume(by: SystemVolume.step) }
        KeyboardShortcuts.onKeyDown(for: .volumeDown) { model.changeVolume(by: -SystemVolume.step) }
        KeyboardShortcuts.onKeyUp(for: .toggleFloatingWindow) { model.toggleFloatingWindow() }
    }
}

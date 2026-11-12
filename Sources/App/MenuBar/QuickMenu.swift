// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Menu rapido (clic destro sull'elemento in menu bar).
@MainActor
enum QuickMenu {
    static func make(model: AppModel, onOpenSettings: @escaping () -> Void, onOpenDebug: @escaping () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if let track = model.track {
            let header = NSMenuItem(title: track.title, action: nil, keyEquivalent: "")
            header.isEnabled = false
            if let artist = track.artist { header.subtitle = artist }
            if let artwork = model.artwork {
                let image = artwork.copy() as? NSImage
                image?.size = NSSize(width: DesignSystem.Size.menuArtwork, height: DesignSystem.Size.menuArtwork)
                header.image = image
            }
            menu.addItem(header)
            menu.addItem(.separator())
        }

        let hasTrack = model.hasTrack
        menu.addItem(item(model.playback.isPlaying ? "Pausa" : "Riproduci", symbol: model.playback.isPlaying ? "pause.fill" : "play.fill", enabled: hasTrack) {
            model.perform(.playPause)
        })
        menu.addItem(item("Successivo", symbol: "forward.fill", enabled: hasTrack) { model.perform(.next) })
        menu.addItem(item("Precedente", symbol: "backward.fill", enabled: hasTrack) { model.perform(.previous) })
        menu.addItem(.separator())
        menu.addItem(item(model.settings.floatingVisible ? "Nascondi finestra flottante" : "Mostra finestra flottante", symbol: "pip") {
            model.toggleFloatingWindow()
        })
        if let player = model.player {
            menu.addItem(item("Apri \(player.name)", symbol: "arrow.up.forward.app") { model.openSourcePlayer() })
        }
        menu.addItem(.separator())
        menu.addItem(item("Impostazioni…", symbol: "gearshape", action: onOpenSettings))
        menu.addItem(item("Diagnostica…", symbol: "stethoscope", action: onOpenDebug))
        menu.addItem(.separator())
        menu.addItem(item("Esci da OpenTunes", symbol: "power") { NSApp.terminate(nil) })
        return menu
    }

    private static func item(_ title: String, symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, handler: action)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.isEnabled = enabled
        return item
    }
}

/// `NSMenuItem` che esegue una closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) non supportato") }

    @objc private func fire() { handler() }
}

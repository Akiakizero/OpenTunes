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
        addTrackActions(to: menu, model: model)
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

    /// Love, stelle, dislike, libreria, cambio player e coda degli ascolti.
    private static func addTrackActions(to menu: NSMenu, model: AppModel) {
        var items: [NSMenuItem] = []
        if model.canLove {
            items.append(item(model.isLoved ? "Togli il love" : "Love", symbol: model.isLoved ? "heart.slash" : "heart") {
                model.toggleLove()
            })
        }
        if model.store.supportsTrackActions {
            let rating = NSMenuItem(title: "Valutazione", action: nil, keyEquivalent: "")
            rating.image = NSImage(systemSymbolName: "star", accessibilityDescription: nil)
            let stars = NSMenu()
            let current = model.musicState?.stars ?? 0
            for value in 0...5 {
                let title = value == 0 ? "Nessuna" : String(repeating: "★", count: value) + String(repeating: "☆", count: 5 - value)
                let entry = ClosureMenuItem(title: title) { model.performTrackAction(.setRating(value)) }
                entry.state = value == current ? .on : .off
                stars.addItem(entry)
            }
            rating.submenu = stars
            items.append(rating)
            let disliked = model.musicState?.disliked ?? false
            let dislike = item("Non mi piace", symbol: "hand.thumbsdown") { model.toggleDislike() }
            dislike.state = disliked ? .on : .off
            items.append(dislike)
            items.append(item("Aggiungi alla libreria", symbol: "plus.circle") { model.addToLibrary() })
        }
        if let other = model.store.switchablePlayers.first {
            items.append(item("Passa a \(other.displayName)", symbol: "arrow.left.arrow.right") { model.switchPlayer() })
        }
        let pending = model.scrobbler.pendingCount
        if pending > 0 {
            items.append(item(pending == 1 ? "1 ascolto in coda — invia ora" : "\(pending) ascolti in coda — invia ora",
                symbol: "arrow.trianglehead.2.clockwise") { model.scrobbler.retryNow() })
        }
        guard !items.isEmpty else { return }
        menu.addItem(.separator())
        items.forEach(menu.addItem)
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

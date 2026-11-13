// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Finestra «Scopri» (top album e simili da Last.fm), creata alla prima apertura.
@MainActor
final class DiscoverWindowController {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let window = window ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: DiscoverView(model: model)))
            window.title = String(localized: "Scopri")
            window.subtitle = "Last.fm"
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(DesignSystem.Size.discoverWindow)
            window.center()
            window.setFrameAutosaveName("Discover")
            self.window = window
            return window
        }()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

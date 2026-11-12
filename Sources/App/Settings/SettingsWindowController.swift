// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ServiceManagement
import SwiftUI

/// Finestra delle impostazioni: schede in stile toolbar, ognuna con una vista SwiftUI.
@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private var window: NSWindow?
    var onOpenDebug: () -> Void = {}

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let window = window ?? makeWindow()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true
        let openDebug: () -> Void = { [weak self] in self?.onOpenDebug() }
        add(GeneralSettingsView(model: model), title: "Generali", symbol: "gearshape", to: tabs)
        add(MenuBarSettingsView(model: model), title: "Menu bar", symbol: "menubar.rectangle", to: tabs)
        add(PositionSettingsView(model: model), title: "Posizione", symbol: "macwindow.on.rectangle", to: tabs)
        add(ShortcutsSettingsView(), title: "Scorciatoie", symbol: "keyboard", to: tabs)
        add(OtherSettingsView(model: model, onOpenDebug: openDebug), title: "Altro", symbol: "ellipsis.circle", to: tabs)

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Settings")
        self.window = window
        return window
    }

    private func add(_ view: some View, title: String, symbol: String, to tabs: NSTabViewController) {
        let controller = NSHostingController(rootView: view.frame(width: DesignSystem.Size.settingsWidth, height: DesignSystem.Size.settingsHeight))
        controller.sizingOptions = [.preferredContentSize]
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        tabs.addTabViewItem(item)
    }
}

/// Avvio al login con `SMAppService` (nessun helper separato).
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

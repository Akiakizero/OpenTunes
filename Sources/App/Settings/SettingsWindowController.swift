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
        // Se macOS rifiuta l'attivazione (apertura non partita da un clic) la finestra resterebbe dietro.
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true
        let openDebug: () -> Void = { [weak self] in self?.onOpenDebug() }
        add(GeneralSettingsView(model: model), title: String(localized: "Generali"), symbol: "gearshape", to: tabs)
        add(MenuBarSettingsView(model: model), title: String(localized: "Menu bar"), symbol: "menubar.rectangle", to: tabs)
        add(SurfacesSettingsView(model: model), title: String(localized: "Superfici"), symbol: "rectangle.3.group", to: tabs)
        add(FeaturesSettingsView(model: model), title: String(localized: "Funzioni"), symbol: "switch.2", to: tabs)
        add(ScrobblingSettingsView(model: model), title: String(localized: "Scrobbling"), symbol: "dot.radiowaves.up.forward", to: tabs)
        add(IntegrationsSettingsView(model: model), title: String(localized: "Integrazioni"), symbol: "puzzlepiece.extension", to: tabs)
        add(ShortcutsSettingsView(), title: String(localized: "Scorciatoie"), symbol: "keyboard", to: tabs)
        add(OtherSettingsView(model: model, onOpenDebug: openDebug), title: String(localized: "Altro"), symbol: "ellipsis.circle", to: tabs)

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        // Con le schede il titolo è quello della scheda: la versione va nel sottotitolo.
        window.subtitle = "OpenTunes \(AppInfo.version)"
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

/// Versione dell'app, letta dall'Info.plist (`MARKETING_VERSION` in project.yml).
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
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

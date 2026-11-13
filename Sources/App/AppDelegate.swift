// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Crea il modello e collega le superfici: menu bar, finestra flottante, HUD, notifiche, hotkey.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Creato solo quando serve: sotto i test e nelle anteprime non si apre il database né il Portachiavi.
    private lazy var model = AppModel.live()
    private lazy var statusBar = StatusBarController(model: model)
    private lazy var floatingPanel = FloatingPanelController(model: model)
    private lazy var hud = HUDController(model: model)
    private lazy var notifier = TrackNotifier(model: model)
    private lazy var settingsWindow = SettingsWindowController(model: model)
    private lazy var desktopWidget = DesktopWidgetController(model: model)
    private lazy var notch = NotchController(model: model)
    private lazy var dockIcon = DockIconController(model: model)
    private lazy var widgetBridge = WidgetBridge(model: model)
    private var debugWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Come host dei test o nelle anteprime di Xcode l'app non avvia superfici, adapter e hotkey
        // (altrimenti le anteprime toccherebbero le preferenze reali).
        let environment = ProcessInfo.processInfo.environment
        guard environment["XCTestConfigurationFilePath"] == nil, environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        model.onEvent = { [weak self] event in self?.handle(event) }
        model.start()

        statusBar.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        statusBar.onOpenDebug = { [weak self] in self?.showDebugWindow() }
        settingsWindow.onOpenDebug = { [weak self] in self?.showDebugWindow() }
        statusBar.start()
        floatingPanel.start()
        desktopWidget.start()
        notch.start()
        dockIcon.start()
        widgetBridge.start()
        _ = notifier
        Hotkeys.register(model: model)
        showDebugSurface(environment["OPENTUNES_DEBUG_SHOW"])
    }

    /// Solo per debug e screenshot: `OPENTUNES_DEBUG_SHOW=popover|hud|volume|settings|desktop|notch` apre una superficie all'avvio.
    private func showDebugSurface(_ name: String?) {
        guard let name else { return }
        Task {
            // Aspetta che menu bar e brano siano pronti.
            try? await Task.sleep(for: .seconds(3))
            switch name {
            case "popover": statusBar.togglePopover()
            case "hud": hud.show(.track(title: model.track?.title ?? "", symbol: "forward.fill"))
            case "volume": hud.show(.volume(model.volume ?? 0.5))
            case "settings": settingsWindow.show()
            case "desktop": model.settings.desktopWidgetVisible = true
            case "notch": notch.showOpenForDebug()
            default: break
            }
        }
    }

    /// Riaprire l'app (es. dal Finder) mostra le impostazioni: utile se l'elemento in menu bar è nascosto.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }

    /// `opentunes://player` (clic sul widget WidgetKit) apre il player della menu bar.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "opentunes" }), model.hasTrack else {
            settingsWindow.show()
            return
        }
        statusBar.togglePopover()
    }

    private func handle(_ event: AppModel.Event) {
        let settings = model.settings
        switch event {
        case .trackChanged:
            notifier.trackChanged()
            if settings.hudOnTrackChange, let title = model.track?.title {
                hud.show(.track(title: title, symbol: nil))
            }
        case .skipped(let forward):
            if settings.hudOnTrackChange {
                hud.show(.track(title: model.track?.title ?? "", symbol: forward ? "forward.fill" : "backward.fill"))
            }
        case .playPauseToggled(let isPlaying):
            if settings.hudOnTrackChange {
                hud.show(.track(title: model.track?.title ?? "", symbol: isPlaying ? "play.fill" : "pause.fill"))
            }
        case .volumeChanged(let level):
            if settings.hudOnVolumeChange { hud.show(.volume(level)) }
        case .trackAction(let title, let symbol):
            hud.show(.track(title: title, symbol: symbol))
        }
    }

    private func showDebugWindow() {
        let window = debugWindow ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: DebugView(store: model.store)))
            window.title = "OpenTunes — Diagnostica"
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 560, height: 680))
            window.center()
            debugWindow = window
            return window
        }()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

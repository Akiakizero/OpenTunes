// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Pannello trasparente sopra la menu bar, centrato sul notch.
final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        // Sopra la menu bar (e i suoi menu), come le altre app del notch.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        // Il pannello è molto più grande della forma visibile: lascia passare i clic finché il mouse non è sopra.
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Player nel notch: stato chiuso con copertina e indicatore, aperto al passaggio del mouse o al clic,
/// titolo per qualche secondo al cambio brano. Sui Mac senza notch è una capsula di vetro nella menu bar.
@MainActor
final class NotchController {
    private let model: AppModel
    private var panel: NotchPanel?
    private var presentation: NotchPresentation?
    private var tasks: [Task<Void, Never>] = []
    /// Osservatori attivi solo mentre il notch è acceso.
    private var notchTasks: [Task<Void, Never>] = []
    private var monitors: [Any] = []
    private var hoverTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var isMouseInside = false

    /// Bundle ID di app che disegnano già nel notch: se ne è aperta una, le impostazioni lo segnalano.
    static let otherNotchApps = ["theboringteam.boringnotch", "com.Jackson.DynamicNotch", "wiki.qaq.NotchDrop"]

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        let settings = model.settings
        tasks.append(observeChanges({ settings.notchEnabled }) { [weak self] enabled in
            enabled ? self?.activate() : self?.deactivate()
        })
    }

    // MARK: Attivazione

    private func activate() {
        guard panel == nil, let screen = NotchGeometry.preferredScreen() else { return }
        let presentation = NotchPresentation(geometry: NotchGeometry(screen: screen))
        presentation.onOpenRequest = { [weak self] in self?.open() }
        let panel = NotchPanel()
        let hosting = NSHostingView(rootView: NotchPlayerView(model: model, presentation: presentation))
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.setFrame(presentation.geometry.panelFrame, display: false)
        panel.orderFrontRegardless()
        self.panel = panel
        self.presentation = presentation

        let store = model.store
        var observers: [Task<Void, Never>] = []
        observers.append(observeChanges({ "\(store.track != nil)\(store.playback.isPlaying)" }) { [weak self] _ in
            self?.settle()
        })
        observers.append(observeChanges({ store.trackChangeCount }) { [weak self] count in
            if count > 1 { self?.peek() }
        })
        observers.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                self?.updateScreen()
            }
        })
        notchTasks = observers

        // Il mouse si segue con i monitor: il pannello ignora i clic finché non è sopra la forma.
        // I monitor globali degli eventi del mouse non richiedono il permesso Accessibilità.
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func deactivate() {
        notchTasks.forEach { $0.cancel() }
        notchTasks = []
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        hoverTask?.cancel()
        peekTask?.cancel()
        panel?.orderOut(nil)
        panel = nil
        presentation = nil
    }

    private func updateScreen() {
        guard let panel, let presentation, let screen = NotchGeometry.preferredScreen() else { return }
        presentation.geometry = NotchGeometry(screen: screen)
        panel.setFrame(presentation.geometry.panelFrame, display: true)
    }

    // MARK: Stati

    private func set(_ state: NotchState) {
        guard let presentation, presentation.state != state else { return }
        presentation.state = state
        // Aperto: il pannello riceve i clic sui controlli anche prima che il mouse si muova.
        if state == .open { panel?.ignoresMouseEvents = false }
    }

    /// Torna allo stato a riposo, se il notch non è aperto o in "peek".
    private func settle() {
        guard let presentation else { return }
        if !model.hasTrack {
            set(.hidden)
            return
        }
        if presentation.state == .open || presentation.state == .peek { return }
        set(NotchState.resting(hasTrack: model.hasTrack, isPlaying: model.playback.isPlaying))
    }

    /// Solo per debug e screenshot (`OPENTUNES_DEBUG_SHOW=notch`).
    func showOpenForDebug() {
        open()
    }

    private func open() {
        guard model.hasTrack else { return }
        peekTask?.cancel()
        set(.open)
    }

    private func close() {
        set(NotchState.resting(hasTrack: model.hasTrack, isPlaying: model.playback.isPlaying))
        if !isMouseInside { panel?.ignoresMouseEvents = true }
    }

    private func peek() {
        guard model.settings.notchPeeksOnTrackChange, presentation?.state != .open, model.hasTrack else { return }
        set(.peek)
        peekTask?.cancel()
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(DesignSystem.Motion.notchPeek))
            guard !Task.isCancelled, let self, self.presentation?.state == .peek else { return }
            self.set(NotchState.resting(hasTrack: self.model.hasTrack, isPlaying: self.model.playback.isPlaying))
        }
    }

    // MARK: Mouse

    /// Area sensibile: la forma visibile, o il notch fisico se la forma è nascosta.
    private var hitRect: CGRect? {
        guard let panel, let presentation else { return nil }
        var local = presentation.shapeFrame
        if presentation.geometry.hasNotch {
            local.origin.x += NotchPlayerView.horizontalOffset(for: presentation.state)
        }
        return NotchGeometry.hitRect(local: local, panelFrame: panel.frame)
    }

    private func mouseMoved() {
        guard let panel, let hitRect else { return }
        let inside = hitRect.contains(NSEvent.mouseLocation)
        guard inside != isMouseInside else { return }
        isMouseInside = inside
        panel.ignoresMouseEvents = !inside
        hoverTask?.cancel()
        let state = presentation?.state
        if inside, state != .open, model.settings.notchOpensOnHover, model.hasTrack {
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(DesignSystem.Motion.notchHoverDelay))
                guard !Task.isCancelled else { return }
                self?.open()
            }
        } else if !inside, state == .open {
            // Breve attesa: uscire di un pixel mentre si punta un pulsante non deve chiudere il player.
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                self?.close()
            }
        }
    }
}

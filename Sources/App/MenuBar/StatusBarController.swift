// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MediaCore
import SwiftUI

/// Un `NSStatusItem` con contenuto SwiftUI.
@MainActor
final class StatusItemHost {
    let role: StatusItemRole
    let item: NSStatusItem
    let layout: StatusItemLayout
    private let hosting: NSView

    init(role: StatusItemRole, model: AppModel, state: StatusItemState) {
        self.role = role
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.item = item
        let layout = StatusItemLayout()
        self.layout = layout
        // Il sistema ricorda la posizione scelta dall'utente (⌘-trascina) per ogni nome.
        item.autosaveName = role == .controls ? "OpenTunesControls" : "OpenTunesMain"
        // La larghezza dell'elemento segue quella del contenuto SwiftUI.
        let content = StatusItemContent(role: role, model: model, state: state, layout: layout) { width in
            if abs(item.length - width) > 0.5 { item.length = width }
        }
        hosting = FirstMouseHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        if let button = item.button {
            button.title = ""
            button.setAccessibilityLabel("OpenTunes")
            button.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: button.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
        }
    }

    var window: NSWindow? { item.button?.window }

    /// Punto dell'evento in coordinate della vista SwiftUI (origine in alto a sinistra).
    func location(of event: NSEvent) -> CGPoint {
        hosting.convert(event.locationInWindow, from: nil)
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }
}

/// `NSHostingView` che accetta il primo clic: i pulsanti in menu bar rispondono subito.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Gestisce gli elementi in menu bar: contenuto, azioni del mouse, popover, menu rapido
/// e modalità compatta accanto al notch.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let state = StatusItemState()
    private var hosts: [StatusItemHost] = []
    private let popover = NSPopover()
    private var monitor: Any?
    private var tasks: [Task<Void, Never>] = []
    /// Delta della rotella accumulato (trackpad: molti eventi piccoli).
    private var scrollAccumulator: CGFloat = 0
    /// Ultima geometria scritta nel log diagnostico (per non ripeterla ogni 2 secondi).
    private var lastLayoutSummary = ""
    /// Quando il popover si è chiuso: un clic sull'elemento lo chiude (transient) e non deve riaprirlo.
    private var popoverClosedAt = Date.distantPast

    var onOpenSettings: () -> Void = {}
    var onOpenDebug: () -> Void = {}

    init(model: AppModel) {
        self.model = model
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let controller = NSHostingController(
            rootView: PopoverView(model: model, onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.onOpenSettings()
            }))
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
    }

    func start() {
        rebuildItems()
        installEventMonitor()

        let settings = model.settings
        tasks.append(observeChanges({ settings.separateControlsItem }) { [weak self] _ in self?.rebuildItems() })
        tasks.append(observeChanges({ [model] in model.hasTrack || !settings.hidesWhenIdle }) { [weak self] visible in
            self?.hosts.forEach { $0.item.isVisible = visible }
        })
        tasks.append(observeChanges({ settings.autoCompact }) { [weak self] _ in self?.updateCompactMode() })

        // Lo spazio libero cambia senza notifiche (altre app aggiungono elementi): controllo periodico leggero.
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                self?.updateCompactMode()
            }
        })
        tasks.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                self?.updateCompactMode()
            }
        })
    }

    private func rebuildItems() {
        hosts.forEach { $0.remove() }
        let roles: [StatusItemRole] = model.settings.separateControlsItem ? [.controls, .info] : [.combined]
        hosts = roles.map { StatusItemHost(role: $0, model: model, state: state) }
        let visible = model.hasTrack || !model.settings.hidesWhenIdle
        hosts.forEach { $0.item.isVisible = visible }
    }

    // MARK: Modalità compatta

    private func updateCompactMode() {
        guard model.settings.autoCompact, model.hasTrack else {
            if state.isCompact { state.isCompact = false }
            return
        }
        let windows = hosts.compactMap(\.window).filter(\.isVisible)
        guard let screen = windows.first?.screen, !windows.isEmpty else { return }
        let frame = windows.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        let fullWidth = hosts.reduce(0) { $0 + $1.layout.fullWidth }
        let compact = NotchLayout.shouldBeCompact(
            itemFrame: frame, fullWidth: fullWidth, notch: screen.notchRange, isCompact: state.isCompact)
        let summary = "frame \(Int(frame.minX))…\(Int(frame.maxX)), piena \(Int(fullWidth)) pt, notch \(screen.notchRange.map { "\(Int($0.lowerBound))…\(Int($0.upperBound))" } ?? "assente")"
        if summary != lastLayoutSummary {
            lastLayoutSummary = summary
            model.store.log("menubar", summary)
        }
        if compact != state.isCompact {
            state.isCompact = compact
            model.store.log("menubar", compact ? "modalità compatta (spazio insufficiente accanto al notch)" : "modalità piena")
        }
    }

    // MARK: Mouse

    private func installEventMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]) {
            [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return consumed ? nil : event
        }
    }

    /// Restituisce `true` se l'evento è stato gestito (e non va inoltrato).
    private func handle(_ event: NSEvent) -> Bool {
        guard let host = hosts.first(where: { $0.window != nil && $0.window === event.window }) else { return false }
        switch event.type {
        case .leftMouseDown:
            // I clic sui pulsanti vanno ai pulsanti SwiftUI.
            if host.layout.isButton(at: host.location(of: event)) { return false }
            run(model.settings.leftClick, from: host)
        case .rightMouseDown:
            run(model.settings.rightClick, from: host)
        case .otherMouseDown:
            run(model.settings.middleClick, from: host)
        case .scrollWheel:
            handleScroll(event)
        default:
            return false
        }
        return true
    }

    private func run(_ action: MouseAction, from host: StatusItemHost) {
        switch action {
        case .openPopover: togglePopover(from: host)
        case .playPause: model.perform(.playPause)
        case .nextTrack: model.perform(.next)
        case .previousTrack: model.perform(.previous)
        case .quickMenu: showQuickMenu(from: host)
        case .toggleFloatingWindow: model.toggleFloatingWindow()
        case .love: model.toggleLove()
        case .none: break
        }
    }

    private func handleScroll(_ event: NSEvent) {
        var delta = event.scrollingDeltaY
        if event.isDirectionInvertedFromDevice { delta = -delta }
        if event.phase == .began || event.momentumPhase == .began { scrollAccumulator = 0 }
        // Rotella classica: uno scatto = un passo. Trackpad: un passo ogni ~12 punti.
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 12 : 0.5
        scrollAccumulator += delta
        guard abs(scrollAccumulator) >= threshold else { return }
        let up = scrollAccumulator < 0
        scrollAccumulator = 0
        switch model.settings.scrollAction {
        case .volume: model.changeVolume(by: up ? SystemVolume.step : -SystemVolume.step)
        case .seek: model.seek(by: up ? 5 : -5)
        case .none: break
        }
    }

    // MARK: Popover e menu

    func togglePopover(from host: StatusItemHost? = nil) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard Date.now.timeIntervalSince(popoverClosedAt) > 0.3 else { return }
        guard let button = (host ?? hosts.last)?.item.button else { return }
        model.refreshVolume()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.highlight(true)
    }

    func popoverDidClose(_ notification: Notification) {
        popoverClosedAt = .now
        hosts.forEach { $0.item.button?.highlight(false) }
    }

    private func showQuickMenu(from host: StatusItemHost) {
        guard let button = host.item.button else { return }
        let menu = QuickMenu.make(model: model, onOpenSettings: onOpenSettings, onOpenDebug: onOpenDebug)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + DesignSystem.Spacing.xs), in: button)
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Pannello che non attiva l'app, sempre in primo piano, trascinabile dallo sfondo.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    // Può diventare key (per slider e menu contestuale) senza attivare l'app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Mostra e nasconde la finestra flottante, ne ricorda la posizione e applica la tinta.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var panel: FloatingPanel?
    private var glass: NSGlassEffectView?
    private var tasks: [Task<Void, Never>] = []

    private static let originKey = "floatingPanelTopLeft"

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        let settings = model.settings
        tasks.append(observeChanges({ settings.showsFloatingWindow }) { [weak self] visible in
            visible ? self?.show() : self?.hide()
        })
        tasks.append(observeChanges({ settings.floatingSize }) { [weak self] _ in self?.applySize() })
        // Monitor scollegato o risoluzione cambiata: la finestra torna su uno schermo visibile.
        tasks.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                self?.keepOnScreen()
            }
        })
        tasks.append(observeChanges({ settings.floatingHidesInFullScreen }) { [weak self] _ in self?.applyCollectionBehavior() })
        tasks.append(observeChanges({ [model] in "\(model.tint?.dominant.r ?? -1)\(model.tint?.dominant.g ?? -1)\(model.tint?.dominant.b ?? -1)\(model.settings.theme.rawValue)" }) {
            [weak self] _ in self?.applyTint()
        })
    }

    private func makePanel() -> FloatingPanel {
        let size = Self.size(for: model.settings.floatingSize)
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size))
        panel.delegate = self

        let glass = NSGlassEffectView()
        glass.cornerRadius = DesignSystem.Radius.panel
        let hosting = NSHostingView(rootView: FloatingPlayerView(model: model))
        hosting.sizingOptions = []
        glass.contentView = hosting
        panel.contentView = glass

        self.panel = panel
        self.glass = glass
        applyCollectionBehavior()
        applyTint()
        restoreOrigin(panel)
        return panel
    }

    private func show() {
        let panel = panel ?? makePanel()
        panel.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func applySize() {
        guard let panel else { return }
        let size = Self.size(for: model.settings.floatingSize)
        // Il bordo superiore sinistro resta fermo quando cambia la taglia.
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        panel.setFrame(NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height), display: true, animate: true)
    }

    /// Senza `.fullScreenAuxiliary` il pannello non compare sopra le app a schermo intero.
    private func applyCollectionBehavior() {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        if !model.settings.floatingHidesInFullScreen { behavior.insert(.fullScreenAuxiliary) }
        panel?.collectionBehavior = behavior
    }

    private func applyTint() {
        glass?.apply(theme: model.settings.theme, tint: model.tint)
    }

    // MARK: Posizione

    private func restoreOrigin(_ panel: NSPanel) {
        let size = panel.frame.size
        if let saved = UserDefaults.standard.string(forKey: Self.originKey).map(NSPointFromString),
            NSScreen.screens.contains(where: { $0.visibleFrame.contains(saved) })
        {
            panel.setFrameOrigin(NSPoint(x: saved.x, y: saved.y - size.height))
        } else if let screen = NSScreen.main {
            // Prima apertura: in alto a destra, sotto la menu bar.
            let visible = screen.visibleFrame
            let margin = DesignSystem.Spacing.xl
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - margin, y: visible.maxY - size.height - margin))
        }
    }

    private func keepOnScreen() {
        guard let panel, panel.isVisible else { return }
        let frame = panel.frame
        guard !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) else { return }
        UserDefaults.standard.removeObject(forKey: Self.originKey)
        restoreOrigin(panel)
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        UserDefaults.standard.set(NSStringFromPoint(NSPoint(x: panel.frame.minX, y: panel.frame.maxY)), forKey: Self.originKey)
    }

    static func size(for size: FloatingSize) -> CGSize {
        switch size {
        case .compact: DesignSystem.Size.floatingCompact
        case .large: DesignSystem.Size.floatingLarge
        case .focus: DesignSystem.Size.floatingFocus
        }
    }
}

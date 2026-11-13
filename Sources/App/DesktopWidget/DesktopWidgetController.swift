// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Finestra senza bordi a livello della scrivania: sopra lo sfondo e le icone, sotto tutte le altre finestre.
///
/// Sotto le icone del Finder i clic finirebbero alla scrivania: per avere controlli usabili il widget sta sopra le icone,
/// allo stesso livello dei widget di macOS (icone + 2). A icone + 1 su macOS 27 il Window Server tiene una finestra
/// a tutto schermo («underbelly») davanti al widget, che così non si vede. Con `.stationary` resta fermo con
/// Mission Control e «Mostra scrivania».
final class DesktopWidgetWindow: NSWindow {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .resizable], backing: .buffered, defer: true)
        level = DesktopWidgetWindow.level
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        animationBehavior = .none
    }

    /// Livello dei widget di macOS sulla scrivania.
    static let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)

    // Key per slider e menu contestuale; non diventa mai main (non ruba il focus alle app).
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Posizione salvata del widget per ogni monitor (identificato dall'UUID del display).
struct DesktopWidgetPlacement: Codable, Equatable {
    /// Frame per UUID del display, in coordinate schermo.
    var frames: [String: CGRect] = [:]
    /// Ultimo display usato.
    var lastDisplay: String?

    struct Screen {
        var id: String
        var visibleFrame: CGRect
    }

    /// Frame da usare: quello salvato per l'ultimo display se è ancora collegato, altrimenti quello di un altro
    /// display collegato, altrimenti in alto a sinistra del primo schermo. Sempre riportato dentro lo schermo.
    func frame(size: CGSize, screens: [Screen]) -> CGRect? {
        guard let fallback = screens.first else { return nil }
        let ordered = screens.filter { $0.id == lastDisplay } + screens.filter { $0.id != lastDisplay }
        for screen in ordered {
            if let saved = frames[screen.id] {
                // La larghezza decide la scala; l'altezza segue il layout corrente.
                let width = saved.width
                let height = width * size.height / max(1, size.width)
                let rect = CGRect(x: saved.minX, y: saved.maxY - height, width: width, height: height)
                return Self.clamp(rect, to: screen.visibleFrame)
            }
        }
        let margin = DesignSystem.Spacing.xxl
        let visible = fallback.visibleFrame
        return CGRect(x: visible.minX + margin, y: visible.maxY - size.height - margin, width: size.width, height: size.height)
    }

    mutating func save(_ frame: CGRect, display: String) {
        frames[display] = frame
        lastDisplay = display
    }

    static func clamp(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        var r = rect
        r.size.width = min(r.width, bounds.width)
        r.size.height = min(r.height, bounds.height)
        r.origin.x = min(max(r.minX, bounds.minX), bounds.maxX - r.width)
        r.origin.y = min(max(r.minY, bounds.minY), bounds.maxY - r.height)
        return r
    }
}

/// Mostra il widget sulla scrivania, applica layout, blocco e tinta, ricorda posizione e misura per monitor.
@MainActor
final class DesktopWidgetController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var window: DesktopWidgetWindow?
    private var glass: NSGlassEffectView?
    private var tasks: [Task<Void, Never>] = []
    private var placement: DesktopWidgetPlacement
    /// Durante i cambi di frame fatti dal codice non si salva la posizione.
    private var isApplyingFrame = false

    private static let placementKey = "desktopWidgetPlacement"

    init(model: AppModel) {
        self.model = model
        placement = UserDefaults.standard.data(forKey: Self.placementKey)
            .flatMap { try? JSONDecoder().decode(DesktopWidgetPlacement.self, from: $0) } ?? DesktopWidgetPlacement()
    }

    func start() {
        let settings = model.settings
        tasks.append(observeChanges({ settings.desktopWidgetVisible }) { [weak self] visible in
            visible ? self?.show() : self?.window?.orderOut(nil)
        })
        tasks.append(observeChanges({ "\(settings.desktopWidgetLayout.rawValue)\(settings.desktopWidgetShowsChart)" }) { [weak self] _ in
            self?.applyLayout()
        })
        tasks.append(observeChanges({ settings.desktopWidgetLocked }) { [weak self] _ in self?.applyLock() })
        tasks.append(observeChanges({ [model] in "\(model.tint?.dominant.r ?? -1)\(model.tint?.dominant.g ?? -1)\(model.tint?.dominant.b ?? -1)\(model.settings.theme.rawValue)" }) {
            [weak self] _ in self?.applyTint()
        })
        tasks.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                self?.restoreFrame()
            }
        })
    }

    private var baseSize: CGSize {
        DesktopWidgetView.baseSize(layout: model.settings.desktopWidgetLayout, chart: model.settings.desktopWidgetShowsChart)
    }

    private func makeWindow() -> DesktopWidgetWindow {
        let window = DesktopWidgetWindow()
        window.delegate = self
        let glass = NSGlassEffectView()
        glass.cornerRadius = DesignSystem.Radius.panel
        let hosting = NSHostingView(rootView: DesktopWidgetView(model: model))
        hosting.sizingOptions = []
        glass.contentView = hosting
        window.contentView = glass
        self.window = window
        self.glass = glass
        applyLock()
        applyTint()
        applyLayout()
        return window
    }

    private func show() {
        let window = window ?? makeWindow()
        // In primo piano solo dentro il suo livello: resta comunque sotto le finestre normali.
        window.orderFrontRegardless()
    }

    private func applyLayout() {
        guard let window else { return }
        let size = baseSize
        window.contentAspectRatio = size
        let scale = DesignSystem.Size.desktopScale
        window.contentMinSize = CGSize(width: size.width * scale.lowerBound, height: size.height * scale.lowerBound)
        window.contentMaxSize = CGSize(width: size.width * scale.upperBound, height: size.height * scale.upperBound)
        restoreFrame()
    }

    private func applyLock() {
        guard let window else { return }
        let locked = model.settings.desktopWidgetLocked
        window.isMovable = !locked
        window.isMovableByWindowBackground = !locked
        if locked { window.styleMask.remove(.resizable) } else { window.styleMask.insert(.resizable) }
    }

    private func applyTint() {
        glass?.apply(theme: model.settings.theme, tint: model.tint)
    }

    // MARK: Posizione per monitor

    private func restoreFrame() {
        guard let window else { return }
        let screens = NSScreen.screens.compactMap { screen in
            screen.displayUUID.map { DesktopWidgetPlacement.Screen(id: $0, visibleFrame: screen.visibleFrame) }
        }
        guard let frame = placement.frame(size: baseSize, screens: screens) else { return }
        isApplyingFrame = true
        window.setFrame(frame, display: true)
        isApplyingFrame = false
    }

    private func saveFrame() {
        guard !isApplyingFrame, let window, let display = window.screen?.displayUUID else { return }
        placement.save(window.frame, display: display)
        if let data = try? JSONEncoder().encode(placement) {
            UserDefaults.standard.set(data, forKey: Self.placementKey)
        }
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidEndLiveResize(_ notification: Notification) { saveFrame() }
}

extension NSScreen {
    /// UUID stabile del display (non cambia tra un avvio e l'altro, a differenza del `CGDirectDisplayID`).
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
            let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

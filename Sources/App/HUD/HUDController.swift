// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Cosa mostra l'HUD.
enum HUDContent: Equatable {
    /// Cambio brano o play/pausa: copertina con simbolo sovrapposto e titolo.
    case track(title: String, symbol: String?)
    /// Volume 0…1.
    case volume(Float)
}

/// HUD a schermo che compare per un attimo e poi svanisce; non riceve clic.
@MainActor
final class HUDController {
    private let model: AppModel
    private var panel: NSPanel?
    private var glass: NSGlassEffectView?
    private var hosting: NSHostingView<HUDView>?
    private var hideTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
    }

    func show(_ content: HUDContent) {
        let panel = panel ?? makePanel()
        hosting?.rootView = HUDView(model: model, content: content)
        glass?.tintColor = model.tint?.dynamicColor(opacity: DesignSystem.glassTintOpacity)
        position(panel)
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignSystem.Motion.quick
            panel.animator().alphaValue = 1
        }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(DesignSystem.Motion.hudVisible))
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignSystem.Motion.slow
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                if panel.alphaValue == 0 { panel.orderOut(nil) }
            }
        }
    }

    private func makePanel() -> NSPanel {
        let side = DesignSystem.Size.hud
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: side, height: side),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let glass = NSGlassEffectView()
        glass.cornerRadius = DesignSystem.Radius.panel
        let hosting = NSHostingView(rootView: HUDView(model: model, content: .volume(0)))
        hosting.sizingOptions = []
        glass.contentView = hosting
        panel.contentView = glass

        self.panel = panel
        self.glass = glass
        self.hosting = hosting
        return panel
    }

    private func position(_ panel: NSPanel) {
        // Lo schermo con il puntatore: è quello che l'utente sta guardando.
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let margin = DesignSystem.Spacing.xxl
        let origin: NSPoint = switch model.settings.hudPosition {
        case .bottom: NSPoint(x: visible.midX - size.width / 2, y: visible.minY + margin * 3)
        case .center: NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        case .topRight: NSPoint(x: visible.maxX - size.width - margin, y: visible.maxY - size.height - margin)
        }
        panel.setFrameOrigin(origin)
    }
}

/// Contenuto dell'HUD.
struct HUDView: View {
    let model: AppModel
    let content: HUDContent

    /// Segmenti dell'indicatore del volume (come i passi dei tasti di sistema).
    private let segments = 16

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.m) {
            ZStack {
                ArtworkView(
                    image: model.artwork, identity: model.track?.artworkHash,
                    size: DesignSystem.Size.hudArtwork, cornerRadius: DesignSystem.Radius.large,
                    showsPlaceholderIcon: symbol == nil)
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: DesignSystem.Size.hudArtwork * 0.4, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: DesignSystem.Spacing.s)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            switch content {
            case .track(let title, _):
                Text(title)
                    .font(DesignSystem.Typography.title)
                    .lineLimit(1)
                    .padding(.horizontal, DesignSystem.Spacing.m)
            case .volume(let level):
                volumeBar(level)
            }
        }
        .frame(width: DesignSystem.Size.hud, height: DesignSystem.Size.hud)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String? {
        switch content {
        case .track(_, let symbol): symbol
        case .volume(let level):
            level == 0 ? "speaker.slash.fill" : level < 0.34 ? "speaker.wave.1.fill" : level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        }
    }

    private func volumeBar(_ level: Float) -> some View {
        let filled = Int((level * Float(segments)).rounded())
        return HStack(spacing: DesignSystem.Spacing.xxs) {
            ForEach(0..<segments, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                    .frame(width: DesignSystem.Spacing.s, height: DesignSystem.Spacing.xs)
            }
        }
        .accessibilityLabel("Volume \(Int(level * 100))%")
    }
}

#Preview("HUD brano") {
    HUDView(model: .preview(), content: .track(title: "Un brano di prova", symbol: "forward.fill"))
        .glassEffect(in: .rect(cornerRadius: DesignSystem.Radius.panel))
        .padding()
}

#Preview("HUD volume — scuro") {
    HUDView(model: .preview(), content: .volume(0.6))
        .glassEffect(in: .rect(cornerRadius: DesignSystem.Radius.panel))
        .padding()
        .preferredColorScheme(.dark)
}

// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import Observation
import SwiftUI

/// Stato condiviso tra il controller della menu bar e le viste degli elementi.
@Observable
@MainActor
final class StatusItemState {
    var isCompact = false
}

/// Geometria riportata dalla vista al controller, per instradare i clic (non osservata).
@MainActor
final class StatusItemLayout {
    /// Aree dei pulsanti in coordinate della vista: i clic qui vanno ai pulsanti SwiftUI.
    var buttonFrames: [MenuBarElement: CGRect] = [:]

    func isButton(at point: CGPoint) -> Bool {
        buttonFrames.values.contains { $0.contains(point) }
    }
    /// Larghezza in modalità piena, misurata anche quando l'elemento è compatto.
    var fullWidth: CGFloat = 0
}

/// Ruolo di un elemento in menu bar: unico, oppure "info" + "controlli" separati.
enum StatusItemRole {
    case combined, info, controls

    var elements: Set<MenuBarElement> {
        switch self {
        case .combined: Set(MenuBarElement.allCases)
        case .info: [.artwork, .title]
        case .controls: [.controls, .love]
        }
    }
}

/// Contenuto SwiftUI di un `NSStatusItem`.
struct StatusItemContent: View {
    let role: StatusItemRole
    let model: AppModel
    let state: StatusItemState
    let layout: StatusItemLayout
    /// Chiamata quando cambia la larghezza visibile: il controller aggiorna `NSStatusItem.length`.
    let onWidthChange: @MainActor (CGFloat) -> Void

    nonisolated static let coordinateSpace = "statusItem"

    var body: some View {
        content(compact: state.isCompact, measuring: false)
            .fixedSize()
            .background(alignment: .leading) {
                // Misura della versione piena, invisibile e senza effetti sul layout.
                content(compact: false, measuring: true)
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { layout.fullWidth = $0 }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onWidthChange($0) }
            .frame(maxHeight: .infinity)
            .coordinateSpace(.named(Self.coordinateSpace))
    }

    @ViewBuilder
    private func content(compact: Bool, measuring: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.s) {
            if model.hasTrack {
                ForEach(elements(compact: compact)) { element in
                    view(for: element, compact: compact, measuring: measuring)
                }
                if !compact, role != .controls, model.settings.showsQueueIndicator, model.scrobbler.pendingCount > 0 {
                    queueIndicator
                }
            } else {
                Image(systemName: "music.note")
                    .font(DesignSystem.Typography.menuBar)
                    .accessibilityLabel("OpenTunes")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
    }

    /// In modalità compatta restano solo copertina (o icona) e play/pausa.
    private func elements(compact: Bool) -> [MenuBarElement] {
        let visible = model.settings.visibleMenuBarElements.filter { role.elements.contains($0) }
        guard compact else {
            // Se l'utente nasconde tutto, resta l'icona/copertina per non far sparire l'elemento.
            return visible.isEmpty && role != .controls ? [.artwork] : visible
        }
        return role == .controls ? [.controls] : [.artwork] + (role == .combined ? [.controls] : [])
    }

    @ViewBuilder
    private func view(for element: MenuBarElement, compact: Bool, measuring: Bool) -> some View {
        switch element {
        case .artwork:
            if let image = model.artwork {
                ArtworkView(
                    image: image, identity: model.track?.artworkHash,
                    size: DesignSystem.Size.menuBarArtwork, cornerRadius: DesignSystem.Radius.tiny)
            } else {
                Image(systemName: "music.note").font(DesignSystem.Typography.menuBar)
            }
        case .title:
            MarqueeText(
                text: model.menuBarTitle ?? "",
                font: DesignSystem.Typography.menuBar,
                maxWidth: model.settings.maxTitleWidth,
                scrolls: model.settings.scrollsTitle)
        case .controls:
            PlaybackControls(variant: compact ? .minimal : .compact, isPlaying: model.playback.isPlaying) {
                model.perform($0)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.coordinateSpace)) } action: {
                if !measuring { layout.buttonFrames[.controls] = $0 }
            }
        case .love:
            if model.canLove {
                Button { model.toggleLove() } label: {
                    Image(systemName: model.isLoved ? "heart.fill" : "heart")
                        .font(DesignSystem.Typography.menuBar)
                        .frame(minWidth: DesignSystem.Size.menuBarControl, minHeight: DesignSystem.Size.menuBarControl)
                        .contentShape(.rect)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(ControlButtonStyle())
                .help(model.isLoved ? "Togli il love" : "Love")
                .accessibilityLabel(model.isLoved ? "Togli il love" : "Love")
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.coordinateSpace)) } action: {
                    if !measuring { layout.buttonFrames[.love] = $0 }
                }
                .onDisappear { if !measuring { layout.buttonFrames[.love] = nil } }
            }
        }
    }

    /// Piccola icona quando ci sono ascolti non ancora inviati (es. senza rete).
    private var queueIndicator: some View {
        let count = model.scrobbler.pendingCount
        return Image(systemName: "arrow.trianglehead.2.clockwise")
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(.secondary)
            .help(count == 1 ? "1 ascolto in attesa di invio" : "\(count) ascolti in attesa di invio")
            .accessibilityLabel(count == 1 ? "1 ascolto in attesa di invio" : "\(count) ascolti in attesa di invio")
    }
}

#Preview("Elemento in menu bar") {
    VStack(spacing: DesignSystem.Spacing.m) {
        StatusItemContent(role: .combined, model: .preview(), state: StatusItemState(), layout: StatusItemLayout()) { _ in }
            .frame(height: DesignSystem.Size.menuBarControl + DesignSystem.Spacing.xs)
        StatusItemContent(role: .combined, model: .preview(track: PreviewData.longTrack), state: StatusItemState(), layout: StatusItemLayout()) { _ in }
            .frame(height: DesignSystem.Size.menuBarControl + DesignSystem.Spacing.xs)
    }
    .padding(DesignSystem.Spacing.l)
}

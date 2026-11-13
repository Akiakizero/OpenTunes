// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import Observation
import SwiftUI

/// Stato condiviso tra il controller della menu bar e le viste degli elementi.
@Observable
@MainActor
final class StatusItemState {
    /// Livello scelto da `MenuBarFit` (piena, compatta, solo icona).
    var level: MenuBarLevel = .full
}

/// Geometria riportata dalla vista al controller, per instradare i clic (non osservata).
@MainActor
final class StatusItemLayout {
    /// Aree dei pulsanti in coordinate della vista: i clic qui vanno ai pulsanti SwiftUI.
    var buttonFrames: [MenuBarElement: CGRect] = [:]

    func isButton(at point: CGPoint) -> Bool {
        buttonFrames.values.contains { $0.contains(point) }
    }
    /// Larghezza di ogni livello, misurata anche quando l'elemento ne mostra un altro.
    var widths: [MenuBarLevel: CGFloat] = [:]
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
        content(level: state.level, measuring: false)
            .fixedSize()
            .background(alignment: .leading) {
                // Misura di tutti i livelli, invisibile e senza effetti sul layout.
                ZStack(alignment: .leading) {
                    ForEach(MenuBarLevel.allCases, id: \.self) { level in
                        content(level: level, measuring: true)
                            .fixedSize()
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { layout.widths[level] = $0 }
                    }
                }
                .hidden()
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onWidthChange($0) }
            .frame(maxHeight: .infinity)
            .coordinateSpace(.named(Self.coordinateSpace))
    }

    @ViewBuilder
    private func content(level: MenuBarLevel, measuring: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.s) {
            if model.hasTrack {
                ForEach(elements(level: level)) { element in
                    view(for: element, compact: level < .full, measuring: measuring)
                }
                if level == .full, role != .controls, model.settings.showsQueueIndicator, model.scrobbler.pendingCount > 0 {
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

    /// Compatta: copertina (o icona) e play/pausa. Icona: solo la copertina (l'elemento dei controlli separato
    /// tiene play/pausa, perché un elemento della status bar non può essere vuoto).
    private func elements(level: MenuBarLevel) -> [MenuBarElement] {
        let visible = model.settings.visibleMenuBarElements.filter { role.elements.contains($0) }
        switch level {
        case .full:
            // Se l'utente nasconde tutto, resta l'icona/copertina per non far sparire l'elemento.
            return visible.isEmpty && role != .controls ? [.artwork] : visible
        case .compact:
            return role == .controls ? [.controls] : [.artwork] + (role == .combined ? [.controls] : [])
        case .icon:
            return role == .controls ? [.controls] : [.artwork]
        }
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
            .onDisappear { if !measuring { layout.buttonFrames[.controls] = nil } }
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

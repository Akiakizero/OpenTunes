// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Testo su una riga che scorre se non entra in `maxWidth`; si ferma con il mouse sopra.
///
/// Ogni giro inizia con una pausa (`Motion.marqueePause`) e poi scorre a velocità costante.
struct MarqueeText: View {
    let text: String
    var font: Font = DesignSystem.Typography.body
    var maxWidth: CGFloat
    /// Se `false` il testo viene troncato invece di scorrere.
    var scrolls = true

    @State private var textWidth: CGFloat = 0
    @State private var isHovering = false
    /// Istante a cui corrisponde lo scostamento zero del ciclo corrente.
    @State private var origin = Date.now
    /// Fase salvata quando il mouse ferma lo scorrimento.
    @State private var pausedPhase: Double?

    private let gap = DesignSystem.Spacing.xxl

    var body: some View {
        let overflows = textWidth > maxWidth
        let width = min(textWidth, maxWidth)
        Group {
            if overflows && scrolls {
                TimelineView(.animation(paused: isHovering)) { context in
                    let offset = offset(at: context.date)
                    HStack(spacing: gap) {
                        label
                        label
                    }
                    .offset(x: -offset)
                    .frame(width: width, alignment: .leading)
                    .clipped()
                    .mask(fadeMask)
                }
            } else {
                label.frame(width: width, alignment: .leading)
                    .truncationMode(.tail)
            }
        }
        .frame(width: width > 0 ? width : nil)
        .background(measure)
        .onHover { hovering in
            if hovering {
                pausedPhase = phase(at: .now)
            } else if let paused = pausedPhase {
                origin = Date.now.addingTimeInterval(-paused)
                pausedPhase = nil
            }
            isHovering = hovering
        }
        .onChange(of: text) {
            origin = .now
            pausedPhase = isHovering ? 0 : nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private var label: some View {
        Text(text).font(font).lineLimit(1).fixedSize()
    }

    /// Misura la larghezza naturale del testo senza influenzare il layout.
    private var measure: some View {
        label.hidden()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
            .frame(width: 0, alignment: .leading)
    }

    private var fadeMask: some View {
        let fade = DesignSystem.Spacing.s / max(1, min(textWidth, maxWidth))
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0), .init(color: .black, location: fade),
                .init(color: .black, location: 1 - fade), .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
    }

    /// Secondi trascorsi nel ciclo corrente.
    private func phase(at date: Date) -> Double {
        if let pausedPhase { return pausedPhase }
        let distance = Double(textWidth + gap)
        let cycle = DesignSystem.Motion.marqueePause + distance / DesignSystem.Motion.marqueeSpeed
        return date.timeIntervalSince(origin).truncatingRemainder(dividingBy: cycle)
    }

    private func offset(at date: Date) -> CGFloat {
        CGFloat(max(0, phase(at: date) - DesignSystem.Motion.marqueePause) * DesignSystem.Motion.marqueeSpeed)
    }
}

#Preview("Testo scorrevole — chiaro") {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
        MarqueeText(text: "Un titolo molto lungo che non entra nello spazio disponibile", maxWidth: 180)
        MarqueeText(text: "Breve", maxWidth: 180)
    }
    .padding(DesignSystem.Spacing.xl)
    .preferredColorScheme(.light)
}

#Preview("Testo scorrevole — scuro") {
    MarqueeText(text: "Un titolo molto lungo che non entra nello spazio disponibile", font: DesignSystem.Typography.title, maxWidth: 180)
        .padding(DesignSystem.Spacing.xl)
        .preferredColorScheme(.dark)
}

// SPDX-License-Identifier: GPL-3.0-or-later
//
// Adattato da DynamicNotchKit (`Views/NotchShape.swift`), Copyright (c) 2025 Kai Azim, licenza MIT
// (testo completo in CREDITS.md).

import SwiftUI

/// Forma del notch: in alto gli angoli si allargano verso l'esterno (si raccordano alla menu bar),
/// in basso sono arrotondati. Il contenuto va rientrato di `topCornerRadius` su ogni lato.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = topCornerRadius, bottom = bottomCornerRadius
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top), control: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY), control: CGPoint(x: rect.minX + top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom), control: CGPoint(x: rect.maxX - top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview("Forma del notch") {
    VStack(spacing: DesignSystem.Spacing.l) {
        NotchShape(topCornerRadius: DesignSystem.Radius.notchClosedTop, bottomCornerRadius: DesignSystem.Radius.notchClosedBottom)
            .frame(width: 260, height: 32)
        NotchShape(topCornerRadius: DesignSystem.Radius.notchOpenTop, bottomCornerRadius: DesignSystem.Radius.notchOpenBottom)
            .frame(width: 420, height: 150)
    }
    .padding(DesignSystem.Spacing.xl)
}

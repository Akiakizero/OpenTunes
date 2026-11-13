// SPDX-License-Identifier: GPL-3.0-or-later
//
// Il calcolo della misura del notch da `auxiliaryTopLeftArea`/`auxiliaryTopRightArea` e `safeAreaInsets`
// è adattato da DynamicNotchKit (`NSScreen+Extensions.swift`), Copyright (c) 2025 Kai Azim, licenza MIT
// (testo completo in CREDITS.md).

import AppKit

/// Dove sta il notch (o, senza notch, la capsula al centro della menu bar) su uno schermo.
struct NotchGeometry: Equatable {
    /// Frame dello schermo in coordinate globali.
    var screenFrame: CGRect
    /// Misura del notch fisico; senza notch quella della capsula.
    var notchSize: CGSize
    /// `true` se lo schermo ha un notch fisico.
    var hasNotch: Bool
    var menuBarHeight: CGFloat

    /// - Parameters:
    ///   - leftArea, rightArea: aree ai lati del notch (`nil` senza notch).
    ///   - safeTop: `safeAreaInsets.top` dello schermo (altezza del notch).
    init(screenFrame: CGRect, visibleFrame: CGRect, leftArea: CGRect?, rightArea: CGRect?, safeTop: CGFloat) {
        self.screenFrame = screenFrame
        menuBarHeight = max(0, screenFrame.maxY - visibleFrame.maxY)
        if let leftArea, let rightArea, safeTop > 0, leftArea.width + rightArea.width < screenFrame.width {
            hasNotch = true
            notchSize = CGSize(width: screenFrame.width - leftArea.width - rightArea.width, height: safeTop)
        } else {
            hasNotch = false
            // Capsula dentro la menu bar, con un piccolo margine sopra e sotto.
            let height = max(DesignSystem.Size.menuBarArtwork + DesignSystem.Spacing.xs, menuBarHeight - DesignSystem.Spacing.xs)
            notchSize = CGSize(width: DesignSystem.Size.notchlessCapsuleWidth, height: height)
        }
    }

    init(screen: NSScreen) {
        self.init(
            screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
            leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea, safeTop: screen.safeAreaInsets.top)
    }

    /// Frame del pannello: centrato sul notch, attaccato al bordo superiore, abbastanza grande per lo stato aperto.
    var panelFrame: CGRect {
        // Il caso più largo tra lo stato aperto e il "peek" (spostato a destra, quindi simmetrico qui).
        let open = DesignSystem.Size.notchExpandedWidth + 2 * DesignSystem.Radius.notchOpenTop
        let peek = notchSize.width + 2 * DesignSystem.Size.notchPeekWidth + 2 * DesignSystem.Radius.notchClosedTop
        let width = max(open, peek) + 2 * DesignSystem.Spacing.xxl
        let height: CGFloat = 260
        return CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
    }

    /// Area sensibile al mouse in coordinate schermo, da un frame nella finestra (origine in alto a sinistra).
    static func hitRect(local: CGRect, panelFrame: CGRect, margin: CGFloat = DesignSystem.Spacing.xs) -> CGRect {
        CGRect(x: panelFrame.minX + local.minX, y: panelFrame.maxY - local.maxY, width: local.width, height: local.height)
            .insetBy(dx: -margin, dy: -margin)
    }

    /// Lo schermo da usare: il primo con il notch, altrimenti quello con la menu bar.
    @MainActor
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil } ?? NSScreen.screens.first
    }
}

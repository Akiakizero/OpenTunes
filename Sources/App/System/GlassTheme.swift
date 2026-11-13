// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

extension NSGlassEffectView {
    /// Applica il tema delle superfici al vetro AppKit (finestra flottante, HUD, widget sulla scrivania).
    func apply(theme: SurfaceTheme, tint: AccentTint?) {
        style = theme.usesClearGlass ? .clear : .regular
        switch theme {
        case .artwork: tintColor = tint?.dynamicColor(opacity: DesignSystem.glassTintOpacity)
        case .monochrome, .transparent: tintColor = nil
        case .opaque: tintColor = .windowBackgroundColor.withAlphaComponent(SurfaceTheme.opaqueVeilOpacity)
        case .custom:
            let custom = CustomTheme.active
            if let fixed = custom.fixedTint {
                tintColor = NSColor(srgbRed: fixed.r, green: fixed.g, blue: fixed.b, alpha: custom.opacity)
            } else {
                tintColor = tint?.dynamicColor(opacity: custom.opacity)
            }
        }
    }
}

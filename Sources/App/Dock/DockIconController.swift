// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Copertina come icona del Dock (opzionale). Con l'opzione attiva l'app compare nel Dock
/// (`.regular`); spenta torna solo in menu bar (`.accessory`, come da `LSUIElement`).
@MainActor
final class DockIconController {
    private let model: AppModel
    private var tasks: [Task<Void, Never>] = []

    /// Proporzioni della griglia delle icone di macOS: il riquadro occupa ~80 % del lato, angoli ~22 %.
    static let iconInsetFraction: CGFloat = 0.1
    static let iconCornerFraction: CGFloat = 0.225

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        let settings = model.settings
        tasks.append(observeChanges({ settings.dockShowsArtwork }) { [weak self] enabled in
            NSApp.setActivationPolicy(enabled ? .regular : .accessory)
            self?.update()
        })
        tasks.append(observeChanges({ [model] in model.track?.artworkHash }) { [weak self] _ in self?.update() })
    }

    private func update() {
        guard model.settings.dockShowsArtwork, let artwork = model.track?.artwork else {
            // `nil` ripristina l'icona dell'app.
            NSApp.applicationIconImage = nil
            return
        }
        let side = 512
        NSApp.applicationIconImage = artwork.squareThumbnail(
            side: side, cornerFraction: Self.iconCornerFraction, inset: CGFloat(side) * Self.iconInsetFraction)
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Decide la modalità compatta della menu bar quando lo spazio a destra del notch non basta.
///
/// Gli elementi della status bar crescono verso sinistra (il bordo destro resta fermo).
/// Senza notch non serve mai la modalità compatta: se manca spazio ci pensa il sistema.
enum NotchLayout {
    /// Isteresi: per tornare alla modalità piena servono questi punti liberi in più.
    static let margin: CGFloat = 8

    /// - Parameters:
    ///   - itemFrame: frame attuale dell'elemento (o dell'unione degli elementi) in coordinate schermo.
    ///   - fullWidth: larghezza che avrebbe l'elemento in modalità piena.
    ///   - notch: intervallo orizzontale occupato dal notch, `nil` se lo schermo non ce l'ha.
    ///   - isCompact: stato corrente.
    static func shouldBeCompact(itemFrame: CGRect, fullWidth: CGFloat, notch: ClosedRange<CGFloat>?, isCompact: Bool) -> Bool {
        guard let notch else { return false }
        if isCompact {
            // Resta compatta finché la versione piena finirebbe sotto il notch.
            let predictedMinX = itemFrame.maxX - fullWidth
            return predictedMinX < notch.upperBound + margin
        }
        // Un elemento che non sta tutto a destra del notch è coperto o nascosto dal sistema.
        return itemFrame.minX < notch.upperBound
    }
}

extension NSScreen {
    /// Intervallo orizzontale del notch in coordinate schermo, `nil` senza notch.
    var notchRange: ClosedRange<CGFloat>? {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea, left.maxX < right.minX else { return nil }
        return left.maxX...right.minX
    }
}

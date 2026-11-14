// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Quanto spazio occupa l'elemento in menu bar: si riduce da solo quando lo spazio non basta.
enum MenuBarLevel: Int, CaseIterable, Comparable, Sendable {
    /// Solo copertina (o icona).
    case icon
    /// Copertina e play/pausa.
    case compact
    /// Gli elementi scelti dall'utente (titolo, pulsanti, love…).
    case full

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var smaller: MenuBarLevel { MenuBarLevel(rawValue: rawValue - 1) ?? .icon }
    var bigger: MenuBarLevel { MenuBarLevel(rawValue: rawValue + 1) ?? .full }

    var label: String {
        switch self {
        case .icon: "icona"
        case .compact: "compatta"
        case .full: "piena"
        }
    }
}

/// Sceglie il livello dell'elemento in menu bar in modo stabile (niente salti avanti e indietro).
///
/// Gli elementi della status bar crescono verso sinistra: il bordo destro resta fermo.
/// - Con il notch lo spazio si calcola: il livello più grande che finisce a destra del notch. Per salire serve
///   `margin` in più (isteresi), così un titolo che cambia di pochi punti non fa oscillare l'elemento.
/// - Senza notch (o se il sistema nasconde l'elemento per altri motivi, es. troppe icone o menu dell'app lunghi)
///   lo spazio non si conosce: quando l'elemento sparisce si scende di un livello e si ricorda la larghezza che non
///   stava. Si risale solo se la versione più grande è più stretta di quella (titolo più corto), se a destra è cambiato
///   qualcosa o dopo `retryInterval`; mai prima di `settleTime` dall'ultimo cambio.
struct MenuBarFit: Equatable, Sendable {
    struct Observation: Sendable {
        /// Bordo destro dell'elemento (o dell'unione degli elementi) in coordinate schermo.
        var rightEdge: CGFloat
        /// Larghezza misurata per ogni livello.
        var widths: [MenuBarLevel: CGFloat]
        /// Intervallo orizzontale del notch, `nil` se lo schermo non ce l'ha.
        var notch: ClosedRange<CGFloat>?
        /// Il sistema non mostra l'elemento (coperto, fuori schermo).
        var isHidden: Bool
        var now: Date
    }

    struct Failure: Equatable, Sendable {
        var width: CGFloat
        var rightEdge: CGFloat
        var date: Date
    }

    static let margin: CGFloat = 8
    static let settleTime: TimeInterval = 3
    static let retryInterval: TimeInterval = 300

    private(set) var level: MenuBarLevel = .full
    private(set) var failure: Failure?
    private(set) var lastChange: Date = .distantPast

    init(level: MenuBarLevel = .full) {
        self.level = level
    }

    /// Aggiorna il livello; restituisce `true` se è cambiato.
    @discardableResult
    mutating func update(_ observation: Observation) -> Bool {
        let o = observation
        let settled = o.now.timeIntervalSince(lastChange) >= Self.settleTime
        var target = level
        // Nascosto perché finisce sotto il notch (o troppo vicino): lo spazio si calcola, non serve ricordarlo.
        let hiddenByNotch = o.notch.map { o.rightEdge - (o.widths[level] ?? .infinity) < $0.upperBound + Self.margin } ?? false
        if o.isHidden, !hiddenByNotch {
            // Il sistema l'ha nascosto per altri motivi: si scende di uno e si ricorda cosa non stava.
            if level > .icon, o.now.timeIntervalSince(lastChange) >= 1 {
                failure = Failure(width: o.widths[level] ?? .infinity, rightEdge: o.rightEdge, date: o.now)
                target = level.smaller
            }
        } else if level < .full, settled, canTry(level.bigger, o) {
            target = level.bigger
        }
        if let notch = o.notch {
            // Il livello più grande che sta a destra del notch (con margine per salire).
            let cap = MenuBarLevel.allCases.reversed().first { candidate in
                let width = o.widths[candidate] ?? .infinity
                // Il sistema nasconde gli elementi anche a pochi punti dal notch: serve sempre `margin`, il doppio per salire.
                return o.rightEdge - width >= notch.upperBound + (candidate > level ? 2 * Self.margin : Self.margin)
            } ?? .icon
            if cap < target {
                target = cap
            } else if !o.isHidden, cap > target, canTry(cap, o) {
                // Con il notch lo spazio è noto: si sale subito fin dove c'è posto.
                target = cap
            }
        }
        guard target != level else { return false }
        level = target
        lastChange = o.now
        return true
    }

    /// Si può provare `candidate`? Sì se non è già fallita una larghezza uguale o minore nelle stesse condizioni.
    private func canTry(_ candidate: MenuBarLevel, _ o: Observation) -> Bool {
        guard let failure else { return true }
        let width = o.widths[candidate] ?? .infinity
        return width + Self.margin < failure.width
            || abs(o.rightEdge - failure.rightEdge) > Self.margin
            || o.now.timeIntervalSince(failure.date) >= Self.retryInterval
    }

    /// Torna alla versione piena e dimentica i fallimenti (es. modalità automatica spenta, niente in riproduzione).
    mutating func reset() {
        level = .full
        failure = nil
        lastChange = .distantPast
    }

    /// Dimentica i fallimenti senza cambiare livello (cambio di schermo o di elementi: lo spazio è diverso).
    mutating func forgetFailures() {
        failure = nil
    }
}

extension NSScreen {
    /// Intervallo orizzontale del notch in coordinate schermo, `nil` senza notch.
    var notchRange: ClosedRange<CGFloat>? {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea, left.maxX < right.minX else { return nil }
        return left.maxX...right.minX
    }
}

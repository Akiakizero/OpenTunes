// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Token di design condivisi da tutte le superfici (menu bar, popover, finestra flottante, HUD).
///
/// Regola: spaziature, raggi, tipografia e durate si prendono solo da qui. I materiali sono
/// solo quelli di sistema (`glassEffect`), mai blur o sfondi disegnati a mano.
enum DesignSystem {
    /// Spaziature, multipli di 4.
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Raggi degli angoli.
    enum Radius {
        /// Copertina in menu bar.
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        /// Finestra flottante e HUD.
        static let panel: CGFloat = 24
        /// Notch chiuso e aperto (angoli in alto, che si raccordano alla menu bar, e in basso).
        static let notchClosedTop: CGFloat = 6
        static let notchClosedBottom: CGFloat = 14
        static let notchOpenTop: CGFloat = 16
        static let notchOpenBottom: CGFloat = 28
    }

    /// Scala tipografica: solo stili di testo di sistema, così rispettano le preferenze dell'utente.
    enum Typography {
        static let largeTitle = Font.title2.weight(.semibold)
        static let title = Font.headline
        static let subtitle = Font.subheadline
        static let body = Font.body
        static let caption = Font.caption
        static let time = Font.caption.monospacedDigit()
        static let menuBar = Font.system(size: NSFont.systemFontSize(for: .regular), weight: .medium)
        static let sectionHeader = Font.caption.weight(.semibold)
    }

    /// Durate e curve delle animazioni.
    enum Motion {
        static let quick: Double = 0.15
        static let standard: Double = 0.25
        static let slow: Double = 0.45
        static let artworkChange = Animation.easeInOut(duration: standard)
        static let hover = Animation.easeOut(duration: quick)
        /// Velocità del testo scorrevole in punti al secondo.
        static let marqueeSpeed: Double = 30
        /// Pausa all'inizio di ogni giro del testo scorrevole.
        static let marqueePause: Double = 1.5
        /// Quanto resta visibile l'HUD.
        static let hudVisible: Double = 1.6
        /// Apertura e chiusura del player nel notch.
        static let notchOpen = Animation.bouncy(duration: 0.4)
        static let notchClose = Animation.smooth(duration: 0.35)
        /// Attesa prima di aprire il notch al passaggio del mouse (evita aperture per sbaglio).
        static let notchHoverDelay: Double = 0.12
        /// Quanto resta visibile il titolo nel notch dopo un cambio brano.
        static let notchPeek: Double = 3
    }

    /// Dimensioni ricorrenti.
    enum Size {
        static let menuBarArtwork: CGFloat = 18
        static let menuBarControl: CGFloat = 20
        /// Area cliccabile dei pulsanti di riproduzione fuori dalla menu bar.
        static let control: CGFloat = 32
        /// Icone piccole (icona dell'app sorgente).
        static let smallIcon: CGFloat = 16
        /// Copertina nel menu rapido.
        static let menuArtwork: CGFloat = 32
        static let popoverWidth: CGFloat = 320
        static let popoverArtwork: CGFloat = 288
        static let historyArtwork: CGFloat = 32
        static let floatingCompact = CGSize(width: 380, height: 88)
        static let floatingLarge = CGSize(width: 300, height: 500)
        static let settingsWidth: CGFloat = 520
        static let settingsHeight: CGFloat = 600
        static let hud: CGFloat = 200
        static let hudArtwork: CGFloat = 120
        /// Widget sulla scrivania: misure di base dei layout (poi scalate con la finestra).
        static let desktopCard = CGSize(width: 260, height: 420)
        static let desktopCardChart = CGSize(width: 260, height: 540)
        static let desktopHorizontal = CGSize(width: 380, height: 136)
        static let desktopHorizontalChart = CGSize(width: 380, height: 236)
        static let desktopArtwork = CGSize(width: 240, height: 240)
        /// Scala minima e massima del widget sulla scrivania.
        static let desktopScale: ClosedRange<CGFloat> = 0.6...2.5
        /// Player nel notch aperto.
        static let notchExpandedWidth: CGFloat = 420
        static let notchExpandedArtwork: CGFloat = 76
        /// Larghezza delle "ali" del notch chiuso (copertina a sinistra, indicatore a destra).
        static let notchWing: CGFloat = 36
        /// Larghezza del titolo mostrato a destra quando il notch "sbircia" al cambio brano.
        static let notchPeekWidth: CGFloat = 200
        /// Capsula sugli schermi senza notch.
        static let notchlessCapsuleWidth: CGFloat = 200
        static let progressTrack: CGFloat = 4
        static let progressTrackHover: CGFloat = 8
    }

    /// Opacità della tinta applicata al vetro.
    static let glassTintOpacity: Double = 0.35
}

extension View {
    /// Vetro di sistema con la tinta della copertina: l'unico "sfondo" ammesso per le superfici.
    func surfaceGlass(tint: Color?, cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        glassEffect(
            .regular.tint(tint?.opacity(DesignSystem.glassTintOpacity)).interactive(interactive),
            in: .rect(cornerRadius: cornerRadius))
    }
}

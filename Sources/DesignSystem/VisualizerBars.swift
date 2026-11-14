// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Barre che seguono la musica (notch e finestra flottante), nello stile della Dynamic Island di iPhone:
/// capsule sottili centrate in verticale che crescono verso l'alto e verso il basso, colorate con una sfumatura
/// orizzontale dei colori della copertina. Nel silenzio e in pausa restano dei puntini.
///
/// Con `levels` (spettro reale di `AudioSpectrum`) ogni barra è una banda dell'audio in uscita, dai bassi a sinistra
/// agli acuti a destra; se non arriva audio (permesso negato) diventano un'animazione continua (somme di seni).
/// Disegnate con `Canvas` a 60 fotogrammi al secondo; in pausa `TimelineView` si ferma e il costo è nullo.
struct VisualizerBars: View {
    var isPlaying: Bool
    var barCount = 6
    /// Colori della sfumatura, da sinistra a destra (uno solo = tinta unita con un riflesso più chiaro).
    var colors: [Color] = [.primary]
    /// Livelli reali 0…1 letti a ogni fotogramma (`nil` = solo animazione).
    var levels: (@Sendable () -> [Float]?)? = nil

    static let framesPerSecond: Double = 60
    /// Altezza minima: un puntino rotondo (la barra è larga quanto alta).
    static let restingLevel = 0.0

    /// Con «Riduci movimento» le barre restano ferme.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isPlaying: Bool, barCount: Int = 6, colors: [Color], levels: (@Sendable () -> [Float]?)? = nil) {
        self.isPlaying = isPlaying
        self.barCount = barCount
        self.colors = colors.isEmpty ? [.primary] : colors
        self.levels = levels
    }

    init(isPlaying: Bool, barCount: Int = 6, color: Color = .primary, levels: (@Sendable () -> [Float]?)? = nil) {
        self.init(isPlaying: isPlaying, barCount: barCount, colors: [color], levels: levels)
    }

    var body: some View {
        let animates = isPlaying && !reduceMotion
        TimelineView(.animation(minimumInterval: 1 / Self.framesPerSecond, paused: !animates)) { context in
            Canvas { canvas, size in
                let time = context.date.timeIntervalSinceReferenceDate
                let real = animates ? levels?() : nil
                // Barre sottili con spazi più larghi delle barre, come nella Dynamic Island.
                let width = size.width / (CGFloat(barCount) * 2.4 - 1.4)
                let gap = width * 1.4
                var bars = Path()
                for index in 0..<barCount {
                    let level: Double = if let real, !real.isEmpty {
                        // Bassi e medi al centro, acuti ai lati; profilo più alto al centro (Dynamic Island).
                        Double(real[Self.band(forBar: index, barCount: barCount, bandCount: real.count)])
                            * Self.envelope(bar: index, barCount: barCount)
                    } else if animates {
                        Self.level(bar: index, time: time) * Self.envelope(bar: index, barCount: barCount)
                    } else {
                        Self.restingLevel
                    }
                    let height = width + (size.height - width) * CGFloat(min(1, max(0, level)))
                    let rect = CGRect(
                        x: CGFloat(index) * (width + gap), y: (size.height - height) / 2, width: width, height: height)
                    bars.addRoundedRect(in: rect, cornerSize: CGSize(width: width / 2, height: width / 2))
                }
                canvas.fill(bars, with: .linearGradient(
                    Gradient(colors: gradientColors),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
            }
        }
        .accessibilityHidden(true)
    }

    private var gradientColors: [Color] {
        colors.count == 1 ? [colors[0], colors[0].mix(with: .white, by: 0.35)] : colors
    }

    /// Banda dello spettro per la barra in posizione `bar`: la banda 0 (bassi) va al centro, le successive si
    /// alternano verso i lati (…4 2 0 1 3 5…), così il profilo è simmetrico come nella Dynamic Island.
    static func band(forBar bar: Int, barCount: Int, bandCount: Int) -> Int {
        let center = (barCount - 1) / 2
        let rank = bar <= center ? (center - bar) * 2 : (bar - center) * 2 - 1
        return min(bandCount - 1, max(0, rank * bandCount / max(1, barCount)))
    }

    /// Altezza massima relativa della barra: 1 al centro, più bassa ai lati (50/60/90/100/90/60% con 6 barre).
    static func envelope(bar: Int, barCount: Int) -> Double {
        guard barCount > 1 else { return 1 }
        let middle = Double(barCount - 1) / 2
        let distance = abs(Double(bar) - middle) / middle
        return 1 - 0.45 * distance * distance
    }

    /// Altezza 0.2…1 della barra all'istante `time`: tre seni a frequenze diverse per barra, senza scatti.
    static func level(bar: Int, time: TimeInterval) -> Double {
        let phase = Double(bar) * 1.7
        let value = sin(time * 5.3 + phase) * 0.5 + sin(time * 8.1 + phase * 2.3) * 0.3 + sin(time * 2.9 + phase * 0.7) * 0.2
        return 0.2 + 0.8 * (value + 1) / 2
    }
}

#Preview("Visualizer") {
    HStack(spacing: DesignSystem.Spacing.l) {
        VisualizerBars(isPlaying: true).frame(width: 24, height: 16)
        VisualizerBars(isPlaying: false).frame(width: 24, height: 16)
        VisualizerBars(isPlaying: true, colors: [.pink, .orange, .yellow]).frame(width: 40, height: 24)
    }
    .padding()
    .background(.black)
}

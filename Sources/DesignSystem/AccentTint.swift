// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Colore RGB in spazio sRGB, componenti in 0…1.
struct RGB: Equatable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    /// Luminanza relativa WCAG 2.1.
    var luminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// Saturazione HSV.
    var saturation: Double {
        let maxC = max(r, g, b), minC = min(r, g, b)
        return maxC == 0 ? 0 : (maxC - minC) / maxC
    }

    var brightness: Double { max(r, g, b) }

    /// Rapporto di contrasto WCAG tra due colori (1…21).
    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let (l1, l2) = (max(a.luminance, b.luminance), min(a.luminance, b.luminance))
        return (l1 + 0.05) / (l2 + 0.05)
    }

    /// Miscela lineare verso `other` (0 = self, 1 = other).
    func mixed(with other: RGB, amount t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    static let white = RGB(r: 1, g: 1, b: 1)
    static let black = RGB(r: 0, g: 0, b: 0)

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
}

/// Tinta d'accento estratta dalla copertina, con controllo di contrasto per tema chiaro e scuro.
struct AccentTint: Equatable, Sendable {
    /// Colore dominante grezzo.
    let dominant: RGB

    /// Rapporto minimo tra la tinta e il testo principale del tema (WCAG AA per testo grande).
    static let minimumContrast: Double = 4.5

    /// Tinta adatta al tema: in scuro si scurisce finché il testo bianco resta leggibile,
    /// in chiaro si schiarisce finché resta leggibile il testo nero.
    func rgb(for scheme: ColorScheme) -> RGB {
        Self.adjusted(dominant, against: scheme == .dark ? .white : .black, minimum: Self.minimumContrast)
    }

    func color(for scheme: ColorScheme) -> Color { rgb(for: scheme).color }

    /// Colore AppKit che segue da solo il tema (per `NSGlassEffectView.tintColor`).
    func dynamicColor(opacity: Double) -> NSColor {
        let light = rgb(for: .light), dark = rgb(for: .dark)
        return NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: opacity)
        }
    }

    /// Avvicina `color` al colore opposto a `text` finché il contrasto non basta.
    static func adjusted(_ color: RGB, against text: RGB, minimum: Double) -> RGB {
        let target: RGB = text == .white ? .black : .white
        var value = color
        var step = 0.0
        while RGB.contrast(value, text) < minimum, step < 1 {
            step = min(1, step + 0.05)
            value = color.mixed(with: target, amount: step)
        }
        return value
    }

    /// Colore dominante da un insieme di pixel: istogramma a 4 bit per canale, pesato per
    /// saturazione, scartando i pixel quasi neri o quasi bianchi se ce ne sono altri.
    static func dominant(in pixels: [RGB]) -> RGB? {
        guard !pixels.isEmpty else { return nil }
        struct Bucket { var count = 0.0; var r = 0.0; var g = 0.0; var b = 0.0 }
        func key(_ p: RGB) -> Int {
            (Int(p.r * 15.999) << 8) | (Int(p.g * 15.999) << 4) | Int(p.b * 15.999)
        }
        let colorful = pixels.filter { $0.brightness > 0.12 && !($0.saturation < 0.08 && $0.brightness > 0.92) }
        let source = colorful.isEmpty ? pixels : colorful
        var buckets: [Int: Bucket] = [:]
        for p in source {
            let weight = 1 + 2 * p.saturation
            var bucket = buckets[key(p), default: Bucket()]
            bucket.count += weight
            bucket.r += p.r * weight
            bucket.g += p.g * weight
            bucket.b += p.b * weight
            buckets[key(p)] = bucket
        }
        guard let best = buckets.values.max(by: { $0.count < $1.count }) else { return nil }
        return RGB(r: best.r / best.count, g: best.g / best.count, b: best.b / best.count)
    }

    /// Estrae la tinta da un'immagine ridotta a 24×24.
    static func from(_ image: NSImage) -> AccentTint? {
        let side = 24
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
        var pixels: [RGB] = []
        pixels.reserveCapacity(side * side)
        for i in 0..<(side * side) {
            let alpha = Double(bytes[i * 4 + 3]) / 255
            guard alpha > 0.5 else { continue }
            pixels.append(
                RGB(
                    r: Double(bytes[i * 4]) / 255 / alpha,
                    g: Double(bytes[i * 4 + 1]) / 255 / alpha,
                    b: Double(bytes[i * 4 + 2]) / 255 / alpha))
        }
        return dominant(in: pixels).map(AccentTint.init(dominant:))
    }
}

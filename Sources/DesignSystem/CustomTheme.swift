// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Tema personalizzato in un file JSON, importabile ed esportabile dalle impostazioni e condivisibile con una PR
/// (cartella `themes/` del repository). Usa sempre il vetro di sistema: il file sceglie solo variante e tinta.
///
/// ```json
/// { "name": "Tramonto", "glass": "regular", "tint": "#FF7A45", "tintOpacity": 0.3, "accent": "#FFB000" }
/// ```
/// `tint` può essere un colore `#RRGGBB`, `"artwork"` (colore della copertina) o mancare (vetro senza tinta).
struct CustomTheme: Codable, Equatable, Sendable {
    enum GlassVariant: String, Codable, Sendable { case regular, clear }

    var name: String
    var glass: GlassVariant = .regular
    var tint: String?
    var tintOpacity: Double?
    /// Colore d'accento per pulsanti e barre (`#RRGGBB`); senza, quello della copertina o di sistema.
    var accent: String?

    init(name: String, glass: GlassVariant = .regular, tint: String? = nil, tintOpacity: Double? = nil, accent: String? = nil) {
        self.name = name
        self.glass = glass
        self.tint = tint
        self.tintOpacity = tintOpacity
        self.accent = accent
    }

    /// Tutti i campi tranne `name` sono facoltativi.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        glass = try container.decodeIfPresent(GlassVariant.self, forKey: .glass) ?? .regular
        tint = try container.decodeIfPresent(String.self, forKey: .tint)
        tintOpacity = try container.decodeIfPresent(Double.self, forKey: .tintOpacity)
        accent = try container.decodeIfPresent(String.self, forKey: .accent)
    }

    enum ValidationError: Error, CustomStringConvertible {
        case emptyName, invalidColor(String), invalidOpacity(Double)

        var description: String {
            switch self {
            case .emptyName: String(localized: "Il tema non ha un nome.")
            case .invalidColor(let value): String(localized: "Colore non valido: \(value) (usa #RRGGBB).")
            case .invalidOpacity(let value): String(localized: "Opacità non valida: \(value) (da 0 a 1).")
            }
        }
    }

    /// Legge e controlla un file di tema.
    static func decode(_ data: Data) throws -> CustomTheme {
        let theme = try JSONDecoder().decode(CustomTheme.self, from: data)
        try theme.validate()
        return theme
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { throw ValidationError.emptyName }
        if let tint, tint != "artwork", Self.rgb(hex: tint) == nil { throw ValidationError.invalidColor(tint) }
        if let accent, Self.rgb(hex: accent) == nil { throw ValidationError.invalidColor(accent) }
        if let tintOpacity, !(0...1).contains(tintOpacity) { throw ValidationError.invalidOpacity(tintOpacity) }
    }

    var usesArtworkTint: Bool { tint == "artwork" }
    var opacity: Double { tintOpacity ?? DesignSystem.glassTintOpacity }

    /// Tinta fissa del vetro (`nil` con `artwork` o senza tinta).
    var fixedTint: RGB? { tint.flatMap(Self.rgb(hex:)) }
    var accentColor: Color? { accent.flatMap(Self.rgb(hex:))?.color }

    static func rgb(hex: String) -> RGB? {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        return RGB(
            r: Double((number >> 16) & 0xFF) / 255, g: Double((number >> 8) & 0xFF) / 255, b: Double(number & 0xFF) / 255)
    }

    static func hex(_ color: RGB) -> String {
        String(format: "#%02X%02X%02X", Int((color.r * 255).rounded()), Int((color.g * 255).rounded()), Int((color.b * 255).rounded()))
    }

    /// Modello di partenza per chi vuole disegnare un tema.
    static let template = CustomTheme(name: "Il mio tema", glass: .regular, tint: "artwork", tintOpacity: 0.35, accent: nil)

    /// Tema personalizzato in uso (impostato dall'app quando l'utente lo importa o lo sceglie).
    @MainActor static var active: CustomTheme = .template
}

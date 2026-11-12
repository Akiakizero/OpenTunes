// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import SwiftUI

/// Azioni dei controlli di riproduzione.
enum PlaybackAction: Equatable {
    case previous, playPause, next
    case toggleShuffle, cycleRepeat
}

/// Precedente, play/pausa, successivo; nella variante completa anche shuffle e repeat.
struct PlaybackControls: View {
    enum Variant {
        /// Modalità compatta della menu bar: solo play/pausa.
        case minimal
        /// Menu bar e modalità compatta: play/pausa e successivo, piccoli.
        case compact
        /// Precedente, play/pausa, successivo.
        case standard
        /// Come `standard` più shuffle e repeat ai lati (se il player li supporta).
        case full
    }

    var variant: Variant
    var isPlaying: Bool
    /// `nil` = il player non espone lo shuffle.
    var shuffle: ShuffleMode? = nil
    /// `nil` = il player non espone il repeat.
    var repeatMode: RepeatMode? = nil
    var isEnabled = true
    var action: (PlaybackAction) -> Void

    var body: some View {
        HStack(spacing: spacing) {
            switch variant {
            case .minimal:
                playPause
            case .compact:
                playPause
                button(.next, symbol: "forward.fill", label: "Successivo")
            case .standard:
                transport
            case .full:
                shuffleButton
                Spacer(minLength: 0)
                transport
                Spacer(minLength: 0)
                repeatButton
            }
        }
        .font(font)
        .disabled(!isEnabled)
    }

    private var transport: some View {
        HStack(spacing: spacing) {
            button(.previous, symbol: "backward.fill", label: "Precedente")
            playPause
            button(.next, symbol: "forward.fill", label: "Successivo")
        }
    }

    private var playPause: some View {
        button(.playPause, symbol: isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "Pausa" : "Riproduci")
            .font(playFont)
            .contentTransition(.symbolEffect(.replace))
    }

    @ViewBuilder private var shuffleButton: some View {
        let on = shuffle.map { $0 != .off } ?? false
        button(.toggleShuffle, symbol: "shuffle", label: on ? "Disattiva shuffle" : "Attiva shuffle")
            .font(DesignSystem.Typography.body)
            .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .opacity(shuffle == nil ? 0 : 1)
            .disabled(shuffle == nil)
    }

    @ViewBuilder private var repeatButton: some View {
        let mode = repeatMode ?? .off
        button(
            .cycleRepeat, symbol: mode == .one ? "repeat.1" : "repeat",
            label: mode == .off ? "Attiva ripetizione" : mode == .all ? "Ripeti brano" : "Disattiva ripetizione"
        )
        .font(DesignSystem.Typography.body)
        .foregroundStyle(mode != .off ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        .opacity(repeatMode == nil ? 0 : 1)
        .disabled(repeatMode == nil)
    }

    private func button(_ action: PlaybackAction, symbol: String, label: String) -> some View {
        Button { self.action(action) } label: {
            Image(systemName: symbol)
                .frame(minWidth: hitSize, minHeight: hitSize)
                .contentShape(.rect)
        }
        .buttonStyle(ControlButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }

    private var spacing: CGFloat {
        switch variant {
        case .minimal, .compact: DesignSystem.Spacing.xxs
        case .standard, .full: DesignSystem.Spacing.l
        }
    }

    private var hitSize: CGFloat {
        isMenuBar ? DesignSystem.Size.menuBarControl : DesignSystem.Size.control
    }

    private var font: Font {
        isMenuBar ? DesignSystem.Typography.menuBar : .title3
    }

    private var playFont: Font {
        isMenuBar ? DesignSystem.Typography.menuBar : .title
    }

    private var isMenuBar: Bool { variant == .minimal || variant == .compact }
}

/// Pulsante senza bordo che si attenua quando è premuto.
struct ControlButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.5 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(DesignSystem.Motion.hover, value: configuration.isPressed)
    }
}

extension RepeatMode {
    /// Ordine del ciclo: off → tutto → brano → off.
    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

#Preview("Controlli — chiaro") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        PlaybackControls(variant: .compact, isPlaying: true) { _ in }
        PlaybackControls(variant: .standard, isPlaying: false) { _ in }
        PlaybackControls(variant: .full, isPlaying: true, shuffle: .tracks, repeatMode: .one) { _ in }
            .frame(width: 280)
    }
    .padding(DesignSystem.Spacing.xl)
    .preferredColorScheme(.light)
}

#Preview("Controlli — scuro") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        PlaybackControls(variant: .compact, isPlaying: false) { _ in }
        PlaybackControls(variant: .full, isPlaying: false, shuffle: .off, repeatMode: .all) { _ in }
            .frame(width: 280)
    }
    .padding(DesignSystem.Spacing.xl)
    .preferredColorScheme(.dark)
}

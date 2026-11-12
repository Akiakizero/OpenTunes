// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import SwiftUI

/// Barra di avanzamento con tempi trascorso/rimanente e seek trascinabile.
///
/// La posizione si calcola da `PlaybackState` a ogni frame del `TimelineView`, senza polling del player.
struct ProgressBar: View {
    var playback: PlaybackState
    var duration: TimeInterval?
    var showsTimes = true
    var onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?
    @State private var isHovering = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let total = duration ?? 0
            let current = playback.position(at: context.date, duration: duration)
            let fraction = dragFraction ?? (total > 0 ? current / total : 0)
            VStack(spacing: DesignSystem.Spacing.xs) {
                track(fraction: fraction, enabled: total > 0)
                if showsTimes {
                    HStack {
                        Text(Self.format(fraction * total))
                        Spacer()
                        Text(total > 0 ? "-" + Self.format(total - fraction * total) : "--:--")
                    }
                    .font(DesignSystem.Typography.time)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Avanzamento")
        .accessibilityValue(Self.format(playback.position(duration: duration)))
        .accessibilityAdjustableAction { direction in
            let step: TimeInterval = direction == .increment ? 10 : -10
            onSeek(max(0, playback.position(duration: duration) + step))
        }
    }

    private func track(fraction: Double, enabled: Bool) -> some View {
        let height = isHovering || dragFraction != nil ? DesignSystem.Size.progressTrackHover : DesignSystem.Size.progressTrack
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(.primary.opacity(0.8))
                    .frame(width: max(0, min(1, fraction)) * proxy.size.width)
            }
            .frame(height: height)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled else { return }
                        dragFraction = max(0, min(1, value.location.x / max(1, proxy.size.width)))
                    }
                    .onEnded { _ in
                        if let f = dragFraction, let duration { onSeek(f * duration) }
                        dragFraction = nil
                    }
            )
        }
        .frame(height: DesignSystem.Size.progressTrackHover + DesignSystem.Spacing.xs)
        .onHover { hovering in
            withAnimation(DesignSystem.Motion.hover) { isHovering = hovering && enabled }
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.down)))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview("Avanzamento — chiaro") {
    ProgressBar(playback: PreviewData.playing, duration: 251) { _ in }
        .frame(width: 280)
        .padding(DesignSystem.Spacing.xl)
        .preferredColorScheme(.light)
}

#Preview("Avanzamento — scuro") {
    ProgressBar(playback: PreviewData.paused, duration: 251) { _ in }
        .frame(width: 280)
        .padding(DesignSystem.Spacing.xl)
        .preferredColorScheme(.dark)
}

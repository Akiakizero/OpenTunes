// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import SwiftUI
import WidgetKit

/// Viste dei widget WidgetKit: piccola (copertina + play/pausa), media (con titolo e controlli),
/// grande (con gli scrobble recenti o i top artisti di Last.fm).
struct NowPlayingWidgetView: View {
    let entry: NowPlayingEntry
    /// Passata da fuori (e non letta dall'ambiente) così la vista si può disegnare anche fuori da WidgetKit.
    let family: WidgetFamily

    @Environment(\.colorScheme) private var colorScheme

    private var state: WidgetState { entry.state }

    private var tint: Color? {
        guard let c = state.tint, c.count == 3 else { return nil }
        return AccentTint(dominant: RGB(r: c[0], g: c[1], b: c[2])).color(for: colorScheme)
    }

    var body: some View {
        Group {
            if state.isDisabled == true {
                disabled
            } else if state.hasTrack {
                switch family {
                case .systemSmall: small
                case .systemLarge: large
                default: medium
                }
            } else {
                idle
            }
        }
        .tint(tint)
        .widgetURL(URL(string: "opentunes://player"))
        .containerBackground(for: .widget) {
            // Sfondo di sistema con la tinta della copertina sopra: niente sfondi disegnati a mano.
            ZStack {
                Rectangle().fill(.background)
                if let tint { tint.opacity(DesignSystem.glassTintOpacity) }
            }
        }
    }

    // MARK: Taglie

    private var small: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s) {
            HStack(alignment: .top) {
                artwork(side: 64)
                Spacer(minLength: 0)
                playPauseButton
            }
            Spacer(minLength: 0)
            titles(lines: 1)
            progress
        }
    }

    private var medium: some View {
        HStack(spacing: DesignSystem.Spacing.m) {
            artwork(side: 120)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s) {
                titles(lines: 2)
                Spacer(minLength: 0)
                progress
                controls
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
            medium.frame(height: 120)
            Divider()
            lastFM
            Spacer(minLength: 0)
        }
    }

    /// L'utente ha spento i widget nelle impostazioni di OpenTunes.
    private var disabled: some View {
        VStack(spacing: DesignSystem.Spacing.s) {
            Image(systemName: "rectangle.slash").font(.title).foregroundStyle(.secondary)
            Text("Widget disattivato in OpenTunes").font(DesignSystem.Typography.subtitle).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idle: some View {
        VStack(spacing: DesignSystem.Spacing.s) {
            Image(systemName: "music.note").font(.title).foregroundStyle(.secondary)
            Text("Niente in riproduzione").font(DesignSystem.Typography.subtitle).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Parti

    private func artwork(side: CGFloat) -> some View {
        Group {
            if let image = entry.artwork {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.quaternary)
                    .overlay { Image(systemName: "music.note").font(.title2).foregroundStyle(.secondary) }
            }
        }
        .frame(width: side, height: side)
        .clipShape(.rect(cornerRadius: side > 80 ? DesignSystem.Radius.medium : DesignSystem.Radius.small))
        .accessibilityHidden(true)
    }

    private func titles(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(state.title ?? "")
                .font(DesignSystem.Typography.title)
                .lineLimit(lines)
            Text(state.artist ?? state.playerName ?? "")
                .font(DesignSystem.Typography.subtitle)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// In riproduzione la barra avanza da sola (`timerInterval`), in pausa è ferma.
    @ViewBuilder private var progress: some View {
        if let interval = state.playbackInterval {
            Group {
                if state.isPlaying {
                    ProgressView(timerInterval: interval, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                } else {
                    ProgressView(value: state.fraction(at: entry.date))
                }
            }
            .progressViewStyle(.linear)
            .labelsHidden()
        }
    }

    private var controls: some View {
        HStack(spacing: DesignSystem.Spacing.l) {
            Button(intent: PreviousTrackIntent()) { Image(systemName: "backward.fill") }
                .accessibilityLabel("Precedente")
            playPauseButton
            Button(intent: NextTrackIntent()) { Image(systemName: "forward.fill") }
                .accessibilityLabel("Successivo")
            if state.canLove {
                Spacer(minLength: 0)
                Button(intent: ToggleLoveIntent()) { Image(systemName: state.isLoved ? "heart.fill" : "heart") }
                    .accessibilityLabel(state.isLoved ? "Togli il love" : "Love")
            }
        }
        .buttonStyle(.plain)
        .font(.title3)
    }

    private var playPauseButton: some View {
        Button(intent: PlayPauseIntent()) {
            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                .font(.title2)
                .frame(width: DesignSystem.Size.control, height: DesignSystem.Size.control)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.isPlaying ? "Pausa" : "Riproduci")
    }

    @ViewBuilder private var lastFM: some View {
        if state.lastFMUser == nil {
            Text("Collega Last.fm nelle impostazioni di OpenTunes per vedere qui i tuoi ascolti.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        } else {
            if !state.recentTracks.isEmpty {
                section("Ascolti recenti") {
                    ForEach(state.recentTracks.prefix(5)) { item in
                        HStack(spacing: DesignSystem.Spacing.s) {
                            Text(item.title).lineLimit(1)
                            Spacer(minLength: DesignSystem.Spacing.s)
                            Text(item.artist).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .font(DesignSystem.Typography.caption)
                    }
                }
            }
            if !state.topArtists.isEmpty {
                section("Top artisti") {
                    Text(state.topArtists.prefix(4).map { "\($0.name) (\($0.playCount))" }.joined(separator: " · "))
                        .font(DesignSystem.Typography.caption)
                        .lineLimit(2)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title).font(DesignSystem.Typography.sectionHeader).foregroundStyle(.secondary)
            content()
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import SwiftUI

/// Contenuto della finestra flottante. Lo sfondo è il vetro di sistema del pannello.
struct FloatingPlayerView: View {
    let model: AppModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let track = model.track {
                switch model.settings.floatingSize {
                case .compact: compact(track)
                case .large: large(track)
                }
            } else {
                idle
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(model.tintColor(for: colorScheme))
        .contextMenu { menuItems }
    }

    // MARK: Taglie

    private func compact(_ track: Track) -> some View {
        let size = DesignSystem.Size.floatingCompact
        let artwork = size.height - 2 * DesignSystem.Spacing.m
        return HStack(spacing: DesignSystem.Spacing.m) {
            ArtworkView(image: model.artwork, identity: track.artworkHash, size: artwork, cornerRadius: DesignSystem.Radius.small)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                MarqueeText(text: track.title, font: DesignSystem.Typography.title, maxWidth: textWidth(compact: true))
                Text(track.artist ?? " ")
                    .font(DesignSystem.Typography.subtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ProgressBar(playback: model.playback, duration: track.duration, showsTimes: false) { model.seek(to: $0) }
            }
            .frame(width: textWidth(compact: true), alignment: .leading)
            PlaybackControls(variant: .standard, isPlaying: model.playback.isPlaying) { model.perform($0) }
        }
        .padding(DesignSystem.Spacing.m)
    }

    private func large(_ track: Track) -> some View {
        let width = DesignSystem.Size.floatingLarge.width - 2 * DesignSystem.Spacing.l
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
            ArtworkView(image: model.artwork, identity: track.artworkHash, size: width, cornerRadius: DesignSystem.Radius.large)
            HStack(alignment: .center, spacing: DesignSystem.Spacing.s) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    MarqueeText(text: track.title, font: DesignSystem.Typography.title, maxWidth: textWidth(compact: false))
                    Text(track.artist ?? " ")
                        .font(DesignSystem.Typography.subtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if model.canLove {
                    Button { model.toggleLove() } label: {
                        Image(systemName: model.isLoved ? "heart.fill" : "heart")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.glass)
                    .help(model.isLoved ? "Togli il love" : "Love")
                    .accessibilityLabel(model.isLoved ? "Togli il love" : "Love")
                }
                Menu {
                    menuItems
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Altro")
            }
            ProgressBar(playback: model.playback, duration: track.duration) { model.seek(to: $0) }
            PlaybackControls(
                variant: .full, isPlaying: model.playback.isPlaying,
                shuffle: model.playback.shuffle, repeatMode: model.playback.repeatMode
            ) { model.perform($0) }
            VolumeSlider(model: model)
        }
        .padding(DesignSystem.Spacing.l)
    }

    private var idle: some View {
        VStack(spacing: DesignSystem.Spacing.s) {
            Image(systemName: "music.note").font(.title).foregroundStyle(.secondary)
            Text("Niente in riproduzione").font(DesignSystem.Typography.subtitle).foregroundStyle(.secondary)
        }
    }

    private func textWidth(compact: Bool) -> CGFloat {
        if compact {
            // Larghezza totale meno copertina, controlli (3 × 32 + 2 spazi) e margini.
            let size = DesignSystem.Size.floatingCompact
            let artwork = size.height - 2 * DesignSystem.Spacing.m
            let controls = 3 * DesignSystem.Size.control + 2 * DesignSystem.Spacing.l
            return size.width - artwork - controls - 4 * DesignSystem.Spacing.m
        }
        // Larghezza meno margini e pulsanti love e "Altro".
        return DesignSystem.Size.floatingLarge.width - 2 * DesignSystem.Spacing.l - 2 * (DesignSystem.Size.control + DesignSystem.Spacing.s)
    }

    @ViewBuilder private var menuItems: some View {
        if model.canLove {
            Button { model.toggleLove() } label: {
                Label(model.isLoved ? "Togli il love" : "Love", systemImage: model.isLoved ? "heart.slash" : "heart")
            }
        }
        TrackActionsMenuItems(model: model)
        Divider()
        Picker("Taglia", selection: Binding(get: { model.settings.floatingSize }, set: { model.settings.floatingSize = $0 })) {
            ForEach(FloatingSize.allCases) { Text($0.label).tag($0) }
        }
        if model.player != nil {
            Button("Apri \(model.player?.name ?? "")") { model.openSourcePlayer() }
        }
        Divider()
        Button("Nascondi finestra") { model.settings.floatingVisible = false }
    }
}

#Preview("Finestra flottante grande") {
    FloatingPlayerView(model: .preview(size: .large))
        .frame(width: DesignSystem.Size.floatingLarge.width, height: DesignSystem.Size.floatingLarge.height)
        .glassEffect(in: .rect(cornerRadius: DesignSystem.Radius.panel))
        .padding()
}

#Preview("Finestra flottante compatta — scuro") {
    FloatingPlayerView(model: .preview(size: .compact))
        .frame(width: DesignSystem.Size.floatingCompact.width, height: DesignSystem.Size.floatingCompact.height)
        .glassEffect(in: .rect(cornerRadius: DesignSystem.Radius.panel))
        .padding()
        .preferredColorScheme(.dark)
}

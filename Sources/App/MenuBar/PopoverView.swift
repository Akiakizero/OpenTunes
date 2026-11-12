// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import SwiftUI

/// Contenuto del popover della menu bar: player completo e brani recenti.
struct PopoverView: View {
    let model: AppModel
    var onOpenSettings: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// Quanti brani recenti mostrare.
    private let historyLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.l) {
            if let track = model.track {
                NowPlayingSection(model: model, track: track)
            } else {
                emptyState
            }
            recentSection
            Divider()
            footer
        }
        .padding(DesignSystem.Spacing.l)
        .frame(width: DesignSystem.Size.popoverWidth)
        .tint(model.tintColor(for: colorScheme))
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.s) {
            Image(systemName: "music.note")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Niente in riproduzione")
                .font(DesignSystem.Typography.title)
            if model.store.activeSourceID == "applescript" {
                Text("Il Now Playing di sistema non è disponibile: OpenTunes può leggere Musica e Spotify con il permesso Automazione.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Consenti l'accesso a Musica e Spotify") { model.requestAutomationPermission() }
            } else if model.store.exhausted {
                Text("Nessuna sorgente disponibile. Apri la finestra di diagnostica dal menu rapido.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    @ViewBuilder private var recentSection: some View {
        let recent = Array(
            model.store.recentTracks
                .filter { entry in !(model.track.map { entry.track.isSameItem(as: $0) } ?? false) }
                .prefix(historyLimit))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s) {
                Text("Ascoltati di recente")
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundStyle(.secondary)
                ForEach(recent) { entry in
                    RecentTrackRow(entry: entry)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: DesignSystem.Spacing.m) {
            Button {
                model.toggleFloatingWindow()
            } label: {
                Label(
                    model.settings.floatingVisible ? "Nascondi finestra" : "Finestra flottante",
                    systemImage: "pip")
            }
            Spacer()
            Button(action: onOpenSettings) {
                Label("Impostazioni", systemImage: "gearshape")
            }
            .labelStyle(.iconOnly)
            .help("Impostazioni")
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Esci", systemImage: "power")
            }
            .labelStyle(.iconOnly)
            .help("Esci da OpenTunes")
        }
        .buttonStyle(.borderless)
        .font(DesignSystem.Typography.subtitle)
    }
}

/// Copertina grande, metadati, avanzamento, controlli e volume.
private struct NowPlayingSection: View {
    let model: AppModel
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
            ArtworkView(
                image: model.artwork, identity: track.artworkHash,
                size: DesignSystem.Size.popoverArtwork, cornerRadius: DesignSystem.Radius.medium)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                MarqueeText(text: track.title, font: DesignSystem.Typography.title, maxWidth: DesignSystem.Size.popoverArtwork)
                if let artist = track.artist {
                    Text(artist).font(DesignSystem.Typography.subtitle).lineLimit(1)
                }
                if let album = track.album {
                    Text(album).font(DesignSystem.Typography.subtitle).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            ProgressBar(playback: model.playback, duration: track.duration) { model.seek(to: $0) }

            PlaybackControls(
                variant: .full, isPlaying: model.playback.isPlaying,
                shuffle: model.playback.shuffle, repeatMode: model.playback.repeatMode
            ) { model.perform($0) }

            VolumeSlider(model: model)

            if let player = model.player {
                Button {
                    model.openSourcePlayer()
                } label: {
                    Label {
                        Text("Apri \(player.name)")
                    } icon: {
                        if let icon = player.icon {
                            Image(nsImage: icon).resizable()
                                .frame(width: DesignSystem.Size.smallIcon, height: DesignSystem.Size.smallIcon)
                        } else {
                            Image(systemName: "arrow.up.forward.app")
                        }
                    }
                }
                .buttonStyle(.borderless)
                .font(DesignSystem.Typography.subtitle)
            }
        }
    }
}

/// Volume di sistema con le icone ai lati, come nei player di sistema.
struct VolumeSlider: View {
    let model: AppModel

    var body: some View {
        if let volume = model.volume {
            HStack(spacing: DesignSystem.Spacing.s) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(
                    value: Binding(get: { Double(volume) }, set: { model.setVolume(Float($0)) }),
                    in: 0...1
                )
                .controlSize(.small)
                .accessibilityLabel("Volume")
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
            .font(DesignSystem.Typography.caption)
        }
    }
}

private struct RecentTrackRow: View {
    let entry: NowPlayingStore.PlayedTrack

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s) {
            ArtworkView(
                image: entry.track.artwork, identity: entry.track.artworkHash,
                size: DesignSystem.Size.historyArtwork, cornerRadius: DesignSystem.Radius.tiny)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.track.title).font(DesignSystem.Typography.subtitle).lineLimit(1)
                if let artist = entry.track.artist {
                    Text(artist).font(DesignSystem.Typography.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: DesignSystem.Spacing.s)
            Text(entry.date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Popover — chiaro") {
    PopoverView(model: .preview(), onOpenSettings: {})
        .preferredColorScheme(.light)
}

#Preview("Popover — scuro") {
    PopoverView(model: .preview(track: PreviewData.longTrack), onOpenSettings: {})
        .preferredColorScheme(.dark)
}

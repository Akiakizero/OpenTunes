// SPDX-License-Identifier: GPL-3.0-or-later

import Charts
import MediaCore
import SwiftUI

/// Contenuto del widget live sulla scrivania. Si disegna alla misura di base del layout e la finestra
/// lo scala: così il ridimensionamento resta proporzionato in tutti i layout.
struct DesktopWidgetView: View {
    let model: AppModel

    @Environment(\.colorScheme) private var colorScheme

    private var settings: AppSettings { model.settings }
    private var layout: DesktopWidgetLayout { settings.desktopWidgetLayout }
    private var showsChart: Bool { settings.desktopWidgetShowsChart && layout != .artwork }

    var body: some View {
        let base = Self.baseSize(layout: layout, chart: settings.desktopWidgetShowsChart)
        GeometryReader { proxy in
            let scale = proxy.size.width / base.width
            content
                .frame(width: base.width, height: base.height)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .tint(model.tintColor(for: colorScheme))
        .contextMenu { menuItems }
    }

    static func baseSize(layout: DesktopWidgetLayout, chart: Bool) -> CGSize {
        switch layout {
        case .card: chart ? DesignSystem.Size.desktopCardChart : DesignSystem.Size.desktopCard
        case .horizontal: chart ? DesignSystem.Size.desktopHorizontalChart : DesignSystem.Size.desktopHorizontal
        case .artwork: DesignSystem.Size.desktopArtwork
        }
    }

    @ViewBuilder private var content: some View {
        if let track = model.track {
            switch layout {
            case .card: card(track)
            case .horizontal: horizontal(track)
            case .artwork: artworkOnly(track)
            }
        } else {
            VStack(spacing: DesignSystem.Spacing.s) {
                Image(systemName: "music.note").font(.title).foregroundStyle(.secondary)
                Text("Niente in riproduzione").font(DesignSystem.Typography.subtitle).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Layout

    private func card(_ track: Track) -> some View {
        let width = DesignSystem.Size.desktopCard.width - 2 * DesignSystem.Spacing.l
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
            ArtworkView(image: model.artwork, identity: track.artworkHash, size: width, cornerRadius: DesignSystem.Radius.large)
            titles(track, width: width)
            ProgressBar(playback: model.playback, duration: track.duration) { model.seek(to: $0) }
            PlaybackControls(variant: .standard, isPlaying: model.playback.isPlaying) { model.perform($0) }
                .frame(maxWidth: .infinity)
            if showsChart { chart }
        }
        .padding(DesignSystem.Spacing.l)
    }

    private func horizontal(_ track: Track) -> some View {
        let artwork = DesignSystem.Size.desktopHorizontal.height - 2 * DesignSystem.Spacing.m
        let textWidth = DesignSystem.Size.desktopHorizontal.width - artwork - 3 * DesignSystem.Spacing.m
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
            HStack(spacing: DesignSystem.Spacing.m) {
                ArtworkView(image: model.artwork, identity: track.artworkHash, size: artwork, cornerRadius: DesignSystem.Radius.medium)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    titles(track, width: textWidth)
                    ProgressBar(playback: model.playback, duration: track.duration, showsTimes: false) { model.seek(to: $0) }
                    PlaybackControls(variant: .standard, isPlaying: model.playback.isPlaying) { model.perform($0) }
                }
                .frame(width: textWidth, alignment: .leading)
            }
            if showsChart { chart }
        }
        .padding(DesignSystem.Spacing.m)
    }

    /// Copertina a tutta finestra con titolo e controlli che compaiono sopra, sul vetro.
    private func artworkOnly(_ track: Track) -> some View {
        let side = DesignSystem.Size.desktopArtwork.width
        return ZStack(alignment: .bottom) {
            ArtworkView(image: model.artwork, identity: track.artworkHash, size: side, cornerRadius: DesignSystem.Radius.panel)
            VStack(spacing: DesignSystem.Spacing.xs) {
                MarqueeText(text: track.title, font: DesignSystem.Typography.title, maxWidth: side - 4 * DesignSystem.Spacing.m)
                ProgressBar(playback: model.playback, duration: track.duration, showsTimes: false) { model.seek(to: $0) }
                PlaybackControls(variant: .standard, isPlaying: model.playback.isPlaying) { model.perform($0) }
            }
            .padding(DesignSystem.Spacing.s)
            .surfaceGlass(tint: model.tintColor(for: colorScheme), cornerRadius: DesignSystem.Radius.large)
            .padding(DesignSystem.Spacing.s)
        }
    }

    // MARK: Parti

    private func titles(_ track: Track, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            MarqueeText(text: track.title, font: DesignSystem.Typography.title, maxWidth: width)
            Text(track.artist ?? " ")
                .font(DesignSystem.Typography.subtitle)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// Top artisti Last.fm (dal profilo in cache).
    @ViewBuilder private var chart: some View {
        let artists = Array((model.scrobbler.profile?.topArtists ?? []).prefix(5))
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Top artisti su Last.fm").font(DesignSystem.Typography.sectionHeader).foregroundStyle(.secondary)
            if artists.isEmpty {
                Text(model.scrobbler.isLastFMConnected ? "Nessun dato per ora." : "Collega Last.fm nelle impostazioni.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Chart(artists) { artist in
                    BarMark(x: .value("Ascolti", artist.playCount), y: .value("Artista", artist.name))
                        .foregroundStyle(.tint)
                        .cornerRadius(DesignSystem.Radius.tiny)
                        .annotation(position: .trailing) {
                            Text("\(artist.playCount)").font(DesignSystem.Typography.time).foregroundStyle(.secondary)
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in AxisValueLabel().font(DesignSystem.Typography.caption) }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var menuItems: some View {
        @Bindable var settings = settings
        Picker("Layout", selection: $settings.desktopWidgetLayout) {
            ForEach(DesktopWidgetLayout.allCases) { Text($0.label).tag($0) }
        }
        Toggle("Grafico Last.fm", isOn: $settings.desktopWidgetShowsChart)
        Toggle("Blocca posizione e misura", isOn: $settings.desktopWidgetLocked)
        Divider()
        if model.player != nil {
            Button("Apri \(model.player?.name ?? "")") { model.openSourcePlayer() }
        }
        Button("Nascondi il widget") { settings.desktopWidgetVisible = false }
    }
}

#Preview("Widget sulla scrivania — scheda") {
    DesktopWidgetView(model: .preview())
        .frame(width: DesignSystem.Size.desktopCard.width, height: DesignSystem.Size.desktopCard.height)
        .glassEffect(in: .rect(cornerRadius: DesignSystem.Radius.panel))
        .padding()
}

#Preview("Widget sulla scrivania — orizzontale, scuro") {
    let model = AppModel.preview()
    model.settings.desktopWidgetLayout = .horizontal
    return DesktopWidgetView(model: model)
        .frame(width: DesignSystem.Size.desktopHorizontal.width, height: DesignSystem.Size.desktopHorizontal.height)
        .glassEffect(in: .rect(cornerRadius: DesignSystem.Radius.panel))
        .padding()
        .preferredColorScheme(.dark)
}

// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import SwiftUI

/// Profilo Last.fm nel popover: scrobble recenti, brani amati, top artisti del mese.
/// I dati arrivano dalla cache di `Scrobbler` (aggiornata al massimo ogni 10 minuti).
struct LastFMProfileView: View {
    let scrobbler: Scrobbler
    /// Righe per elenco.
    var limit = 5

    enum Tab: String, CaseIterable, Identifiable {
        case recent, loved, artists
        var id: String { rawValue }
        var label: String {
            switch self {
            case .recent: "Scrobble"
            case .loved: "Amati"
            case .artists: "Artisti"
            }
        }
    }

    @State private var tab: Tab = .recent

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s) {
            if let profile = scrobbler.profile {
                header(profile.user)
                Picker("Elenco", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                list(profile)
            } else {
                Text("Caricamento del profilo…")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await scrobbler.refreshProfile() }
    }

    private func header(_ user: LastFMProfile.User) -> some View {
        HStack(spacing: DesignSystem.Spacing.s) {
            AsyncImage(url: user.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle").resizable().foregroundStyle(.secondary)
            }
            .frame(width: DesignSystem.Size.historyArtwork, height: DesignSystem.Size.historyArtwork)
            .clipShape(.circle)
            VStack(alignment: .leading, spacing: 0) {
                Text(user.name).font(DesignSystem.Typography.subtitle)
                Text("\(user.playCount.formatted()) scrobble")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let url = user.url {
                Link(destination: url) { Image(systemName: "arrow.up.forward.square") }
                    .help("Apri il profilo su Last.fm")
            }
        }
    }

    @ViewBuilder private func list(_ profile: LastFMProfile) -> some View {
        switch tab {
        case .recent: tracks(profile.recent)
        case .loved: tracks(profile.loved)
        case .artists:
            ForEach(profile.topArtists.prefix(limit)) { artist in
                HStack {
                    Text(artist.name).font(DesignSystem.Typography.subtitle).lineLimit(1)
                    Spacer()
                    Text("\(artist.playCount)")
                        .font(DesignSystem.Typography.time)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private func tracks(_ entries: [LastFMProfile.TrackEntry]) -> some View {
        if entries.isEmpty {
            Text("Niente da mostrare").font(DesignSystem.Typography.caption).foregroundStyle(.secondary)
        }
        ForEach(entries.prefix(limit)) { entry in
            HStack(spacing: DesignSystem.Spacing.s) {
                AsyncImage(url: entry.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "music.note").foregroundStyle(.secondary)
                }
                .frame(width: DesignSystem.Size.historyArtwork, height: DesignSystem.Size.historyArtwork)
                .clipShape(.rect(cornerRadius: DesignSystem.Radius.tiny))
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.title).font(DesignSystem.Typography.subtitle).lineLimit(1)
                    Text(entry.artist).font(DesignSystem.Typography.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: DesignSystem.Spacing.s)
                if entry.isNowPlaying {
                    Image(systemName: "waveform").foregroundStyle(.tint).help("In riproduzione")
                } else if let date = entry.date {
                    Text(date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import SwiftUI
import WidgetKit

@main
struct OpenTunesWidgets: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
    }
}

struct NowPlayingEntry: TimelineEntry {
    var date: Date
    var state: WidgetState
    var artwork: NSImage?
}

/// Legge lo stato scritto dall'app nell'App Group. L'app ricarica i widget a ogni cambio brano;
/// in più il widget chiede di ricaricarsi alla fine del brano corrente, nel caso l'app non ci riesca.
struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: .now, state: .sample, artwork: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        let state = SharedContainer.readState()
        completion(context.isPreview && !state.hasTrack ? placeholder(in: context) : entry(state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let state = SharedContainer.readState()
        var policy: TimelineReloadPolicy = .never
        if state.isPlaying, let end = state.playbackInterval?.upperBound, end > .now {
            policy = .after(end.addingTimeInterval(2))
        }
        completion(Timeline(entries: [entry(state)], policy: policy))
    }

    private func entry(_ state: WidgetState) -> NowPlayingEntry {
        let artwork = state.artworkHash == nil ? nil : SharedContainer.readArtwork().flatMap(NSImage.init(data:))
        return NowPlayingEntry(date: .now, state: state, artwork: artwork)
    }
}

struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.nowPlaying, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("In riproduzione")
        .description("Il brano in riproduzione con i controlli. La taglia grande mostra anche Last.fm.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct NowPlayingWidgetEntryView: View {
    let entry: NowPlayingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        NowPlayingWidgetView(entry: entry, family: family)
    }
}

extension WidgetState {
    static let sample = WidgetState(
        title: "Un brano di prova", artist: "Artista di prova", album: "Album", playerName: "Musica",
        isPlaying: true, elapsedTime: 80, timestamp: .now, duration: 240, artworkHash: nil, tint: [0.2, 0.5, 0.7],
        canLove: true, isLoved: false, lastFMUser: "utente",
        recentTracks: [
            Entry(title: "Primo brano", artist: "Artista uno"), Entry(title: "Secondo brano", artist: "Artista due"),
            Entry(title: "Terzo brano", artist: "Artista tre"), Entry(title: "Quarto brano", artist: "Artista quattro"),
        ],
        topArtists: [Artist(name: "Artista uno", playCount: 420), Artist(name: "Artista due", playCount: 230)])
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MediaCore
import SwiftUI
import UniformTypeIdentifiers

/// Finestra «Scopri»: griglia dei top album di Last.fm (esportabile come PNG), artisti e brani simili
/// a quello in riproduzione.
struct DiscoverView: View {
    let model: AppModel

    enum Tab: String, CaseIterable, Identifiable {
        case topAlbums, similarArtists, similarTracks
        var id: String { rawValue }
        var label: String {
            switch self {
            case .topAlbums: String(localized: "Top album")
            case .similarArtists: String(localized: "Artisti simili")
            case .similarTracks: String(localized: "Brani simili")
            }
        }
    }

    @State private var tab: Tab = .topAlbums

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
            Picker("Sezione", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            switch tab {
            case .topAlbums: TopAlbumsView(model: model)
            case .similarArtists: SimilarView(model: model, kind: .artists)
            case .similarTracks: SimilarView(model: model, kind: .tracks)
            }
        }
        .padding(DesignSystem.Spacing.l)
        .frame(minWidth: DesignSystem.Size.discoverWindow.width, minHeight: DesignSystem.Size.discoverWindow.height)
        .tint(model.tintColor(for: .light))
    }
}

// MARK: Top album

extension LastFMPeriod {
    var label: String {
        switch self {
        case .week: String(localized: "7 giorni")
        case .month: String(localized: "1 mese")
        case .year: String(localized: "12 mesi")
        case .overall: String(localized: "Sempre")
        }
    }
}

/// Lato della griglia dei top album.
enum TopAlbumsGridSize: Int, CaseIterable, Identifiable {
    case three = 3, four = 4, five = 5
    var id: Int { rawValue }
    var label: String { "\(rawValue)×\(rawValue)" }
}

private struct TopAlbumsView: View {
    let model: AppModel
    @AppStorage("discoverPeriod") private var period: LastFMPeriod = .month
    @AppStorage("discoverGridSize") private var gridSize: TopAlbumsGridSize = .three
    @State private var albums: [LastFMAlbum] = []
    @State private var error: String?
    @State private var isLoading = false
    @State private var isExporting = false

    var body: some View {
        if !model.scrobbler.isLastFMConnected {
            ContentUnavailableView(
                "Collega Last.fm", systemImage: "person.crop.circle.badge.questionmark",
                description: Text("I top album arrivano dal tuo profilo Last.fm: collegalo in Impostazioni › Scrobbling."))
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
                HStack {
                    Picker("Periodo", selection: $period) {
                        ForEach(LastFMPeriod.allCases) { Text($0.label).tag($0) }
                    }
                    .fixedSize()
                    Picker("Griglia", selection: $gridSize) {
                        ForEach(TopAlbumsGridSize.allCases) { Text($0.label).tag($0) }
                    }
                    .fixedSize()
                    Spacer()
                    Button {
                        export()
                    } label: {
                        if isExporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Esporta PNG…", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(albums.isEmpty || isExporting)
                }
                content
            }
            .task(id: period) { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        let shown = Array(albums.prefix(gridSize.rawValue * gridSize.rawValue))
        if let error, albums.isEmpty {
            ContentUnavailableView("Top album non disponibili", systemImage: "wifi.exclamationmark", description: Text(error))
        } else if isLoading, albums.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if albums.isEmpty {
            ContentUnavailableView("Nessun ascolto nel periodo", systemImage: "square.grid.3x3")
        } else {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.s), count: gridSize.rawValue),
                    spacing: DesignSystem.Spacing.s
                ) {
                    ForEach(shown) { album in
                        AlbumCell(album: album)
                    }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            albums = try await model.scrobbler.topAlbums(period: period, limit: TopAlbumsGridSize.five.rawValue * TopAlbumsGridSize.five.rawValue)
            error = nil
        } catch {
            self.error = "\(error)"
        }
    }

    private func export() {
        let shown = Array(albums.prefix(gridSize.rawValue * gridSize.rawValue))
        let side = gridSize.rawValue
        let name = "OpenTunes top album \(period.label) \(side)x\(side).png"
        isExporting = true
        Task {
            defer { isExporting = false }
            let png = await TopAlbumsExporter.png(albums: shown, columns: side)
            guard let png else {
                error = "Esportazione non riuscita"
                return
            }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.nameFieldStringValue = name
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do { try png.write(to: url, options: .atomic) } catch { self.error = error.localizedDescription }
        }
    }
}

private struct AlbumCell: View {
    let album: LastFMAlbum

    var body: some View {
        Group {
            if let url = album.url {
                Link(destination: url) { cover }.buttonStyle(.plain)
            } else {
                cover
            }
        }
        .help("\(album.artist) — \(album.name) · \(album.playCount) ascolti")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(album.name), \(album.artist), \(album.playCount) ascolti")
    }

    private var cover: some View {
        AsyncImage(url: album.imageURL) { image in
            image.resizable().aspectRatio(1, contentMode: .fill)
        } placeholder: {
            Rectangle().fill(.quaternary)
                .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: DesignSystem.Radius.small))
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 0) {
                Text(album.name).font(DesignSystem.Typography.caption.weight(.semibold)).lineLimit(1)
                Text(album.artist).font(DesignSystem.Typography.caption).lineLimit(1)
            }
            .foregroundStyle(.white)
            .shadow(radius: 2)
            .padding(DesignSystem.Spacing.xs)
        }
    }
}

/// Griglia esportata: copertine scaricate prima e disegnate con `ImageRenderer` (niente `AsyncImage`,
/// che nel renderer non farebbe in tempo a caricarsi).
@MainActor
enum TopAlbumsExporter {
    static func png(albums: [LastFMAlbum], columns: Int) async -> Data? {
        var images: [String: NSImage] = [:]
        await withTaskGroup(of: (String, Data?).self) { group in
            for album in albums {
                guard let url = album.imageURL else { continue }
                group.addTask { (album.id, try? await URLSession.shared.data(from: url).0) }
            }
            for await (id, data) in group {
                if let data, let image = NSImage(data: data) { images[id] = image }
            }
        }
        let renderer = ImageRenderer(content: TopAlbumsGridImage(albums: albums, images: images, columns: columns))
        renderer.scale = 1
        guard let cgImage = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }
}

/// Contenuto dell'immagine esportata: quadrati senza spazi, nome dell'album in basso.
struct TopAlbumsGridImage: View {
    let albums: [LastFMAlbum]
    let images: [String: NSImage]
    let columns: Int

    var body: some View {
        let side = DesignSystem.Size.topAlbumExportCell
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<Int((Double(albums.count) / Double(max(1, columns))).rounded(.up)), id: \.self) { row in
                GridRow {
                    ForEach(albums.dropFirst(row * columns).prefix(columns)) { album in
                        ZStack(alignment: .bottomLeading) {
                            if let image = images[album.id] {
                                Image(nsImage: image).resizable().aspectRatio(1, contentMode: .fill)
                            } else {
                                Rectangle().fill(Color(white: 0.15))
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(album.name).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                                Text(album.artist).font(.system(size: 15)).lineLimit(1)
                            }
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 3)
                            .padding(DesignSystem.Spacing.s)
                        }
                        .frame(width: side, height: side)
                        .clipped()
                    }
                }
            }
        }
        .background(.black)
    }
}

// MARK: Simili

private struct SimilarView: View {
    let model: AppModel
    enum Kind { case artists, tracks }
    let kind: Kind

    @State private var items: [LastFMSimilarItem] = []
    @State private var error: String?
    @State private var isLoading = false

    private var query: String? {
        guard let track = model.track, let artist = track.artist, !artist.isEmpty else { return nil }
        return kind == .artists ? artist : "\(artist)\u{1F}\(track.title)"
    }

    var body: some View {
        Group {
            if !model.scrobbler.canDiscover {
                ContentUnavailableView(
                    "Serve una chiave Last.fm", systemImage: "key",
                    description: Text("Inserisci la tua chiave in Impostazioni › Scrobbling."))
            } else if query == nil {
                ContentUnavailableView("Niente in riproduzione", systemImage: "music.note",
                    description: Text("I suggerimenti partono dal brano in riproduzione."))
            } else if let error, items.isEmpty {
                ContentUnavailableView("Suggerimenti non disponibili", systemImage: "wifi.exclamationmark", description: Text(error))
            } else if isLoading, items.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                ContentUnavailableView("Nessun suggerimento", systemImage: "sparkles")
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s) {
                    Text(header)
                        .font(DesignSystem.Typography.sectionHeader)
                        .foregroundStyle(.secondary)
                    List(items) { item in
                        row(item)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .task(id: query) { await load() }
    }

    private var header: String {
        switch kind {
        case .artists: String(localized: "Simili a \(model.track?.artist ?? "")")
        case .tracks: String(localized: "Simili a «\(model.track?.title ?? "")»")
        }
    }

    private func row(_ item: LastFMSimilarItem) -> some View {
        HStack(spacing: DesignSystem.Spacing.m) {
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name).font(DesignSystem.Typography.body).lineLimit(1)
                if let artist = item.artist {
                    Text(artist).font(DesignSystem.Typography.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Gauge(value: item.match) { Text("Somiglianza") }
                .gaugeStyle(.accessoryLinearCapacity)
                .frame(width: DesignSystem.Size.control * 2)
                .accessibilityValue(Text(item.match, format: .percent.precision(.fractionLength(0))))
            if let url = item.url {
                Link(destination: url) { Image(systemName: "arrow.up.forward.square") }
                    .help("Apri su Last.fm")
                    .accessibilityLabel("Apri \(item.name) su Last.fm")
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
    }

    private func load() async {
        guard let track = model.track, let artist = track.artist, !artist.isEmpty, model.scrobbler.canDiscover else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = switch kind {
            case .artists: try await model.scrobbler.similarArtists(to: artist)
            case .tracks: try await model.scrobbler.similarTracks(artist: artist, title: track.title)
            }
            error = nil
        } catch {
            items = []
            self.error = "\(error)"
        }
    }
}

#Preview("Griglia esportata") {
    TopAlbumsGridImage(
        albums: (0..<9).map { LastFMAlbum(name: "Album \($0)", artist: "Artista \($0)", playCount: 10 - $0) },
        images: [:], columns: 3)
        .scaleEffect(0.5)
        .frame(width: 450, height: 450)
}

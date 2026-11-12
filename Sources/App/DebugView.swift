// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import SwiftUI

/// Finestra di debug della fase 0: mostra lo stato di `NowPlayingStore` in tempo reale.
struct DebugView: View {
    let store: NowPlayingStore
    @State private var permissions: [String: AutomationPermission] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            nowPlaying
            controls
            Divider()
            sourceInfo
            Divider()
            eventLog
        }
        .padding()
        .frame(minWidth: 480, minHeight: 560)
        .task { await refreshPermissions() }
    }

    private var nowPlaying: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let image = store.track?.artwork {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "music.note").font(.system(size: 48)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 140, height: 140)
            .background(.quaternary)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.track?.title ?? "Niente in riproduzione").font(.title2.bold()).lineLimit(2)
                Text(store.track?.artist ?? "—").font(.title3)
                Text(store.track?.album ?? "—").foregroundStyle(.secondary)
                if let player = store.player {
                    Text("\(player.name) · \(player.bundleID)").font(.caption).foregroundStyle(.secondary)
                }
                Text(store.playback.isPlaying ? "▶︎ in riproduzione" : "❚❚ in pausa").font(.caption)
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let duration = store.track?.duration
                    let position = store.playback.position(at: context.date, duration: duration)
                    VStack(alignment: .leading) {
                        ProgressView(value: position, total: max(duration ?? 1, position, 1))
                        Text("\(Self.format(position)) / \(duration.map(Self.format) ?? "--:--")")
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack {
            Button { Task { await store.send(.previousTrack) } } label: { Label("Precedente", systemImage: "backward.fill") }
            Button { Task { await store.send(.togglePlayPause) } } label: { Label("Play/Pausa", systemImage: "playpause.fill") }
            Button { Task { await store.send(.nextTrack) } } label: { Label("Successivo", systemImage: "forward.fill") }
        }
        .labelStyle(.titleAndIcon)
        .disabled(store.activeSourceID == nil)
    }

    private var sourceInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sorgente attiva: \(store.activeSourceID ?? (store.exhausted ? "nessuna" : "…"))").bold()
            ForEach(AppleScriptPlayer.allSupported, id: \.bundleID) { player in
                HStack {
                    Text("Automazione \(player.displayName): \(permissions[player.bundleID]?.description ?? "…")")
                    Spacer()
                    Button("Richiedi permesso") {
                        Task {
                            permissions[player.bundleID] = await AutomationPermission.request(for: player.bundleID)
                        }
                    }
                }
                .font(.callout)
            }
            HStack {
                Button("Aggiorna stato permessi") { Task { await refreshPermissions() } }
                Button("Apri Impostazioni › Automazione") { AutomationPermission.openSystemSettings() }
            }
            .font(.callout)
            Text("I permessi servono solo se il Now Playing di sistema non è disponibile e l'app usa AppleScript.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var eventLog: some View {
        VStack(alignment: .leading) {
            Text("Eventi").bold()
            ScrollViewReader { proxy in
                List(store.events) { event in
                    Text("\(event.date.formatted(date: .omitted, time: .standard))  [\(event.sourceID)]  \(event.message)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .id(event.id)
                }
                .onChange(of: store.events.last?.id) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    private func refreshPermissions() async {
        for player in AppleScriptPlayer.allSupported {
            permissions[player.bundleID] = await AutomationPermission.status(for: player.bundleID)
        }
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

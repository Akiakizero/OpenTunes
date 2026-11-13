// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import SwiftUI

/// Testo del brano corrente: con LRC la riga in corso è evidenziata e resta al centro; senza sincronia
/// si mostra il testo semplice. Messaggi chiari se non c'è testo (nessun errore per i brani poco noti).
struct LyricsView: View {
    let model: AppModel

    var body: some View {
        Group {
            switch model.lyrics {
            case .idle, .loading:
                message("Cerco il testo…", symbol: "text.magnifyingglass")
            case .notFound:
                message("Nessun testo per questo brano", symbol: "text.page.slash")
            case .failed:
                VStack(spacing: DesignSystem.Spacing.s) {
                    message("Testo non disponibile adesso", symbol: "wifi.exclamationmark")
                    Button("Riprova") { model.loadLyrics() }
                        .controlSize(.small)
                }
            case .found(let lyrics):
                if lyrics.isSynced {
                    SyncedLyricsList(model: model, lyrics: lyrics)
                } else if lyrics.isInstrumental {
                    message("Brano strumentale", symbol: "pianokeys")
                } else {
                    ScrollView {
                        Text(lyrics.plain ?? "")
                            .font(DesignSystem.Typography.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: model.track.map(AppModel.lyricsKey)) { model.loadLyrics() }
    }

    private func message(_ text: LocalizedStringKey, symbol: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.s) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.secondary)
            Text(text)
                .font(DesignSystem.Typography.subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Righe sincronizzate: la posizione si ricalcola 4 volte al secondo solo mentre il brano suona.
private struct SyncedLyricsList: View {
    let model: AppModel
    let lyrics: Lyrics

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: !model.playback.isPlaying)) { context in
            let current = lyrics.lineIndex(at: model.playback.position(at: context.date, duration: model.track?.duration))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.s) {
                        ForEach(lyrics.lines) { line in
                            row(line, isCurrent: line.id == current, isPast: (current ?? -1) > line.id)
                                .id(line.id)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xl)
                }
                .scrollIndicators(.never)
                .onChange(of: current) { _, index in
                    guard let index else { return }
                    withAnimation(DesignSystem.Motion.artworkChange) { proxy.scrollTo(index, anchor: .center) }
                }
                .onAppear { if let current { proxy.scrollTo(current, anchor: .center) } }
            }
        }
    }

    private func row(_ line: Lyrics.Line, isCurrent: Bool, isPast: Bool) -> some View {
        Text(line.text.isEmpty ? "♪" : line.text)
            .font(isCurrent ? DesignSystem.Typography.title : DesignSystem.Typography.subtitle)
            .foregroundStyle(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(isPast ? .tertiary : .secondary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            // Un clic su una riga salta a quel punto del brano.
            .onTapGesture { model.seek(to: line.time) }
            .accessibilityAddTraits(isCurrent ? [.isSelected, .isButton] : .isButton)
            .accessibilityHint("Salta a questo punto del brano")
    }
}

#Preview("Testi") {
    let model = AppModel.preview()
    let _ = model.lyricsKey = model.track.map(AppModel.lyricsKey)
    let _ = model.lyrics = .found(Lyrics(lines: LRCParser.parse("[00:01]Prima riga\n[00:30]Seconda riga\n[01:00]Terza riga del testo\n[02:30]Ultima")))
    return LyricsView(model: model)
        .frame(width: 268, height: 268)
        .padding()
}

// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import SwiftUI

/// Pulsante love e menu delle azioni sul brano (stelle, dislike, libreria, cambio player).
/// Usato nel popover e nella finestra flottante.
struct TrackActionsView: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if model.canLove {
                Button { model.toggleLove() } label: {
                    Image(systemName: model.isLoved ? "heart.fill" : "heart")
                        .foregroundStyle(model.isLoved ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(minWidth: DesignSystem.Size.control, minHeight: DesignSystem.Size.control)
                        .contentShape(.rect)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(ControlButtonStyle())
                .help(loveHelp)
                .accessibilityLabel(model.isLoved ? "Togli il love" : "Love")
            }
            if hasMenu {
                Menu {
                    TrackActionsMenuItems(model: model)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(minWidth: DesignSystem.Size.control, minHeight: DesignSystem.Size.control)
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Azioni sul brano")
            }
        }
        .font(DesignSystem.Typography.body)
    }

    private var hasMenu: Bool {
        model.store.supportsTrackActions || !model.store.switchablePlayers.isEmpty
    }

    private var loveHelp: String {
        switch (model.scrobbler.isLastFMConnected, model.store.supportsTrackActions) {
        case (true, true) where model.settings.syncsLoveWithMusic: "Love su Last.fm e preferito in Musica"
        case (true, _): "Love su Last.fm"
        default: "Preferito in Musica"
        }
    }
}

/// Voci del menu delle azioni (anche nel menu contestuale della finestra flottante).
struct TrackActionsMenuItems: View {
    let model: AppModel

    var body: some View {
        if model.store.supportsTrackActions {
            Picker(selection: Binding(
                get: { model.musicState?.stars ?? 0 },
                set: { model.performTrackAction(.setRating($0)) }
            )) {
                Text("Nessuna").tag(0)
                ForEach(1...5, id: \.self) { stars in
                    Text(String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)).tag(stars)
                }
            } label: {
                Label("Valutazione", systemImage: "star")
            }
            Toggle(isOn: Binding(get: { model.musicState?.disliked ?? false }, set: { _ in model.toggleDislike() })) {
                Label("Non mi piace", systemImage: "hand.thumbsdown")
            }
            Button { model.addToLibrary() } label: {
                Label("Aggiungi alla libreria", systemImage: "plus.circle")
            }
        }
        if let other = model.store.switchablePlayers.first {
            Divider()
            Button { model.switchPlayer() } label: {
                Label("Passa a \(other.displayName)", systemImage: "arrow.left.arrow.right")
            }
        }
    }
}

/// Stato dello scrobbling del brano corrente ed eventuali errori, in una riga.
struct ScrobbleStatusLine: View {
    let model: AppModel

    var body: some View {
        if let error = model.actionError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } else if !model.scrobbler.activeServices.isEmpty, model.scrobbler.currentIsScrobbled {
            Label("Ascolto registrato", systemImage: "checkmark.circle")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        } else if model.scrobbler.lastFMNeedsReconnect {
            Label("Last.fm: accedi di nuovo dalle impostazioni", systemImage: "exclamationmark.triangle")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

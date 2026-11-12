// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Copertina con angoli arrotondati, placeholder e dissolvenza al cambio brano.
struct ArtworkView: View {
    let image: NSImage?
    /// Identità della copertina (es. hash): quando cambia parte la transizione.
    var identity: String?
    var size: CGFloat
    var cornerRadius: CGFloat = DesignSystem.Radius.small
    /// `false` quando sopra c'è già un simbolo (es. HUD).
    var showsPlaceholderIcon = true

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .id(identity)
                    .transition(.opacity)
            } else {
                placeholder.transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .animation(DesignSystem.Motion.artworkChange, value: identity)
        .animation(DesignSystem.Motion.artworkChange, value: image == nil)
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                if showsPlaceholderIcon {
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.4, height: size * 0.4)
                        .foregroundStyle(.secondary)
                }
            }
    }
}

#Preview("Copertina — chiaro") {
    HStack(spacing: DesignSystem.Spacing.l) {
        ArtworkView(image: PreviewData.artwork, identity: "a", size: 120, cornerRadius: DesignSystem.Radius.medium)
        ArtworkView(image: nil, size: 120, cornerRadius: DesignSystem.Radius.medium)
        ArtworkView(image: PreviewData.artwork, identity: "a", size: DesignSystem.Size.menuBarArtwork, cornerRadius: DesignSystem.Radius.tiny)
    }
    .padding(DesignSystem.Spacing.xl)
    .preferredColorScheme(.light)
}

#Preview("Copertina — scuro") {
    HStack(spacing: DesignSystem.Spacing.l) {
        ArtworkView(image: PreviewData.artwork, identity: "a", size: 120, cornerRadius: DesignSystem.Radius.medium)
        ArtworkView(image: nil, size: 120, cornerRadius: DesignSystem.Radius.medium)
    }
    .padding(DesignSystem.Spacing.xl)
    .preferredColorScheme(.dark)
}

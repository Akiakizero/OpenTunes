// SPDX-License-Identifier: GPL-3.0-or-later

import MediaCore
import Observation
import SwiftUI

/// Stati del player nel notch.
enum NotchState: Hashable, Sendable {
    /// Non si vede (la forma coincide con il notch fisico).
    case hidden
    /// Copertina a sinistra del notch, indicatore di riproduzione a destra.
    case closed
    /// Come `closed`, con il titolo a destra per qualche secondo dopo un cambio brano.
    case peek
    /// Copertina, titolo, controlli e avanzamento sotto il notch.
    case open

    /// Stato a riposo (senza mouse sopra): visibile solo mentre suona qualcosa.
    static func resting(hasTrack: Bool, isPlaying: Bool) -> NotchState {
        hasTrack && isPlaying ? .closed : .hidden
    }
}

/// Stato condiviso tra il controller (finestra, mouse) e la vista.
@Observable
@MainActor
final class NotchPresentation {
    var state: NotchState = .hidden
    var geometry: NotchGeometry
    /// Frame della forma visibile in coordinate della finestra (origine in alto a sinistra), per il mouse.
    var shapeFrame: CGRect = .zero
    @ObservationIgnored var onOpenRequest: (() -> Void)?

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }
}

/// Player nel notch. Sui Mac con notch la forma è nera come il notch fisico e ne prolunga il profilo;
/// senza notch è una capsula di vetro al centro della menu bar.
struct NotchPlayerView: View {
    let model: AppModel
    let presentation: NotchPresentation

    @Environment(\.colorScheme) private var colorScheme

    private var state: NotchState { presentation.state }
    private var geometry: NotchGeometry { presentation.geometry }
    private var notch: CGSize { geometry.notchSize }

    var body: some View {
        Group {
            if geometry.hasNotch { notchStyle } else { capsuleStyle }
        }
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { presentation.shapeFrame = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(state == .open ? DesignSystem.Motion.notchOpen : DesignSystem.Motion.notchClose, value: state)
        .animation(DesignSystem.Motion.notchOpen, value: model.track?.title)
    }

    // MARK: Notch fisico

    private var topRadius: CGFloat { state == .open ? DesignSystem.Radius.notchOpenTop : DesignSystem.Radius.notchClosedTop }
    private var bottomRadius: CGFloat { state == .open ? DesignSystem.Radius.notchOpenBottom : DesignSystem.Radius.notchClosedBottom }

    private var leftWing: CGFloat { Self.wings(for: state, notchHeight: notch.height).left }
    private var rightWing: CGFloat { Self.wings(for: state, notchHeight: notch.height).right }

    /// Larghezza delle ali ai lati del notch fisico. L'ala della copertina è quadrata (alta quanto il notch),
    /// così la copertina ha lo stesso margine sopra, sotto e verso l'esterno e non finisce sulla curva dell'angolo.
    static func wings(for state: NotchState, notchHeight: CGFloat) -> (left: CGFloat, right: CGFloat) {
        let wing = max(DesignSystem.Size.notchWing, notchHeight)
        switch state {
        case .closed: return (wing, wing)
        case .peek: return (wing, DesignSystem.Size.notchPeekWidth)
        case .hidden, .open: return (0, 0)
        }
    }

    /// Lato della copertina nel notch chiuso: il notch meno il margine sopra e sotto.
    static func closedArtworkSize(notchHeight: CGFloat) -> CGFloat {
        max(DesignSystem.Size.menuBarArtwork, notchHeight - 2 * DesignSystem.Spacing.s)
    }

    /// Spostamento orizzontale della forma (ali asimmetriche): `offset` non cambia il frame misurato,
    /// quindi anche il controller lo usa per l'area sensibile al mouse.
    static func horizontalOffset(for state: NotchState, notchHeight: CGFloat) -> CGFloat {
        let wings = wings(for: state, notchHeight: notchHeight)
        return (wings.right - wings.left) / 2
    }

    private var notchStyle: some View {
        ZStack(alignment: .top) {
            if state == .open {
                VStack(spacing: 0) {
                    Color.clear.frame(height: notch.height)
                    expanded
                        .padding(.horizontal, DesignSystem.Spacing.l)
                        .padding(.top, DesignSystem.Spacing.s)
                        .padding(.bottom, DesignSystem.Spacing.l)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            } else {
                wings
            }
        }
        .frame(width: state == .open ? DesignSystem.Size.notchExpandedWidth : notch.width + leftWing + rightWing)
        .padding(.horizontal, topRadius)
        .background(.black)
        .clipShape(NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius))
        // Le ali possono essere asimmetriche: si sposta la forma perché il centro resti sul notch fisico.
        .offset(x: Self.horizontalOffset(for: state, notchHeight: notch.height))
        .opacity(state == .hidden ? 0 : 1)
        // Sul nero il testo è sempre chiaro.
        .environment(\.colorScheme, .dark)
        .contentShape(.rect)
        .onTapGesture { if state != .open { presentation.onOpenRequest?() } }
    }

    private var wings: some View {
        HStack(spacing: 0) {
            closedArtwork
                .frame(width: leftWing)
            Spacer(minLength: notch.width)
            trailing
                .frame(width: rightWing)
        }
        .frame(height: notch.height)
        .opacity(state == .hidden ? 0 : 1)
        // Per VoiceOver il notch chiuso è un pulsante che apre il player.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("OpenTunes: \(model.track?.title ?? "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { presentation.onOpenRequest?() }
    }

    private var closedArtwork: some View {
        ArtworkView(
            image: model.artwork, identity: model.track?.artworkHash,
            size: Self.closedArtworkSize(notchHeight: notch.height),
            cornerRadius: DesignSystem.Radius.tiny)
    }

    /// A destra: l'indicatore centrato nell'ala (simmetrico alla copertina) o il titolo durante il "peek".
    @ViewBuilder private var trailing: some View {
        if state == .peek, let track = model.track {
            MarqueeText(
                text: track.title, font: DesignSystem.Typography.subtitle,
                maxWidth: DesignSystem.Size.notchPeekWidth - DesignSystem.Spacing.s - DesignSystem.Spacing.m)
                .foregroundStyle(.primary)
                .padding(.leading, DesignSystem.Spacing.s)
                .padding(.trailing, DesignSystem.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        } else {
            playingIndicator
        }
    }

    @ViewBuilder private var playingIndicator: some View {
        let color = model.tintColor(for: .dark) ?? .primary
        Group {
            if model.settings.visualizerEnabled {
                VisualizerBars(isPlaying: model.playback.isPlaying, colors: model.visualizerColors, levels: model.spectrumLevels)
                    .frame(width: DesignSystem.Size.notchVisualizer.width, height: DesignSystem.Size.notchVisualizer.height)
            } else {
                Image(systemName: "waveform")
                    .font(DesignSystem.Typography.menuBar)
                    .foregroundStyle(color)
                    .symbolEffect(.variableColor.iterative, isActive: model.playback.isPlaying)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(model.playback.isPlaying ? "In riproduzione" : "In pausa")
    }

    /// Riga del testo in corso sotto l'artista (solo con testo sincronizzato).
    @ViewBuilder private var lyricLine: some View {
        if model.settings.lyricsEnabled, model.settings.notchShowsLyrics {
            TimelineView(.animation(minimumInterval: 0.5, paused: !model.playback.isPlaying)) { context in
                if let line = model.currentLyricLine(at: context.date), !line.isEmpty {
                    Text(line)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(DesignSystem.Motion.artworkChange, value: line)
                        .accessibilityLabel("Testo: \(line)")
                }
            }
            .task(id: model.track.map(AppModel.lyricsKey)) { model.loadLyrics() }
        }
    }

    // MARK: Senza notch

    private var capsuleStyle: some View {
        Group {
            if state == .open {
                expanded
                    .padding(DesignSystem.Spacing.m)
                    .frame(width: DesignSystem.Size.notchExpandedWidth)
                    .surfaceGlass(
                        tint: model.tintColor(for: colorScheme), cornerRadius: DesignSystem.Radius.panel, theme: model.settings.theme)
                    .padding(.top, geometry.menuBarHeight + DesignSystem.Spacing.s)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack(spacing: DesignSystem.Spacing.s) {
                    closedArtwork
                    if let track = model.track {
                        MarqueeText(
                            text: track.title, font: DesignSystem.Typography.caption,
                            maxWidth: notch.width - 2 * notch.height - 2 * DesignSystem.Spacing.s)
                    }
                    Spacer(minLength: 0)
                    playingIndicator
                }
                .padding(.horizontal, DesignSystem.Spacing.s)
                .frame(width: notch.width, height: notch.height)
                .surfaceGlass(tint: model.tintColor(for: colorScheme), in: .capsule, theme: model.settings.theme)
                .padding(.top, (geometry.menuBarHeight - notch.height) / 2)
                .opacity(state == .hidden ? 0 : 1)
                .contentShape(.capsule)
                .onTapGesture { presentation.onOpenRequest?() }
            }
        }
        .tint(model.tintColor(for: colorScheme))
    }

    // MARK: Aperto

    private var expanded: some View {
        let width = DesignSystem.Size.notchExpandedWidth - DesignSystem.Size.notchExpandedArtwork - DesignSystem.Spacing.m - 2 * DesignSystem.Spacing.l
        return HStack(alignment: .top, spacing: DesignSystem.Spacing.m) {
            ArtworkView(
                image: model.artwork, identity: model.track?.artworkHash,
                size: DesignSystem.Size.notchExpandedArtwork, cornerRadius: DesignSystem.Radius.medium)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        MarqueeText(
                            text: model.track?.title ?? "", font: DesignSystem.Typography.title,
                            maxWidth: width - DesignSystem.Size.control)
                        Text(model.track?.artist ?? " ")
                            .font(DesignSystem.Typography.subtitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        lyricLine
                    }
                    Spacer(minLength: 0)
                    if model.canLove {
                        Button { model.toggleLove() } label: {
                            Image(systemName: model.isLoved ? "heart.fill" : "heart")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(ControlButtonStyle())
                        .help(model.isLoved ? "Togli il love" : "Love")
                        .accessibilityLabel(model.isLoved ? "Togli il love" : "Love")
                    }
                }
                ProgressBar(playback: model.playback, duration: model.track?.duration) { model.seek(to: $0) }
                PlaybackControls(variant: .standard, isPlaying: model.playback.isPlaying) { model.perform($0) }
                    .frame(maxWidth: .infinity)
            }
            .frame(width: width, alignment: .leading)
        }
        .tint(model.tintColor(for: geometry.hasNotch ? .dark : colorScheme))
    }
}

#Preview("Notch — stati") {
    let model = AppModel.preview()
    let geometry = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1728, height: 1117), visibleFrame: CGRect(x: 0, y: 0, width: 1728, height: 1079),
        leftArea: CGRect(x: 0, y: 1079, width: 764, height: 38), rightArea: CGRect(x: 964, y: 1079, width: 764, height: 38), safeTop: 38)
    return VStack(spacing: DesignSystem.Spacing.l) {
        ForEach([NotchState.closed, .peek, .open], id: \.self) { state in
            let presentation = NotchPresentation(geometry: geometry)
            let _ = presentation.state = state
            NotchPlayerView(model: model, presentation: presentation)
                .frame(width: geometry.panelFrame.width, height: state == .open ? 170 : 40)
        }
    }
    .padding()
    .background(.gray)
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MediaCore

/// Dati finti per le anteprime SwiftUI. La copertina è disegnata al volo: niente asset di terzi.
@MainActor
enum PreviewData {
    static let artwork: NSImage = makeArtwork(top: .systemTeal, bottom: .systemIndigo)
    static let warmArtwork: NSImage = makeArtwork(top: .systemOrange, bottom: .systemPink)

    static let playing = PlaybackState(isPlaying: true, elapsedTime: 97, timestamp: .now, shuffle: .off, repeatMode: .off)
    static let paused = PlaybackState(isPlaying: false, elapsedTime: 160, timestamp: .now)

    static let track = Track(
        title: "Un brano di prova", artist: "Artista di prova", album: "Album di prova", duration: 251,
        artworkData: artwork.tiffRepresentation, playerBundleID: "com.apple.Music")

    static let longTrack = Track(
        title: "Un titolo davvero molto lungo per vedere lo scorrimento", artist: "Artista con un nome lungo",
        album: "Album", duration: 412, artworkData: warmArtwork.tiffRepresentation, playerBundleID: "com.spotify.client")

    static func makeArtwork(top: NSColor, bottom: NSColor, side: CGFloat = 300) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -90)
            NSColor.white.withAlphaComponent(0.25).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: side * 0.3, dy: side * 0.3)).fill()
            return true
        }
    }
}

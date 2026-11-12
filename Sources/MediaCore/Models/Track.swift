// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CryptoKit

/// Un brano come lo riporta un player.
///
/// La copertina è conservata come `Data` (che è `Sendable`) insieme al suo hash; `artwork`
/// costruisce l'`NSImage` su richiesta, così il modello può attraversare gli attori.
public struct Track: Sendable, Equatable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var albumArtist: String?
    /// Durata in secondi, se nota.
    public var duration: TimeInterval?
    public var artworkData: Data?
    /// SHA-256 esadecimale di `artworkData`, per capire al volo se la copertina è cambiata.
    public private(set) var artworkHash: String?
    /// URL remoto della copertina (Spotify via AppleScript fornisce solo questo).
    public var artworkURL: URL?
    /// Bundle ID dell'app che riproduce il brano.
    public var playerBundleID: String

    public init(
        title: String,
        artist: String? = nil,
        album: String? = nil,
        albumArtist: String? = nil,
        duration: TimeInterval? = nil,
        artworkData: Data? = nil,
        artworkURL: URL? = nil,
        playerBundleID: String
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.duration = duration
        self.artworkURL = artworkURL
        self.playerBundleID = playerBundleID
        self.artworkData = nil
        setArtwork(artworkData)
    }

    public mutating func setArtwork(_ data: Data?) {
        artworkData = data
        artworkHash = data.map { Self.hash($0) }
    }

    public var artwork: NSImage? {
        artworkData.flatMap { NSImage(data: $0) }
    }

    /// Stesso brano (ignorando copertina e posizione).
    public func isSameItem(as other: Track) -> Bool {
        title == other.title && artist == other.artist && album == other.album
            && playerBundleID == other.playerBundleID
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

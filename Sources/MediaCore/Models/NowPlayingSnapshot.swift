// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Stato completo emesso da una sorgente. `track == nil` significa "niente in riproduzione".
public struct NowPlayingSnapshot: Sendable, Equatable {
    public var track: Track?
    public var playback: PlaybackState
    /// `id` della sorgente che l'ha prodotto.
    public var sourceID: String

    public init(track: Track?, playback: PlaybackState, sourceID: String) {
        self.track = track
        self.playback = playback
        self.sourceID = sourceID
    }

    public static func empty(sourceID: String) -> NowPlayingSnapshot {
        NowPlayingSnapshot(track: nil, playback: .stopped, sourceID: sourceID)
    }

    public var currentPosition: TimeInterval {
        playback.position(at: .now, duration: track?.duration)
    }
}

public enum MediaCommand: Sendable, Equatable {
    case play
    case pause
    case togglePlayPause
    case nextTrack
    case previousTrack
    case seek(to: TimeInterval)
    case setShuffle(ShuffleMode)
    case setRepeat(RepeatMode)
}

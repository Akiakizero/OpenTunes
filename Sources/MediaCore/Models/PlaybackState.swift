// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum RepeatMode: Int, Sendable, Equatable {
    case off = 1
    case one = 2
    case all = 3
}

public enum ShuffleMode: Int, Sendable, Equatable {
    case off = 1
    case albums = 2
    case tracks = 3
}

/// Stato della riproduzione.
///
/// `elapsedTime` è la posizione al momento `timestamp`: la posizione corrente si calcola
/// con `position(at:)` senza dover interrogare il player di continuo.
public struct PlaybackState: Sendable, Equatable {
    public var isPlaying: Bool
    /// Posizione in secondi letta al momento `timestamp`.
    public var elapsedTime: TimeInterval
    /// Momento in cui `elapsedTime` era valida.
    public var timestamp: Date
    /// 1.0 = velocità normale.
    public var playbackRate: Double
    public var shuffle: ShuffleMode?
    public var repeatMode: RepeatMode?

    public init(
        isPlaying: Bool = false,
        elapsedTime: TimeInterval = 0,
        timestamp: Date = .now,
        playbackRate: Double = 1,
        shuffle: ShuffleMode? = nil,
        repeatMode: RepeatMode? = nil
    ) {
        self.isPlaying = isPlaying
        self.elapsedTime = elapsedTime
        self.timestamp = timestamp
        self.playbackRate = playbackRate
        self.shuffle = shuffle
        self.repeatMode = repeatMode
    }

    public static let stopped = PlaybackState()

    /// Posizione stimata all'istante `date`, limitata a `0...duration` se la durata è nota.
    public func position(at date: Date = .now, duration: TimeInterval? = nil) -> TimeInterval {
        var value = elapsedTime
        if isPlaying {
            let delta = max(0, date.timeIntervalSince(timestamp))
            value += delta * (playbackRate > 0 ? playbackRate : 1)
        }
        value = max(0, value)
        if let duration, duration > 0 { value = min(value, duration) }
        return value
    }
}

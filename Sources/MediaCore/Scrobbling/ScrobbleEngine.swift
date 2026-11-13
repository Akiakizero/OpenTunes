// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Decide quando un brano va annunciato (`updateNowPlaying`) e quando va inviato come ascolto.
///
/// È una macchina a stati senza effetti collaterali: riceve gli snapshot del Now Playing e i "tick"
/// periodici, e restituisce gli eventi. Regole:
/// - conta solo il tempo passato in riproduzione: la pausa ferma il conteggio ma non lo azzera;
/// - un brano si invia una sola volta per sessione di ascolto;
/// - una nuova sessione inizia con un brano diverso o quando lo stesso brano riparte dall'inizio;
/// - se lo stesso brano ricompare con lo stesso orario di inizio (es. cambio di sorgente) non si reinvia.
public struct ScrobbleEngine: Sendable {
    public enum Event: Sendable, Equatable {
        case nowPlaying(ScrobbleTrack)
        case scrobble(ScrobbleTrack)
    }

    struct Session: Sendable {
        var item: Track
        var scrobble: ScrobbleTrack
        var playback: PlaybackState
        var listened: TimeInterval = 0
        var lastTick: Date
        var scrobbled = false
        var announced = false
    }

    public var rules: ScrobbleRules
    /// Un intervallo più lungo tra due aggiornamenti (es. Mac in stop) conta al massimo così.
    public static let maxTickGap: TimeInterval = 60
    /// Uno stesso brano che "riparte" entro questa distanza dall'inizio precedente è lo stesso ascolto.
    static let sameStartTolerance: TimeInterval = 30

    private(set) var session: Session?
    /// Ultimi ascolti inviati (identità e inizio), per non reinviare dopo un cambio di sorgente.
    private var recent: [(identity: String, startedAt: Date)] = []

    public init(rules: ScrobbleRules = .lastFM) {
        self.rules = rules
    }

    /// Brano della sessione in corso (già pronto per l'invio).
    public var current: ScrobbleTrack? { session?.scrobble }
    /// Secondi ascoltati nella sessione in corso.
    public var listened: TimeInterval { session?.listened ?? 0 }
    /// `true` se la sessione in corso è già stata inviata.
    public var currentIsScrobbled: Bool { session?.scrobbled ?? false }

    /// Applica un nuovo snapshot. `track == nil` (o senza artista) chiude la sessione.
    public mutating func update(track: Track?, playback: PlaybackState, at now: Date = .now) -> [Event] {
        advance(to: now)
        guard let track, let artist = track.artist?.trimmingCharacters(in: .whitespaces), !artist.isEmpty,
            !track.title.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            session = nil
            return []
        }
        let position = playback.position(at: now, duration: track.duration)
        var events: [Event] = []
        if var current = session, current.item.isSameItem(as: track), !restarted(current, position: position, at: now) {
            let wasPlaying = current.playback.isPlaying
            current.playback = playback
            current.item = track
            if current.scrobble.duration == nil, let duration = track.duration, duration > 0 {
                current.scrobble.duration = duration
            }
            // Riprende dopo una pausa: l'annuncio "in riproduzione" di Last.fm scade, va ripetuto.
            if playback.isPlaying, !wasPlaying { current.announced = false }
            session = current
        } else {
            startSession(track: track, artist: artist, playback: playback, position: position, at: now)
        }
        if let current = session, current.playback.isPlaying, !current.announced {
            session?.announced = true
            events.append(.nowPlaying(current.scrobble))
        }
        events += checkThreshold()
        return events
    }

    /// Avanza il tempo senza snapshot nuovi: va chiamata periodicamente mentre si ascolta.
    public mutating func tick(at now: Date = .now) -> [Event] {
        advance(to: now)
        return checkThreshold()
    }

    /// Secondi che mancano all'invio, se la sessione sta suonando e non è ancora stata inviata.
    public func timeUntilScrobble() -> TimeInterval? {
        guard let session, session.playback.isPlaying, !session.scrobbled,
            let threshold = rules.threshold(duration: session.scrobble.duration)
        else { return nil }
        return max(0, threshold - session.listened)
    }

    // MARK: Interni

    private mutating func advance(to now: Date) {
        guard var current = session else { return }
        if current.playback.isPlaying {
            let delta = now.timeIntervalSince(current.lastTick)
            if delta > 0 { current.listened += min(delta, Self.maxTickGap) }
        }
        current.lastTick = max(current.lastTick, now)
        session = current
    }

    /// Lo stesso brano è ripartito dall'inizio (ripeti brano o ritorno all'inizio).
    private func restarted(_ session: Session, position: TimeInterval, at now: Date) -> Bool {
        let expected = session.playback.position(at: now, duration: session.scrobble.duration)
        return position < 10 && expected - position > 30
    }

    private mutating func startSession(track: Track, artist: String, playback: PlaybackState, position: TimeInterval, at now: Date) {
        let startedAt = now.addingTimeInterval(-position)
        let scrobble = ScrobbleTrack(
            artist: artist, title: track.title, album: track.album.flatMap { $0.isEmpty ? nil : $0 },
            albumArtist: track.albumArtist.flatMap { $0.isEmpty ? nil : $0 },
            duration: (track.duration ?? 0) > 0 ? track.duration : nil,
            startedAt: startedAt, playerBundleID: track.playerBundleID)
        var new = Session(item: track, scrobble: scrobble, playback: playback, lastTick: now)
        new.scrobbled = recent.contains {
            $0.identity == scrobble.identity && abs($0.startedAt.timeIntervalSince(startedAt)) < Self.sameStartTolerance
        }
        session = new
    }

    private mutating func checkThreshold() -> [Event] {
        guard var current = session, !current.scrobbled,
            let threshold = rules.threshold(duration: current.scrobble.duration),
            current.listened >= threshold
        else { return [] }
        current.scrobbled = true
        session = current
        recent.append((current.scrobble.identity, current.scrobble.startedAt))
        if recent.count > 20 { recent.removeFirst(recent.count - 20) }
        return [.scrobble(current.scrobble)]
    }
}

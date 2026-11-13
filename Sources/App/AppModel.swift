// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreAudio
import MediaCore
import Observation
import os
import SwiftData
import SwiftUI

/// Stato condiviso dalle superfici: lo store del Now Playing, le preferenze e i dati derivati
/// (copertina decodificata, tinta, volume). Le superfici leggono da qui e inviano azioni qui.
@Observable
@MainActor
final class AppModel {
    let store: NowPlayingStore
    let settings: AppSettings
    let scrobbler: Scrobbler
    /// Portachiavi (o memoria per anteprime e test).
    @ObservationIgnored let secrets: any SecretStore
    @ObservationIgnored private let history: TrackHistory?

    /// Copertina del brano corrente, decodificata una volta sola per hash.
    private(set) var artwork: NSImage?
    /// Tinta estratta dalla copertina (`nil` se disattivata o senza copertina).
    private(set) var tint: AccentTint?
    /// Colori principali della copertina per il visualizer (vuoto se la tinta è spenta o non c'è copertina).
    private(set) var palette: [RGB] = []
    /// Ultimo volume di sistema noto (0…1).
    var volume: Float?
    /// Preferito, dislike e stelle del brano corrente in Musica (`nil` = non disponibile).
    private(set) var musicState: MusicTrackState?
    /// Ultimo errore di un'azione sul brano, mostrato sotto i pulsanti.
    var actionError: String?
    /// Secret della chiave personale Last.fm (copia in memoria di quella nel Portachiavi).
    private(set) var customLastFMSecret: String
    /// Testo del brano corrente (caricato solo quando una superficie lo mostra).
    /// Scritti anche da `AppModel+Extras.swift` (per questo non sono `private(set)`).
    var lyrics: LyricsState = .idle
    /// Volume interno del player (Musica, Spotify), `nil` se non disponibile.
    var playerVolume: Double?
    /// Dispositivi di uscita audio e quello in uso.
    var outputDevices: [AudioOutputDevice] = []
    var currentOutputID: AudioDeviceID?
    /// Link universale in preparazione (per mostrare l'attesa nei pulsanti).
    var isPreparingShareLink = false
    /// La finestra flottante grande mostra il testo al posto della copertina.
    var floatingShowsLyrics = false

    /// Stato del testo del brano corrente.
    enum LyricsState: Equatable {
        case idle
        case loading
        case found(Lyrics)
        case notFound
        case failed(String)

        var lyrics: Lyrics? {
            if case .found(let lyrics) = self { lyrics } else { nil }
        }
    }

    /// Eventi per HUD e notifiche.
    enum Event {
        case trackChanged
        case playPauseToggled(isPlaying: Bool)
        case skipped(forward: Bool)
        case volumeChanged(Float)
        /// Esito di un'azione sul brano chiesta da una scorciatoia (l'HUD dà il riscontro).
        case trackAction(title: String, symbol: String)
    }

    @ObservationIgnored var onEvent: ((Event) -> Void)?
    /// Apre la finestra «Scopri» (top album e simili da Last.fm); collegata da `AppDelegate`.
    @ObservationIgnored var onOpenDiscover: (() -> Void)?
    /// Aggiornamenti automatici (solo nell'app reale: anteprime e test non avviano Sparkle).
    @ObservationIgnored var updater: Updater?
    /// Discord Rich Presence e controllo MIDI (solo nell'app reale; per le impostazioni).
    @ObservationIgnored var discord: DiscordController?
    @ObservationIgnored var midi: MIDIControl?
    /// Apre la finestra delle statistiche locali; collegata da `AppDelegate`.
    @ObservationIgnored var onOpenStatistics: (() -> Void)?
    /// Spettro reale dell'audio di sistema per il visualizer (acceso solo quando serve).
    @ObservationIgnored let spectrum = AudioSpectrum()
    @ObservationIgnored var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var artworkHash: String?
    /// Brano per cui è stato chiesto il testo (evita richieste ripetute).
    @ObservationIgnored var lyricsKey: String?
    @ObservationIgnored let lyricsService: LyricsService
    @ObservationIgnored let shareLinks: ShareLinkService

    /// Senza `storage` il database è in memoria e i segreti non toccano il Portachiavi: per anteprime e test.
    init(
        store: NowPlayingStore = NowPlayingStore(), settings: AppSettings = AppSettings(),
        storage: ModelContainer? = nil, secrets: any SecretStore = MemorySecretStore(),
        lyricsService: LyricsService = LyricsService(cacheDirectory: nil), shareLinks: ShareLinkService = ShareLinkService()
    ) {
        self.store = store
        self.lyricsService = lyricsService
        self.shareLinks = shareLinks
        self.settings = settings
        self.secrets = secrets
        let container: ModelContainer
        do {
            container = try storage ?? Storage.makeContainer(inMemory: true)
        } catch {
            // Un database in memoria non può fallire se lo schema è valido: è un errore di programmazione.
            fatalError("Database in memoria non disponibile: \(error)")
        }
        history = storage.map { TrackHistory(modelContainer: $0) }
        customLastFMSecret = secrets.secret(for: SecretAccount.lastFMCustomSecret) ?? ""
        scrobbler = Scrobbler(
            store: store, queue: ScrobbleQueue(modelContainer: container), secrets: secrets,
            profileCacheURL: storage == nil ? nil : Scrobbler.defaultProfileCacheURL)
    }

    /// Modello dell'app reale: database su disco e Portachiavi.
    static func live() -> AppModel {
        do {
            return AppModel(
                storage: try Storage.makeContainer(), secrets: KeychainStore(), lyricsService: .shared, shareLinks: .shared)
        } catch {
            Logger(subsystem: "org.opentunes.OpenTunes", category: "AppModel")
                .error("database non disponibile, uso la memoria: \(error, privacy: .public)")
            return AppModel(secrets: KeychainStore(), lyricsService: .shared, shareLinks: .shared)
        }
    }

    var track: Track? { store.track }
    var playback: PlaybackState { store.playback }
    var player: PlayerApp? { store.player }
    var hasTrack: Bool { store.track != nil }

    /// Statistiche locali dalla cronologia (`period` = ultimi N secondi, `nil` = tutto). `nil` senza database.
    func statistics(period: TimeInterval?) async -> ListeningStats? {
        guard settings.statisticsEnabled, let history else { return nil }
        let plays = await history.plays(since: Date.now.addingTimeInterval(-(period ?? 3_650 * 86_400)))
        return ListeningStats(plays: plays, period: period)
    }

    /// Testo per la menu bar secondo il formato scelto.
    var menuBarTitle: String? {
        guard let track else { return nil }
        return settings.titleFormat.render(title: track.title, artist: track.artist, album: track.album)
    }

    func start() {
        applyStoreSettings()
        applyScrobblerSettings()
        store.startDefault()
        if let history { Task { await store.attachHistory(history) } }
        scrobbler.start()
        startDerivedState()
        tasks.append(observeChanges({ [weak self] in self?.scrobblerConfiguration }) { [weak self] _ in
            self?.applyScrobblerSettings()
        })
        tasks.append(observeChanges({ [store] in store.track?.playerBundleID }) { [weak self] bundleID in
            guard let self, let bundleID, !bundleID.isEmpty, !settings.seenPlayerBundleIDs.contains(bundleID) else { return }
            settings.seenPlayerBundleIDs.append(bundleID)
        })
        tasks.append(observeChanges({ [store] in store.track.map { "\($0.playerBundleID)\u{1F}\($0.artist ?? "")\u{1F}\($0.title)" } }) {
            [weak self] _ in
            self?.actionError = nil
            self?.refreshMusicState()
            self?.refreshPlayerVolume()
        })
        startSystemObservers()
    }

    /// Avvia gli osservatori che tengono aggiornati copertina, tinta, volume ed eventi.
    func startDerivedState() {
        volume = SystemVolume.current
        tasks.append(observeChanges({ [store] in store.track.map(Self.lyricsKey) }) { [weak self] key in
            // Cambio brano: il testo vecchio non vale più. Le viste che lo mostrano lo richiedono con `loadLyrics()`.
            guard let self, key != lyricsKey else { return }
            lyricsKey = nil
            lyrics = .idle
        })
        tasks.append(observeChanges({ [store] in store.track?.artworkHash }) { [weak self] _ in
            self?.updateArtwork()
        })
        tasks.append(observeChanges({ [settings] in settings.tintsWithArtwork }) { [weak self] _ in
            self?.updateArtwork(force: true)
        })
        tasks.append(observeChanges({ [store] in store.trackChangeCount }) { [weak self] count in
            // Il primo brano dopo l'avvio non è un "cambio": niente HUD né notifica.
            if count > 1 { self?.onEvent?(.trackChanged) }
        })
        tasks.append(observeChanges({ [settings] in
            [settings.ignoredBundleIDs.joined(separator: ","), "\(settings.normalizesBrowserTitles)", "\(settings.looksUpMissingArtwork)"]
        }) { [weak self] _ in
            self?.applyStoreSettings()
        })
    }

    private func applyStoreSettings() {
        store.ignoredBundleIDs = Set(settings.ignoredBundleIDs)
        store.normalizesBrowserTitles = settings.normalizesBrowserTitles
        store.looksUpMissingArtwork = settings.looksUpMissingArtwork
    }

    // MARK: Scrobbling

    /// Chiave Last.fm in uso: quella personale se scelta e completa, altrimenti quella del progetto.
    var lastFMCredentials: LastFMCredentials? {
        if settings.lastFMUsesCustomKey {
            let custom = LastFMCredentials(
                apiKey: settings.lastFMCustomAPIKey.trimmingCharacters(in: .whitespaces),
                secret: customLastFMSecret.trimmingCharacters(in: .whitespaces))
            return custom.isValid ? custom : nil
        }
        return LastFMCredentials.bundled()
    }

    var scrobblerConfiguration: Scrobbler.Configuration {
        Scrobbler.Configuration(
            rules: settings.scrobbleRules, cleaner: settings.cleanerOptions,
            lastFMEnabled: settings.lastFMEnabled, listenBrainzEnabled: settings.listenBrainzEnabled,
            excludedBundleIDs: Set(settings.scrobbleExcludedBundleIDs), credentials: lastFMCredentials,
            listenBrainzServer: ListenBrainzClient.serverURL(from: settings.listenBrainzServer))
    }

    private func applyScrobblerSettings() {
        scrobbler.configuration = scrobblerConfiguration
    }

    func setCustomLastFMSecret(_ secret: String) {
        let value = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try secrets.setSecret(value, for: SecretAccount.lastFMCustomSecret)
            customLastFMSecret = value
        } catch {
            actionError = String(localized: "Portachiavi: \(String(describing: error))")
        }
    }

    // MARK: Love e azioni sul brano

    /// Love su Last.fm se collegato, altrimenti il preferito di Musica.
    var isLoved: Bool {
        if scrobbler.isLastFMConnected, let loved = scrobbler.currentIsLoved { return loved }
        return musicState?.favorited ?? false
    }

    /// Il pulsante love fa qualcosa: Last.fm collegato o brano di Musica.
    var canLove: Bool {
        guard settings.loveEnabled, let track else { return false }
        return (scrobbler.isLastFMConnected && track.artist?.isEmpty == false) || store.supportsTrackActions
    }

    /// Love/unlove: Last.fm e, se attivo il collegamento, anche il preferito di Musica.
    func toggleLove(feedback: Bool = false) {
        guard canLove else { return }
        let loved = !isLoved
        let title = track?.title ?? ""
        Task {
            var failure: String?
            if scrobbler.isLastFMConnected {
                do { try await scrobbler.setLoved(loved) } catch { failure = "Last.fm: \(error)" }
            }
            if store.supportsTrackActions, settings.syncsLoveWithMusic || !scrobbler.isLastFMConnected {
                do {
                    try await store.perform(.setFavorite(loved))
                } catch {
                    failure = failure ?? "Musica: \(error)"
                }
                refreshMusicState()
            }
            actionError = failure
            if feedback, failure == nil {
                onEvent?(.trackAction(title: title, symbol: loved ? "heart.fill" : "heart.slash"))
            }
        }
    }

    /// Stelle (0…5), dislike e libreria: solo Musica.
    func performTrackAction(_ action: TrackAction, feedback: Bool = false) {
        guard settings.musicActionsEnabled, store.supportsTrackActions else { return }
        let title = track?.title ?? ""
        Task {
            do {
                try await store.perform(action)
                actionError = nil
                if feedback { onEvent?(.trackAction(title: title, symbol: Self.symbol(for: action))) }
            } catch {
                actionError = "Musica: \(error)"
            }
            refreshMusicState()
        }
    }

    func toggleDislike() {
        performTrackAction(.setDisliked(!(musicState?.disliked ?? false)))
    }

    func addToLibrary(feedback: Bool = false) {
        performTrackAction(.addToLibrary, feedback: feedback)
    }

    /// Passa al prossimo player in esecuzione (Musica ↔ Spotify).
    func switchPlayer() {
        guard settings.switchPlayerEnabled else { return }
        Task {
            if let player = await store.switchPlayer() {
                onEvent?(.trackAction(title: player.displayName, symbol: "arrow.left.arrow.right"))
            }
        }
    }

    func refreshMusicState() {
        guard store.supportsTrackActions else {
            musicState = nil
            return
        }
        Task { musicState = await store.trackState() }
    }

    private static func symbol(for action: TrackAction) -> String {
        switch action {
        case .setFavorite(let on): on ? "star.fill" : "star.slash"
        case .setDisliked(let on): on ? "hand.thumbsdown.fill" : "hand.thumbsdown"
        case .setRating: "star.fill"
        case .addToLibrary: "plus.circle.fill"
        }
    }

    func updateArtwork(force: Bool = false) {
        let hash = store.track?.artworkHash
        guard force || hash != artworkHash else { return }
        artworkHash = hash
        artwork = store.track?.artwork
        tint = settings.tintsWithArtwork ? artwork.flatMap(AccentTint.from) : nil
        palette = settings.tintsWithArtwork ? artwork.map { AccentTint.palette(of: $0) } ?? [] : []
    }

    /// Colore della tinta per lo schema indicato.
    func tintColor(for scheme: ColorScheme) -> Color? {
        if settings.theme == .custom, let accent = CustomTheme.active.accentColor { return accent }
        return tint?.color(for: scheme)
    }

    // MARK: Azioni

    func perform(_ action: PlaybackAction) {
        let playback = store.playback
        switch action {
        case .previous:
            send(.previousTrack)
            onEvent?(.skipped(forward: false))
        case .next:
            send(.nextTrack)
            onEvent?(.skipped(forward: true))
        case .playPause:
            send(.togglePlayPause)
            onEvent?(.playPauseToggled(isPlaying: !playback.isPlaying))
        case .toggleShuffle:
            let on = (playback.shuffle ?? .off) != .off
            send(.setShuffle(on ? .off : .tracks))
        case .cycleRepeat:
            send(.setRepeat((playback.repeatMode ?? .off).next))
        }
    }

    func seek(to seconds: TimeInterval) {
        send(.seek(to: seconds))
    }

    /// Salta di `delta` secondi rispetto alla posizione corrente.
    func seek(by delta: TimeInterval) {
        guard let duration = track?.duration else { return }
        let target = max(0, min(duration, playback.position(duration: duration) + delta))
        seek(to: target)
    }

    func changeVolume(by delta: Float) {
        guard let value = SystemVolume.change(by: delta) else { return }
        volume = value
        onEvent?(.volumeChanged(value))
    }

    func setVolume(_ value: Float) {
        volume = SystemVolume.set(value) ?? volume
    }

    func refreshVolume() {
        volume = SystemVolume.current
    }

    /// Mostra o nasconde la finestra flottante; non fa niente se l'utente l'ha disattivata.
    func toggleFloatingWindow() {
        guard settings.floatingEnabled else { return }
        settings.floatingVisible.toggle()
    }

    /// Porta in primo piano il player che sta suonando.
    func openSourcePlayer() {
        guard let bundleID = track?.playerBundleID, !bundleID.isEmpty else { return }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            running.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Chiede il permesso Automazione per i player installati (solo su azione dell'utente).
    func requestAutomationPermission() {
        Task {
            for player in AppleScriptPlayer.allSupported
            where NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) != nil {
                _ = await AutomationPermission.request(for: player.bundleID)
            }
        }
    }

    /// Comando diretto al player (play, pausa esplicite dai comandi URL).
    func send(_ command: MediaCommand) {
        Task { await store.send(command) }
    }
}

/// Esegue `onChange` con il valore iniziale e a ogni sua modifica (deduplicando i valori uguali).
@MainActor
func observeChanges<T: Equatable & Sendable>(
    _ value: @escaping @MainActor @Sendable () -> T,
    onChange: @escaping @MainActor (T) -> Void
) -> Task<Void, Never> {
    Task { @MainActor in
        var last: T?
        for await current in Observations(value) {
            if current != last {
                last = current
                onChange(current)
            }
        }
    }
}

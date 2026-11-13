// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network
import Observation

/// Collega il Now Playing ai servizi di scrobbling.
///
/// Legge gli snapshot di `NowPlayingStore`, li passa a `ScrobbleEngine`, pulisce i titoli con
/// `TitleCleaner`, salva gli ascolti nella `ScrobbleQueue` e li invia a Last.fm e ListenBrainz a blocchi,
/// con nuovi tentativi ad attesa crescente. Gestisce anche accesso, love e profilo Last.fm.
@Observable
@MainActor
public final class Scrobbler {
    public struct Configuration: Sendable, Equatable {
        public var rules: ScrobbleRules
        public var cleaner: TitleCleaner.Options
        public var lastFMEnabled: Bool
        public var listenBrainzEnabled: Bool
        /// Player che non fanno scrobbling (per default i browser).
        public var excludedBundleIDs: Set<String>
        /// Chiave dell'app (personale o del progetto); `nil` = Last.fm non configurabile.
        public var credentials: LastFMCredentials?
        /// Server compatibile con ListenBrainz (istanza propria, Maloja); `nil` = listenbrainz.org.
        public var listenBrainzServer: URL?

        public init(
            rules: ScrobbleRules = .lastFM, cleaner: TitleCleaner.Options = .init(), lastFMEnabled: Bool = true,
            listenBrainzEnabled: Bool = true, excludedBundleIDs: Set<String> = PlayerApp.browserBundleIDs,
            credentials: LastFMCredentials? = nil, listenBrainzServer: URL? = nil
        ) {
            self.listenBrainzServer = listenBrainzServer
            self.rules = rules
            self.cleaner = cleaner
            self.lastFMEnabled = lastFMEnabled
            self.listenBrainzEnabled = listenBrainzEnabled
            self.excludedBundleIDs = excludedBundleIDs
            self.credentials = credentials
        }
    }

    public enum AuthState: Sendable, Equatable {
        case idle
        /// Token creato: l'utente deve approvarlo nella pagina di Last.fm.
        case waitingForApproval(URL)
        case failed(String)
    }

    public var configuration: Configuration {
        didSet {
            guard configuration != oldValue else { return }
            engine.rules = configuration.rules
            Task { await refreshPendingCount() }
            requestFlush()
        }
    }

    public private(set) var lastFMUser: String?
    public private(set) var listenBrainzUser: String?
    public private(set) var lastFMAuth: AuthState = .idle
    /// Ascolti in coda per i servizi attivi (mostrati come indicatore in menu bar).
    public private(set) var pendingCount = 0
    /// Ultimo ascolto registrato (già pulito).
    public private(set) var lastScrobble: ScrobbleTrack?
    /// `true` se il brano in corso è già stato registrato.
    public private(set) var currentIsScrobbled = false
    /// Love su Last.fm del brano corrente (`nil` = sconosciuto o non collegato).
    public private(set) var currentIsLoved: Bool?
    public private(set) var profile: LastFMProfile?
    public private(set) var lastError: String?
    /// La sessione Last.fm è stata revocata: serve un nuovo accesso.
    public private(set) var lastFMNeedsReconnect = false

    public var isLastFMConnected: Bool { lastFMUser != nil && configuration.credentials != nil }
    public var isListenBrainzConnected: Bool { listenBrainzUser != nil }

    /// Servizi a cui inviare adesso: attivi e collegati.
    public var activeServices: Set<ScrobbleServiceKind> {
        var services: Set<ScrobbleServiceKind> = []
        if configuration.lastFMEnabled, isLastFMConnected, !lastFMNeedsReconnect { services.insert(.lastFM) }
        if configuration.listenBrainzEnabled, isListenBrainzConnected { services.insert(.listenBrainz) }
        return services
    }

    @ObservationIgnored private let store: NowPlayingStore
    @ObservationIgnored private let queue: ScrobbleQueue
    @ObservationIgnored private let secrets: any SecretStore
    @ObservationIgnored private let transport: HTTPTransport
    @ObservationIgnored private let profileCacheURL: URL?
    @ObservationIgnored private var engine: ScrobbleEngine
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var flushSignal: AsyncStream<Void>.Continuation?
    @ObservationIgnored private var authTask: Task<Void, Never>?
    @ObservationIgnored private var lovedKey: String?
    @ObservationIgnored private var isFlushing = false
    /// Copie in memoria dei segreti: il Portachiavi si legge una volta sola all'avvio.
    @ObservationIgnored private var lastFMSessionKey: String?
    @ObservationIgnored private var listenBrainzToken: String?

    /// Il profilo in cache vale per 10 minuti: così non si chiama l'API a ogni apertura del popover.
    public static let profileMaxAge: TimeInterval = 600

    public init(
        store: NowPlayingStore, queue: ScrobbleQueue, secrets: any SecretStore = KeychainStore(),
        configuration: Configuration = Configuration(), transport: @escaping HTTPTransport = HTTP.live,
        profileCacheURL: URL? = nil
    ) {
        self.store = store
        self.queue = queue
        self.secrets = secrets
        self.configuration = configuration
        self.transport = transport
        self.profileCacheURL = profileCacheURL
        engine = ScrobbleEngine(rules: configuration.rules)
        lastFMSessionKey = secrets.secret(for: SecretAccount.lastFMSession)
        lastFMUser = lastFMSessionKey != nil ? secrets.secret(for: SecretAccount.lastFMUser) : nil
        listenBrainzToken = secrets.secret(for: SecretAccount.listenBrainzToken)
        listenBrainzUser = listenBrainzToken != nil ? secrets.secret(for: SecretAccount.listenBrainzUser) : nil
        profile = Self.loadProfile(from: profileCacheURL)
    }

    /// Cartella della cache del profilo: `~/Library/Caches/OpenTunes/lastfm-profile.json`.
    public static var defaultProfileCacheURL: URL {
        URL.cachesDirectory.appending(path: "OpenTunes", directoryHint: .isDirectory).appending(path: "lastfm-profile.json")
    }

    // MARK: Ciclo di vita

    public func start() {
        stop()
        let (signals, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        flushSignal = signal

        // Snapshot del Now Playing → motore.
        tasks.append(Task { [weak self, store] in
            for await snapshot in observations({ store.snapshot }) {
                self?.observe(snapshot)
            }
        })
        // Tick: il tempo di ascolto avanza anche senza snapshot nuovi.
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                let wait = self?.engine.timeUntilScrobble().map { min(max($0, 1), 15) } ?? 15
                try? await Task.sleep(for: .seconds(wait))
                guard let self else { return }
                self.handle(self.engine.tick())
            }
        })
        // Invio della coda: su richiesta e quando scade il prossimo tentativo.
        tasks.append(Task { [weak self] in
            signal.yield()
            for await _ in signals {
                await self?.flush()
            }
        })
        tasks.append(Task { [weak self, queue] in
            while !Task.isCancelled {
                let next = (try? await queue.nextAttempt()) ?? .distantFuture
                let wait = min(max(next.timeIntervalSinceNow, 5), 300)
                try? await Task.sleep(for: .seconds(wait))
                self?.requestFlush()
            }
        })
        // Quando la rete torna si ritenta subito.
        tasks.append(Task { [weak self, queue] in
            var wasSatisfied = true
            for await path in NWPathMonitor() {
                let satisfied = path.status == .satisfied
                if satisfied, !wasSatisfied {
                    try? await queue.retryNow()
                    self?.log("rete tornata disponibile: riprovo la coda")
                    self?.requestFlush()
                }
                wasSatisfied = satisfied
            }
        })
        Task { try? await queue.purge() }
    }

    public func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        flushSignal?.finish()
        flushSignal = nil
    }

    public func requestFlush() {
        flushSignal?.yield()
    }

    /// Ritenta subito tutta la coda, ignorando l'attesa crescente (azione dell'utente).
    public func retryNow() {
        Task {
            try? await queue.retryNow()
            requestFlush()
        }
    }

    // MARK: Motore

    private func observe(_ snapshot: NowPlayingSnapshot?) {
        var track = snapshot?.track
        if let bundleID = track?.playerBundleID, configuration.excludedBundleIDs.contains(bundleID) { track = nil }
        let previous = engine.current
        handle(engine.update(track: track, playback: snapshot?.playback ?? .stopped))
        if engine.current?.identity != previous?.identity || engine.current?.startedAt != previous?.startedAt {
            currentIsScrobbled = engine.currentIsScrobbled
        }
        let key = store.track.map { "\($0.artist ?? "")\u{1F}\($0.title)" }
        if key != lovedKey {
            lovedKey = key
            currentIsLoved = nil
            refreshLoved()
        }
    }

    func handle(_ events: [ScrobbleEngine.Event]) {
        for event in events {
            switch event {
            case .nowPlaying(let track): announce(clean(track))
            case .scrobble(let track):
                currentIsScrobbled = true
                Task { await submit(clean(track)) }
            }
        }
    }

    public func clean(_ track: ScrobbleTrack) -> ScrobbleTrack {
        TitleCleaner(options: configuration.cleaner).clean(track)
    }

    private func announce(_ track: ScrobbleTrack) {
        let services = activeServices
        if services.contains(.lastFM), let client = lastFMClient() {
            Task {
                do { try await client.updateNowPlaying(track) } catch { await self.serviceFailed(.lastFM, error, context: "now playing") }
            }
        }
        if services.contains(.listenBrainz), let client = listenBrainzClient() {
            Task {
                do { try await client.playingNow(track) } catch { await self.serviceFailed(.listenBrainz, error, context: "now playing") }
            }
        }
    }

    /// Salva l'ascolto nella coda (prima di inviarlo) e avvia l'invio.
    func submit(_ track: ScrobbleTrack) async {
        let services = activeServices
        guard !services.isEmpty else {
            log("ascolto non registrato (nessun servizio collegato): \(track.artist) — \(track.title)")
            return
        }
        do {
            if try await queue.enqueue(track, services: services) {
                lastScrobble = track
                log("ascolto in coda: \(track.artist) — \(track.title)")
            } else {
                log("ascolto duplicato ignorato: \(track.artist) — \(track.title)")
            }
        } catch {
            log("errore della coda: \(error)")
        }
        await refreshPendingCount()
        requestFlush()
    }

    // MARK: Invio della coda

    /// Invia gli ascolti pronti, a blocchi, a ogni servizio attivo.
    public func flush() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        for service in ScrobbleServiceKind.allCases where activeServices.contains(service) {
            await flush(service)
        }
        await refreshPendingCount()
    }

    private func flush(_ service: ScrobbleServiceKind) async {
        var batchSize = service == .lastFM ? LastFMClient.maxBatch : ListenBrainzClient.maxBatch
        while activeServices.contains(service) {
            guard let items = try? await queue.due(for: service, limit: batchSize), !items.isEmpty else { return }
            let ids = items.map(\.id)
            do {
                switch service {
                case .lastFM:
                    guard let client = lastFMClient() else { return }
                    let result = try await client.scrobble(items.map(\.track))
                    try await applyLastFMResult(result, items: items)
                case .listenBrainz:
                    guard let client = listenBrainzClient() else { return }
                    try await client.submit(items.map(\.track))
                    try await queue.markSent(ids, for: service)
                }
                log("\(service.displayName): inviati \(items.count) ascolti")
                lastError = nil
            } catch let error as ScrobbleServiceError {
                if error.isRetryable {
                    try? await queue.markFailed(ids, for: service, error: error.description)
                    await serviceFailed(service, error, context: "invio")
                    return
                }
                if case .rejected = error, items.count > 1 {
                    // Un elemento non valido fa rifiutare tutto il blocco: si riprova uno alla volta.
                    batchSize = 1
                    continue
                }
                if case .rejected(let reason) = error {
                    try? await queue.drop(ids, for: service, reason: reason)
                    log("\(service.displayName): ascolto scartato (\(reason)): \(items[0].track.title)")
                    continue
                }
                await serviceFailed(service, error, context: "invio")
                return
            } catch {
                try? await queue.markFailed(ids, for: service, error: "\(error)")
                return
            }
        }
    }

    private func applyLastFMResult(_ result: LastFMClient.ScrobbleResult, items: [ScrobbleQueue.Item]) async throws {
        var sent = Set(items.map(\.id))
        for ignored in result.ignored where items.indices.contains(ignored.index) {
            let item = items[ignored.index]
            sent.remove(item.id)
            if ignored.isRetryable {
                try await queue.markFailed([item.id], for: .lastFM, error: "limite giornaliero (\(ignored.code))")
            } else {
                try await queue.drop([item.id], for: .lastFM, reason: "ignorato da Last.fm (\(ignored.code))")
                log("Last.fm ha ignorato «\(item.track.title)» (codice \(ignored.code))")
            }
        }
        try await queue.markSent(items.map(\.id).filter(sent.contains), for: .lastFM)
    }

    private func refreshPendingCount() async {
        let services = Set(ScrobbleServiceKind.allCases.filter { service in
            switch service {
            case .lastFM: configuration.lastFMEnabled && isLastFMConnected
            case .listenBrainz: configuration.listenBrainzEnabled && isListenBrainzConnected
            }
        })
        pendingCount = (try? await queue.pendingCount(for: services)) ?? 0
    }

    private func serviceFailed(_ service: ScrobbleServiceKind, _ error: any Error, context: String) async {
        let message = "\(service.displayName) (\(context)): \(error)"
        lastError = message
        log(message)
        if service == .lastFM, case .unauthorized = error as? ScrobbleServiceError {
            lastFMNeedsReconnect = true
        }
    }

    // MARK: Love

    /// Love/unlove su Last.fm del brano corrente (titolo pulito come negli scrobble).
    public func setLoved(_ loved: Bool) async throws {
        guard let track = lovableTrack() else { throw ScrobbleServiceError.rejected("nessun brano con artista") }
        guard let client = lastFMClient() else { throw ScrobbleServiceError.notConfigured("Last.fm non collegato") }
        let previous = currentIsLoved
        currentIsLoved = loved
        do {
            try await client.setLoved(loved, artist: track.artist, title: track.title)
            log("Last.fm: \(loved ? "love" : "unlove") «\(track.title)»")
        } catch {
            currentIsLoved = previous
            await serviceFailed(.lastFM, error, context: loved ? "love" : "unlove")
            throw error
        }
    }

    private func lovableTrack() -> ScrobbleTrack? {
        guard let track = store.track, let artist = track.artist, !artist.isEmpty else { return nil }
        return clean(ScrobbleTrack(
            artist: artist, title: track.title, album: track.album, albumArtist: track.albumArtist,
            duration: track.duration, startedAt: .now, playerBundleID: track.playerBundleID))
    }

    private func refreshLoved() {
        guard let track = lovableTrack(), let client = lastFMClient(), let user = lastFMUser else { return }
        let key = lovedKey
        Task {
            guard let loved = try? await client.isLoved(artist: track.artist, title: track.title, user: user),
                key == self.lovedKey
            else { return }
            self.currentIsLoved = loved
        }
    }

    // MARK: Accesso a Last.fm

    /// Flusso desktop: token → pagina di approvazione nel browser → session key nel Portachiavi.
    public func connectLastFM(open: @escaping @MainActor (URL) -> Void) {
        authTask?.cancel()
        guard let credentials = configuration.credentials else {
            lastFMAuth = .failed("Manca la API key di Last.fm: inseriscine una nelle impostazioni.")
            return
        }
        let client = LastFMClient(credentials: credentials, transport: transport)
        authTask = Task {
            do {
                let token = try await client.getToken()
                let url = client.authorizationURL(token: token)
                lastFMAuth = .waitingForApproval(url)
                open(url)
                // Il token vale 60 minuti; si aspetta l'approvazione per al massimo 10.
                let deadline = Date.now.addingTimeInterval(600)
                while Date.now < deadline {
                    try await Task.sleep(for: .seconds(3))
                    do {
                        let session = try await client.getSession(token: token)
                        try secrets.setSecret(session.key, for: SecretAccount.lastFMSession)
                        try secrets.setSecret(session.user, for: SecretAccount.lastFMUser)
                        lastFMSessionKey = session.key
                        lastFMUser = session.user
                        lastFMNeedsReconnect = false
                        lastFMAuth = .idle
                        log("Last.fm collegato come \(session.user)")
                        await refreshPendingCount()
                        requestFlush()
                        refreshLoved()
                        await refreshProfile(force: true)
                        return
                    } catch let error as LastFMClient.APIError where error.isTokenPending {
                        continue
                    }
                }
                lastFMAuth = .failed("Tempo scaduto: approvazione non ricevuta.")
            } catch is CancellationError {
                lastFMAuth = .idle
            } catch {
                lastFMAuth = .failed("\(error)")
                log("accesso a Last.fm fallito: \(error)")
            }
        }
    }

    public func cancelLastFMConnection() {
        authTask?.cancel()
        authTask = nil
        lastFMAuth = .idle
    }

    /// Scollega l'account: cancella la sessione dal Portachiavi, il profilo e la coda per Last.fm.
    public func disconnectLastFM() async {
        cancelLastFMConnection()
        try? secrets.setSecret(nil, for: SecretAccount.lastFMSession)
        try? secrets.setSecret(nil, for: SecretAccount.lastFMUser)
        lastFMSessionKey = nil
        lastFMUser = nil
        lastFMNeedsReconnect = false
        currentIsLoved = nil
        profile = nil
        if let profileCacheURL { try? FileManager.default.removeItem(at: profileCacheURL) }
        try? await queue.cancelAll(for: .lastFM)
        await refreshPendingCount()
        log("Last.fm scollegato")
    }

    // MARK: ListenBrainz

    /// Verifica il token e lo salva nel Portachiavi.
    public func connectListenBrainz(token: String) async throws {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = try await ListenBrainzClient(token: token, baseURL: configuration.listenBrainzServer, transport: transport).validateToken()
        try secrets.setSecret(token, for: SecretAccount.listenBrainzToken)
        try secrets.setSecret(user, for: SecretAccount.listenBrainzUser)
        listenBrainzToken = token
        listenBrainzUser = user
        log("ListenBrainz collegato come \(user)")
        await refreshPendingCount()
        requestFlush()
    }

    public func disconnectListenBrainz() async {
        try? secrets.setSecret(nil, for: SecretAccount.listenBrainzToken)
        try? secrets.setSecret(nil, for: SecretAccount.listenBrainzUser)
        listenBrainzToken = nil
        listenBrainzUser = nil
        try? await queue.cancelAll(for: .listenBrainz)
        await refreshPendingCount()
        log("ListenBrainz scollegato")
    }

    // MARK: Profilo

    /// Aggiorna il profilo Last.fm se la cache è più vecchia di `profileMaxAge` (o se `force`).
    public func refreshProfile(force: Bool = false) async {
        guard let user = lastFMUser, let client = lastFMClient() else { return }
        if !force, let profile, profile.user.name == user, Date.now.timeIntervalSince(profile.fetchedAt) < Self.profileMaxAge { return }
        do {
            let fresh = try await client.profile(user: user)
            profile = fresh
            Self.saveProfile(fresh, to: profileCacheURL)
        } catch {
            log("profilo Last.fm non aggiornato: \(error)")
        }
    }

    private static func loadProfile(from url: URL?) -> LastFMProfile? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LastFMProfile.self, from: data)
    }

    private static func saveProfile(_ profile: LastFMProfile, to url: URL?) {
        guard let url, let data = try? JSONEncoder().encode(profile) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Scopri (top album, simili)

    /// Top album dell'utente collegato. Lancia `notConfigured` se Last.fm non è collegato.
    public func topAlbums(period: LastFMPeriod, limit: Int = 25) async throws -> [LastFMAlbum] {
        guard let user = lastFMUser, let client = discoveryClient() else {
            throw ScrobbleServiceError.notConfigured("Last.fm non collegato")
        }
        return try await client.topAlbums(user: user, period: period, limit: limit)
    }

    /// Artisti simili: basta la chiave API, non serve l'accesso.
    public func similarArtists(to artist: String) async throws -> [LastFMSimilarItem] {
        guard let client = discoveryClient() else { throw ScrobbleServiceError.notConfigured("API key Last.fm mancante") }
        return try await client.similarArtists(artist: artist)
    }

    public func similarTracks(artist: String, title: String) async throws -> [LastFMSimilarItem] {
        guard let client = discoveryClient() else { throw ScrobbleServiceError.notConfigured("API key Last.fm mancante") }
        return try await client.similarTracks(artist: artist, title: title)
    }

    /// `true` se si possono chiedere i dati pubblici di Last.fm (chiave del progetto o personale).
    public var canDiscover: Bool { configuration.credentials != nil }

    // MARK: Client

    /// Client per le chiamate pubbliche (non firmate): non richiede la sessione.
    private func discoveryClient() -> LastFMClient? {
        configuration.credentials.map { LastFMClient(credentials: $0, sessionKey: lastFMSessionKey, transport: transport) }
    }

    private func lastFMClient() -> LastFMClient? {
        guard let credentials = configuration.credentials, let session = lastFMSessionKey else { return nil }
        return LastFMClient(credentials: credentials, sessionKey: session, transport: transport)
    }

    private func listenBrainzClient() -> ListenBrainzClient? {
        listenBrainzToken.map { ListenBrainzClient(token: $0, baseURL: configuration.listenBrainzServer, transport: transport) }
    }

    private func log(_ message: String) {
        store.log("scrobble", message)
    }
}

/// `Observations` creato in una funzione generica: con il tipo concreto (`NowPlayingSnapshot?`) il compilatore
/// di Xcode 26.6, usato dalla CI, va in crash generando il thunk della closure.
@MainActor
func observations<T: Sendable>(_ value: @escaping @MainActor @Sendable () -> T) -> Observations<T, Never> {
    Observations(value)
}

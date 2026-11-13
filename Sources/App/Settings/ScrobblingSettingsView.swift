// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MediaCore
import SwiftUI

/// Impostazioni di Last.fm, ListenBrainz, regole, pulizia dei titoli, player e coda.
struct ScrobblingSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            LastFMSection(model: model)
            ListenBrainzSection(model: model)
            Section {
                LabeledContent("Soglia") {
                    HStack {
                        Slider(value: $settings.scrobblePercent, in: 25...100, step: 5)
                        Text("\(Int(settings.scrobblePercent))%")
                            .font(DesignSystem.Typography.time)
                            .frame(width: DesignSystem.Size.control * 1.5, alignment: .trailing)
                    }
                }
                Toggle("Al massimo 4 minuti di ascolto", isOn: $settings.scrobbleCapsAtFourMinutes)
            } header: {
                Text("Quando registrare un ascolto")
            } footer: {
                Text("Regola di Last.fm: metà del brano o 4 minuti, quello che arriva prima; i brani di 30 secondi o meno non contano. La pausa non azzera il tempo ascoltato.")
            }
            CleanupSection(model: model)
            PlayersSection(model: model)
            Section("Love e menu bar") {
                Toggle("Il love imposta anche il preferito in Musica", isOn: $settings.syncsLoveWithMusic)
                Toggle("Mostra in menu bar quando ci sono ascolti in coda", isOn: $settings.showsQueueIndicator)
            }
            QueueSection(model: model)
        }
        .formStyle(.grouped)
    }
}

private struct LastFMSection: View {
    let model: AppModel
    @State private var secret = ""

    var body: some View {
        @Bindable var settings = model.settings
        let scrobbler = model.scrobbler
        Section {
            Toggle("Invia gli ascolti a Last.fm", isOn: $settings.lastFMEnabled)
            if let user = scrobbler.lastFMUser {
                LabeledContent("Account") {
                    HStack {
                        Text(user)
                        Button("Scollega") { Task { await scrobbler.disconnectLastFM() } }
                    }
                }
                if scrobbler.lastFMNeedsReconnect {
                    Label("Last.fm ha rifiutato la sessione: accedi di nuovo.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    connectButton
                }
            } else {
                switch scrobbler.lastFMAuth {
                case .waitingForApproval(let url):
                    LabeledContent("In attesa dell'approvazione nel browser…") {
                        HStack {
                            Link("Riapri la pagina", destination: url)
                            Button("Annulla") { scrobbler.cancelLastFMConnection() }
                        }
                    }
                case .failed(let message):
                    Text(message).foregroundStyle(.red).font(DesignSystem.Typography.caption)
                    connectButton
                case .idle:
                    connectButton
                }
            }
            Toggle("Usa una API key personale", isOn: $settings.lastFMUsesCustomKey)
            if settings.lastFMUsesCustomKey {
                TextField("API key", text: $settings.lastFMCustomAPIKey)
                HStack {
                    SecureField("Shared secret", text: $secret, prompt: Text(model.customLastFMSecret.isEmpty ? "" : "salvata nel Portachiavi"))
                        .onSubmit(saveSecret)
                    Button("Salva", action: saveSecret).disabled(secret.isEmpty)
                }
                Link("Crea una API key su Last.fm", destination: URL(string: "https://www.last.fm/api/account/create")!)
                    .font(DesignSystem.Typography.caption)
            }
        } header: {
            Text("Last.fm")
        } footer: {
            if model.lastFMCredentials == nil {
                Text("Questa build non include una API key Last.fm: attiva «Usa una API key personale» e inserisci la tua.")
            } else {
                Text("L'accesso avviene nel browser; la sessione è salvata nel Portachiavi. In un'app open source la secret dell'app è di fatto pubblica: puoi usare la tua chiave.")
            }
        }
    }

    private var connectButton: some View {
        Button(model.scrobbler.lastFMNeedsReconnect ? "Accedi di nuovo…" : "Accedi a Last.fm…") {
            model.scrobbler.connectLastFM { NSWorkspace.shared.open($0) }
        }
        .disabled(model.lastFMCredentials == nil)
    }

    private func saveSecret() {
        model.setCustomLastFMSecret(secret)
        secret = ""
    }
}

private struct ListenBrainzSection: View {
    let model: AppModel
    @State private var token = ""
    @State private var error: String?
    @State private var connecting = false

    var body: some View {
        @Bindable var settings = model.settings
        let scrobbler = model.scrobbler
        Section {
            Toggle("Invia gli ascolti a ListenBrainz", isOn: $settings.listenBrainzEnabled)
            if let user = scrobbler.listenBrainzUser {
                LabeledContent("Account") {
                    HStack {
                        Text(user)
                        Button("Scollega") { Task { await scrobbler.disconnectListenBrainz() } }
                    }
                }
            } else {
                TextField("Server", text: $settings.listenBrainzServer, prompt: Text("listenbrainz.org (o Maloja: https://server)"))
                HStack {
                    SecureField("Token utente", text: $token)
                        .onSubmit(connect)
                    Button("Collega", action: connect).disabled(token.isEmpty || connecting)
                }
                if let error {
                    Text(error).foregroundStyle(.red).font(DesignSystem.Typography.caption)
                }
                Link("Trova il token nelle impostazioni di ListenBrainz", destination: URL(string: "https://listenbrainz.org/settings/")!)
                    .font(DesignSystem.Typography.caption)
            }
        } header: {
            Text("ListenBrainz")
        } footer: {
            Text("Il token è salvato nel Portachiavi. Per Maloja o un'istanza propria di ListenBrainz scrivi l'indirizzo del server prima di collegare il token.")
        }
    }

    private func connect() {
        connecting = true
        Task {
            do {
                try await model.scrobbler.connectListenBrainz(token: token)
                token = ""
                error = nil
            } catch {
                self.error = "Token non valido: \(error)"
            }
            connecting = false
        }
    }
}

private struct CleanupSection: View {
    let model: AppModel

    /// Esempi mostrati nell'anteprima quando non c'è un brano in riproduzione.
    private static let samples = [
        "Let It Be (Remastered 2009)", "Blinding Lights - Radio Edit", "Bad Guy [Official Video]",
        "Under Pressure (feat. David Bowie)",
    ]

    var body: some View {
        @Bindable var settings = model.settings
        Section {
            Toggle("Togli «Remastered», «2011 Remaster»…", isOn: $settings.cleansRemaster)
            Toggle("Togli «Radio Edit», «Single Version»…", isOn: $settings.cleansVersionTags)
            Toggle("Togli «Official Video», «Lyric Video»…", isOn: $settings.cleansVideoTags)
            Toggle("Togli «feat. …» dal titolo", isOn: $settings.cleansFeaturing)
            Toggle("Correggi l'album artist delle compilation e «- Single»", isOn: $settings.fixesAlbumArtist)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                ForEach(previewTitles, id: \.self) { original in
                    let cleaned = TitleCleaner(options: settings.cleanerOptions).cleanTitle(original)
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(original).foregroundStyle(.secondary)
                        Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                        Text(cleaned).foregroundStyle(cleaned == original ? .secondary : .primary)
                    }
                    .lineLimit(1)
                }
            }
            .font(DesignSystem.Typography.caption)
            .accessibilityLabel("Anteprima: titolo originale e titolo inviato")
        } header: {
            Text("Scrobble puliti")
        } footer: {
            Text("La pulizia vale solo per gli ascolti inviati: OpenTunes mostra sempre il titolo originale.")
        }
    }

    private var previewTitles: [String] {
        if let title = model.track?.title { return [title] + Self.samples.prefix(2) }
        return Self.samples
    }
}

private struct PlayersSection: View {
    let model: AppModel

    var body: some View {
        Section {
            ForEach(players, id: \.self) { bundleID in
                Toggle(isOn: Binding(
                    get: { model.settings.scrobbles(bundleID) },
                    set: { model.settings.setScrobbles(bundleID, $0) }
                )) {
                    HStack(spacing: DesignSystem.Spacing.s) {
                        let player = PlayerApp.resolve(bundleID: bundleID)
                        if let icon = player.icon {
                            Image(nsImage: icon).resizable()
                                .frame(width: DesignSystem.Size.smallIcon, height: DesignSystem.Size.smallIcon)
                        }
                        Text(player.name)
                        if player.isBrowser {
                            Text("browser").font(DesignSystem.Typography.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Player che fanno scrobbling")
        } footer: {
            Text("I browser sono esclusi di default (video di YouTube e simili). I player nuovi fanno scrobbling finché non li escludi.")
        }
    }

    /// Player noti installati, più quelli visti in riproduzione.
    private var players: [String] {
        var result = PlayerApp.known.map(\.bundleID).filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
        }
        for bundleID in model.settings.seenPlayerBundleIDs where !result.contains(bundleID) { result.append(bundleID) }
        return result
    }
}

private struct QueueSection: View {
    let model: AppModel

    var body: some View {
        let scrobbler = model.scrobbler
        Section("Coda e cronologia") {
            LabeledContent("Ascolti in attesa", value: "\(scrobbler.pendingCount)")
            if let last = scrobbler.lastScrobble {
                LabeledContent("Ultimo ascolto", value: "\(last.artist) — \(last.title)")
            }
            if let error = scrobbler.lastError {
                Text(error).font(DesignSystem.Typography.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Invia ora") { scrobbler.retryNow() }
                    .disabled(scrobbler.pendingCount == 0)
                Spacer()
                Button("Cancella la cronologia locale") { model.store.clearHistory() }
            }
        }
    }
}

#Preview("Impostazioni scrobbling") {
    ScrobblingSettingsView(model: .preview())
        .frame(width: DesignSystem.Size.settingsWidth, height: DesignSystem.Size.settingsHeight)
}

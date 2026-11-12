// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import KeyboardShortcuts
import MediaCore
import SwiftUI

// MARK: Generali

struct GeneralSettingsView: View {
    let model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Toggle("Apri OpenTunes al login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.set(enabled)
                            launchError = nil
                        } catch {
                            launchError = error.localizedDescription
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if let launchError {
                    Text(launchError).font(DesignSystem.Typography.caption).foregroundStyle(.red)
                }
            }
            Section("Finestra flottante") {
                Toggle("Mostra la finestra flottante", isOn: $settings.floatingVisible)
                Picker("Taglia", selection: $settings.floatingSize) {
                    ForEach(FloatingSize.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Colora le superfici con la tinta della copertina", isOn: $settings.tintsWithArtwork)
            }
            Section {
                Toggle("Mostra l'HUD sullo schermo", isOn: $settings.hudOnTrackChange)
                Picker("Notifica di sistema", selection: $settings.notificationMode) {
                    ForEach(NotificationMode.allCases) { Text($0.label).tag($0) }
                }
            } header: {
                Text("Cambio brano")
            } footer: {
                Text("L'HUD compare anche con play/pausa e salto di brano. Entrambi sono spenti finché non li attivi.")
            }
            Section("Volume") {
                Toggle("Mostra l'HUD al cambio volume", isOn: $settings.hudOnVolumeChange)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

// MARK: Menu bar

struct MenuBarSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                preview
            }
            Section {
                List {
                    ForEach(settings.menuBarOrder) { element in
                        Toggle(isOn: Binding(
                            get: { settings.isVisible(element) },
                            set: { settings.setVisible(element, $0) }
                        )) {
                            Label(element.label, systemImage: "line.3.horizontal")
                        }
                    }
                    .onMove { settings.menuBarOrder.move(fromOffsets: $0, toOffset: $1) }
                }
                .frame(height: 3 * DesignSystem.Size.control + 2 * DesignSystem.Spacing.m)
            } header: {
                Text("Elementi")
            } footer: {
                Text("Trascina per riordinare. Con tutti gli elementi spenti resta la copertina.")
            }
            Section("Formato del titolo") {
                TitleFormatEditor(template: $settings.titleTemplate, sample: model.track ?? PreviewData.track)
                LabeledContent("Larghezza massima") {
                    HStack {
                        Slider(value: $settings.maxTitleWidth, in: 60...400, step: 10)
                        Text("\(Int(settings.maxTitleWidth)) pt")
                            .font(DesignSystem.Typography.time)
                            .frame(width: DesignSystem.Size.control * 2, alignment: .trailing)
                    }
                }
                Toggle("Fai scorrere il titolo se è troppo lungo", isOn: $settings.scrollsTitle)
            }
            Section("Comportamento") {
                Toggle("Controlli e titolo come due elementi separati", isOn: $settings.separateControlsItem)
                Toggle("Nascondi quando non c'è niente in riproduzione", isOn: $settings.hidesWhenIdle)
                Toggle("Modalità compatta automatica accanto al notch", isOn: $settings.autoCompact)
            }
            Section("Mouse") {
                Picker("Clic sinistro", selection: $settings.leftClick) { actions }
                Picker("Clic centrale", selection: $settings.middleClick) { actions }
                Picker("Clic destro", selection: $settings.rightClick) { actions }
                Picker("Rotella", selection: $settings.scrollAction) {
                    ForEach(ScrollAction.allCases) { Text($0.label).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var actions: some View {
        ForEach(MouseAction.allCases) { Text($0.label).tag($0) }
    }

    /// Anteprima dell'elemento in menu bar, su una capsula di vetro.
    private var preview: some View {
        HStack {
            Spacer()
            StatusItemContent(
                role: .combined, model: model, state: StatusItemState(), layout: StatusItemLayout()
            ) { _ in }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.s)
            .glassEffect()
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.s)
        .accessibilityLabel("Anteprima della menu bar")
    }
}

/// Campo del formato con preset e pulsanti per inserire i segnaposto.
struct TitleFormatEditor: View {
    @Binding var template: String
    let sample: Track

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s) {
            HStack {
                TextField("Formato", text: $template, prompt: Text("{artist} — {title}"))
                    .labelsHidden()
                Menu {
                    ForEach(TitleFormat.presets, id: \.template) { preset in
                        Button(preset.template) { template = preset.template }
                    }
                } label: {
                    Image(systemName: "list.bullet")
                }
                .menuStyle(.button)
                .fixedSize()
                .help("Formati predefiniti")
            }
            HStack(spacing: DesignSystem.Spacing.s) {
                Text("Inserisci:").font(DesignSystem.Typography.caption).foregroundStyle(.secondary)
                ForEach([("Artista", "artist"), ("Titolo", "title"), ("Album", "album")], id: \.1) { label, token in
                    Button(label) { template += "{\(token)}" }
                        .controlSize(.small)
                }
                Spacer()
            }
            Text(TitleFormat(template).render(title: sample.title, artist: sample.artist, album: sample.album))
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: Posizione

struct PositionSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Finestra flottante") {
                Picker("Taglia", selection: $settings.floatingSize) {
                    ForEach(FloatingSize.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Nascondi sopra le app a schermo intero", isOn: $settings.floatingHidesInFullScreen)
                Text("La finestra si sposta trascinandola dallo sfondo e ricorda la posizione.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Section("HUD") {
                Picker("Posizione dell'HUD", selection: $settings.hudPosition) {
                    ForEach(HUDPosition.allCases) { Text($0.label).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Scorciatoie

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section {
                ForEach(Hotkeys.all, id: \.name) { entry in
                    KeyboardShortcuts.Recorder(entry.label, name: entry.name)
                }
            } footer: {
                Text("Le scorciatoie funzionano in qualsiasi app.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Altro

struct OtherSettingsView: View {
    let model: AppModel
    var onOpenDebug: () -> Void
    @State private var newBundleID = ""

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                ForEach(settings.ignoredBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Text(PlayerApp.resolve(bundleID: bundleID).name)
                        Text(bundleID).font(DesignSystem.Typography.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            settings.ignoredBundleIDs.removeAll { $0 == bundleID }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Rimuovi")
                    }
                }
                HStack {
                    TextField("Bundle ID", text: $newBundleID, prompt: Text("es. com.apple.Safari"))
                        .onSubmit(addBundleID)
                    Menu("App aperte") {
                        ForEach(runningApps, id: \.bundleID) { app in
                            Button(app.name) { add(app.bundleID) }
                        }
                    }
                    .fixedSize()
                    if let current = model.track?.playerBundleID, !current.isEmpty {
                        Button("Player attuale") { add(current) }
                    }
                }
            } header: {
                Text("Player ignorati")
            } footer: {
                Text("Quello che riproducono queste app non compare in OpenTunes (utile per Zoom o i video nel browser).")
            }
            Section("Metadati") {
                Toggle("Pulisci i titoli dei browser (es. «(Official Video)»)", isOn: $settings.normalizesBrowserTitles)
                Toggle("Cerca le copertine mancanti su iTunes", isOn: $settings.looksUpMissingArtwork)
                Text("La ricerca invia artista e titolo all'iTunes Search API di Apple.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Sorgente attiva", value: model.store.activeSourceID ?? "nessuna")
                Button("Apri la diagnostica…", action: onOpenDebug)
                LabeledContent("Versione", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                Text("OpenTunes è software libero (GPL-3.0-or-later). Non è affiliato a NepTunes né ad Apple.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var runningApps: [(bundleID: String, name: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in app.bundleIdentifier.map { ($0, app.localizedName ?? $0) } }
            .filter { !model.settings.ignoredBundleIDs.contains($0.0) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private func addBundleID() {
        add(newBundleID.trimmingCharacters(in: .whitespaces))
        newBundleID = ""
    }

    private func add(_ bundleID: String) {
        guard !bundleID.isEmpty, !model.settings.ignoredBundleIDs.contains(bundleID) else { return }
        model.settings.ignoredBundleIDs.append(bundleID)
    }
}

#Preview("Impostazioni menu bar") {
    MenuBarSettingsView(model: .preview())
        .frame(width: DesignSystem.Size.settingsWidth, height: DesignSystem.Size.settingsHeight)
}

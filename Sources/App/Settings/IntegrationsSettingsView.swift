// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Integrazioni della fase 5: Discord, riga di comando e URL, Comandi Rapidi, MIDI, temi JSON, statistiche.
struct IntegrationsSettingsView: View {
    let model: AppModel
    @State private var cliInstalled = CommandLineBridge.isInstalled
    @State private var cliError: String?
    @State private var themeMessage: String?

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Toggle("Mostra su Discord cosa stai ascoltando", isOn: $settings.discordEnabled)
                TextField("ID applicazione", text: $settings.discordApplicationID, prompt: Text("quello del progetto, se presente"))
                    .disabled(!settings.discordEnabled)
                if settings.discordEnabled, let status = model.discord?.status, !status.isEmpty {
                    Text(status).font(DesignSystem.Typography.caption).foregroundStyle(.secondary)
                }
                Link("Crea un'applicazione su discord.com/developers", destination: URL(string: "https://discord.com/developers/applications")!)
                    .font(DesignSystem.Typography.caption)
            } header: {
                Text("Discord Rich Presence")
            } footer: {
                Text("Serve Discord aperto su questo Mac: OpenTunes gli parla in locale, senza account né token. La copertina arriva dall'iTunes Search API se «Cerca le copertine mancanti» è acceso. In pausa l'attività sparisce.")
            }

            Section {
                Toggle("Comandi via URL e riga di comando", isOn: $settings.urlCommandsEnabled)
                LabeledContent("Comando") {
                    HStack {
                        Text(cliInstalled ? "~/.local/bin/opentunes" : "non installato")
                            .font(DesignSystem.Typography.time)
                            .foregroundStyle(.secondary)
                        Button(cliInstalled ? "Reinstalla" : "Installa", action: installCLI)
                    }
                }
                .disabled(!settings.urlCommandsEnabled)
                if let cliError {
                    Text(cliError).font(DesignSystem.Typography.caption).foregroundStyle(.red)
                }
                Text("opentunes now · next · love · copy-link · volume 40 — oppure open opentunes://next da Raycast, Alfred, BetterTouchTool o Keyboard Maestro.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } header: {
                Text("Riga di comando e URL")
            } footer: {
                Text("Aggiungi ~/.local/bin al PATH (es. in ~/.zshrc: export PATH=\"$HOME/.local/bin:$PATH\"). Il clic sul widget (opentunes://player) funziona sempre.")
            }

            Section {
                Toggle("Comandi Rapidi, Siri e Spotlight", isOn: $settings.appIntentsEnabled)
            } header: {
                Text("Comandi Rapidi")
            } footer: {
                Text("Azioni: brano in riproduzione, play/pausa, successivo, precedente, love, copia il link universale, mostra il testo. Frasi in italiano e in inglese, es. «Che brano sta suonando su OpenTunes?».")
            }

            MIDISection(model: model)

            Section {
                Picker("Tema", selection: $settings.theme) {
                    ForEach(SurfaceTheme.allCases) { Text($0.label).tag($0) }
                }
                HStack {
                    Button("Importa tema JSON…", action: importTheme)
                    Button("Esporta…", action: exportTheme)
                    Spacer()
                }
                if settings.theme == .custom {
                    LabeledContent("Tema personalizzato", value: CustomTheme.active.name)
                }
                if let themeMessage {
                    Text(themeMessage).font(DesignSystem.Typography.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Temi")
            } footer: {
                Text("Un tema è un file JSON con nome, vetro (regular o clear), tinta (#RRGGBB o «artwork»), opacità e accento. Esporta il modello, modificalo e proponilo con una PR nella cartella themes/ del repository.")
            }

            Section {
                Toggle("Statistiche di ascolto locali", isOn: $settings.statisticsEnabled)
                Button("Apri le statistiche…") { model.onOpenStatistics?() }
                    .disabled(!settings.statisticsEnabled || model.onOpenStatistics == nil)
            } header: {
                Text("Statistiche")
            } footer: {
                Text("Calcolate dalla cronologia su questo Mac (fino a 10.000 ascolti), senza Last.fm.")
            }
        }
        .formStyle(.grouped)
        .onAppear { cliInstalled = CommandLineBridge.isInstalled }
    }

    private func installCLI() {
        do {
            try CommandLineBridge.install()
            cliError = nil
        } catch {
            cliError = String(localized: "Installazione non riuscita: \(error.localizedDescription)")
        }
        cliInstalled = CommandLineBridge.isInstalled
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.settings.importTheme(Data(contentsOf: url))
            themeMessage = String(localized: "Tema «\(CustomTheme.active.name)» attivo.")
        } catch {
            themeMessage = String(localized: "Tema non valido: \(String(describing: error))")
        }
    }

    private func exportTheme() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let theme = model.settings.theme == .custom ? CustomTheme.active : CustomTheme.template
        panel.nameFieldStringValue = "\(theme.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try theme.encoded().write(to: url, options: .atomic)
            themeMessage = String(localized: "Tema esportato.")
        } catch {
            themeMessage = error.localizedDescription
        }
    }
}

/// Pad e manopole MIDI: per ogni azione il messaggio assegnato e il pulsante «Impara».
private struct MIDISection: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings
        Section {
            Toggle("Controllo da MIDI", isOn: $settings.midiEnabled)
            if let midi = model.midi, settings.midiEnabled {
                LabeledContent("Dispositivi", value: midi.sourceNames.isEmpty ? String(localized: "nessuno") : midi.sourceNames.joined(separator: ", "))
                ForEach(MIDIAction.allCases) { action in
                    LabeledContent(action.label) {
                        HStack {
                            if midi.learning == action {
                                Text("Premi un pad…").foregroundStyle(.tint)
                            } else {
                                Text(midi.trigger(for: action)?.label ?? "—").foregroundStyle(.secondary)
                            }
                            Button(midi.learning == action ? "Annulla" : "Impara") {
                                midi.learning = midi.learning == action ? nil : action
                            }
                            if midi.trigger(for: action) != nil {
                                Button {
                                    midi.clear(action)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("Togli")
                            }
                        }
                    }
                }
            }
        } header: {
            Text("MIDI")
        } footer: {
            Text("Note e Control Change di qualsiasi controller collegato (es. un pad MPD218). Scegli «Impara» e premi il pad da assegnare.")
        }
    }
}

#Preview("Impostazioni integrazioni") {
    IntegrationsSettingsView(model: .preview())
        .frame(width: DesignSystem.Size.settingsWidth, height: DesignSystem.Size.settingsHeight)
}

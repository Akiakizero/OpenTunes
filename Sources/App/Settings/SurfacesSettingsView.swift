// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Superfici dell'app: in cima un interruttore per ognuna (si possono tenere sempre spente),
/// sotto le opzioni di ciascuna. Le opzioni di una superficie spenta restano visibili ma disattivate.
struct SurfacesSettingsView: View {
    let model: AppModel
    @State private var otherNotchApp: String?

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                ForEach(Surface.allCases) { surface in
                    Toggle(isOn: Binding(get: { settings.isEnabled(surface) }, set: { settings.setEnabled(surface, $0) })) {
                        Label {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                Text(surface.label)
                                Text(surface.summary)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: surface.symbol)
                                .foregroundStyle(.tint)
                                .frame(width: DesignSystem.Size.control)
                        }
                    }
                    .accessibilityHint(surface.summary)
                }
                if !settings.menuBarEnabled {
                    Label("Senza menu bar, le impostazioni si aprono riaprendo OpenTunes dal Finder, da Spotlight o dal Launchpad.",
                          systemImage: "info.circle")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                if !settings.hasInteractiveSurface {
                    Label("Tutte le superfici con i controlli sono spente: restano solo scorciatoie e widget di macOS.",
                          systemImage: "exclamationmark.triangle")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Superfici attive")
            } footer: {
                Text("Una superficie spenta resta spenta anche dopo il riavvio, finché non la riaccendi qui.")
            }

            Section {
                Toggle("Mostra la finestra adesso", isOn: $settings.floatingVisible)
                Picker("Taglia", selection: $settings.floatingSize) {
                    ForEach(FloatingSize.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Nascondi sopra le app a schermo intero", isOn: $settings.floatingHidesInFullScreen)
            } header: {
                Text("Finestra flottante")
            } footer: {
                Text("Si sposta trascinandola dallo sfondo e ricorda la posizione. Il clic destro mostra le altre opzioni.")
            }
            .disabled(!settings.floatingEnabled)

            Section {
                Toggle("Apri passando sopra con il mouse", isOn: $settings.notchOpensOnHover)
                Toggle("Mostra il titolo al cambio brano", isOn: $settings.notchPeeksOnTrackChange)
                Toggle("Mostra la riga del testo sotto il titolo", isOn: $settings.notchShowsLyrics)
                    .disabled(!settings.lyricsEnabled)
                if let otherNotchApp, settings.notchEnabled {
                    Label("\(otherNotchApp) è aperta e usa già il notch: puoi spegnere qui il player di OpenTunes.",
                          systemImage: "exclamationmark.triangle")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Notch")
            } footer: {
                Text("Chiuso mostra la copertina a sinistra del notch e l'indicatore di riproduzione a destra; si apre con un clic o passandoci sopra. Sui Mac senza notch è una capsula al centro della menu bar.")
            }
            .disabled(!settings.notchEnabled)

            Section {
                Picker("Layout", selection: $settings.desktopWidgetLayout) {
                    ForEach(DesktopWidgetLayout.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Grafico dei top artisti Last.fm", isOn: $settings.desktopWidgetShowsChart)
                    .disabled(settings.desktopWidgetLayout == .artwork)
                Toggle("Blocca posizione e misura", isOn: $settings.desktopWidgetLocked)
            } header: {
                Text("Widget sulla scrivania")
            } footer: {
                Text("Sta sopra lo sfondo e sotto le finestre, su tutte le scrivanie. Trascinalo dallo sfondo e ridimensionalo dai bordi: posizione e misura si ricordano per ogni monitor.")
            }
            .disabled(!settings.desktopWidgetVisible)

            Section {
                Text("Aggiungi il widget «In riproduzione» dal Centro notifiche o con un clic destro sulla scrivania › Modifica widget. Le taglie sono tre; la grande mostra anche gli ascolti recenti su Last.fm. Spento, il widget resta dove l'hai messo ma non riceve più il brano.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Widget di macOS")
            }

            Section {
                Toggle("Copertina come icona del Dock", isOn: $settings.dockShowsArtwork)
            } header: {
                Text("Dock")
            } footer: {
                Text("Con questa opzione OpenTunes compare anche nel Dock.")
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: detectOtherNotchApps)
    }

    private func detectOtherNotchApps() {
        otherNotchApp = NSWorkspace.shared.runningApplications
            .first { app in app.bundleIdentifier.map(NotchController.otherNotchApps.contains) ?? false }
            .map { $0.localizedName ?? $0.bundleIdentifier ?? "" }
    }
}

#Preview("Impostazioni superfici") {
    SurfacesSettingsView(model: .preview())
        .frame(width: DesignSystem.Size.settingsWidth, height: DesignSystem.Size.settingsHeight)
}

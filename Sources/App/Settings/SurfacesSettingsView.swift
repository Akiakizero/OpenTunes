// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Notch, widget sulla scrivania, widget WidgetKit e icona del Dock.
struct SurfacesSettingsView: View {
    let model: AppModel
    @State private var otherNotchApp: String?

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Toggle("Mostra il player nel notch", isOn: $settings.notchEnabled)
                Toggle("Apri passando sopra con il mouse", isOn: $settings.notchOpensOnHover)
                    .disabled(!settings.notchEnabled)
                Toggle("Mostra il titolo al cambio brano", isOn: $settings.notchPeeksOnTrackChange)
                    .disabled(!settings.notchEnabled)
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
            Section {
                Toggle("Mostra il widget sulla scrivania", isOn: $settings.desktopWidgetVisible)
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
            Section {
                Text("Aggiungi il widget «In riproduzione» dal Centro notifiche o con un clic destro sulla scrivania › Modifica widget. Le taglie sono tre; la grande mostra anche gli ascolti recenti su Last.fm.")
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

// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Un interruttore per ogni funzione dell'app, raggruppati per area: ognuno tiene solo quello che usa.
/// Le superfici (menu bar, notch, finestre, widget) si accendono e spengono in «Superfici».
struct FeaturesSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Toggle("Love (Last.fm o preferito di Musica)", isOn: $settings.loveEnabled)
                Toggle("Stelle, «Non mi piace» e «Aggiungi alla libreria» (Musica)", isOn: $settings.musicActionsEnabled)
                Toggle("Passa da un player all'altro (Musica ↔ Spotify)", isOn: $settings.switchPlayerEnabled)
                Toggle("Link universale e Condividi (song.link)", isOn: $settings.shareLinksEnabled)
                Toggle("Testi sincronizzati (LRCLIB)", isOn: $settings.lyricsEnabled)
                Toggle("Scopri: top album e brani simili (Last.fm)", isOn: $settings.discoverEnabled)
            } header: {
                Text("Brano")
            } footer: {
                Text("Link, testi e Scopri inviano artista e titolo ai servizi indicati solo quando li usi.")
            }

            Section("Player nel popover") {
                Toggle("Volume di sistema", isOn: $settings.showsSystemVolume)
                Toggle("Scelta dell'uscita audio", isOn: $settings.showsAudioOutput)
                Toggle("Volume del player (Musica, Spotify)", isOn: $settings.showsPlayerVolume)
                Toggle("Pulsante «Apri il player»", isOn: $settings.showsOpenPlayer)
                Toggle("Stato dello scrobbling ed errori", isOn: $settings.showsScrobbleStatus)
                Toggle("Ascoltati di recente", isOn: $settings.showsRecentTracks)
                Toggle("Scheda Last.fm (profilo e top artisti)", isOn: $settings.showsLastFMProfile)
            }

            Section {
                Toggle("Visualizer al posto dell'indicatore di riproduzione", isOn: $settings.visualizerEnabled)
                Toggle("Segui l'audio reale (spettro)", isOn: $settings.visualizerUsesAudio)
                    .disabled(!settings.visualizerEnabled)
            } header: {
                Text("Visualizer")
            } footer: {
                Text("Con lo spettro reale macOS chiede una volta il permesso «Registrazione audio di sistema»: l'audio viene solo analizzato, niente viene registrato. Senza, le barre sono un'animazione.")
            }

            Section("Riscontri") {
                Toggle("HUD al cambio brano, play/pausa e salto", isOn: $settings.hudOnTrackChange)
                Toggle("HUD al cambio volume", isOn: $settings.hudOnVolumeChange)
                Toggle("Indicatore degli ascolti in coda in menu bar", isOn: $settings.showsQueueIndicator)
            }

            Section {
                Toggle("Scorciatoie da tastiera globali", isOn: $settings.hotkeysEnabled)
                Toggle("Comandi Rapidi, Siri e Spotlight", isOn: $settings.appIntentsEnabled)
                Toggle("Comandi via URL e riga di comando (opentunes://)", isOn: $settings.urlCommandsEnabled)
                Toggle("Discord Rich Presence", isOn: $settings.discordEnabled)
                Toggle("Controllo da MIDI", isOn: $settings.midiEnabled)
                Toggle("Statistiche di ascolto locali", isOn: $settings.statisticsEnabled)
            } header: {
                Text("Automazione e integrazioni")
            } footer: {
                Text("Le opzioni di Discord, MIDI e della riga di comando sono nella scheda «Integrazioni».")
            }

            Section("Metadati") {
                Toggle("Pulisci i titoli dei browser", isOn: $settings.normalizesBrowserTitles)
                Toggle("Cerca le copertine mancanti su iTunes", isOn: $settings.looksUpMissingArtwork)
                Toggle("Colori dalla copertina (tema)", isOn: Binding(
                    get: { settings.theme.usesArtworkTint },
                    set: { settings.theme = $0 ? .artwork : .monochrome }))
            }
        }
        .formStyle(.grouped)
    }
}

#Preview("Impostazioni funzioni") {
    FeaturesSettingsView(model: .preview())
        .frame(width: DesignSystem.Size.settingsWidth, height: DesignSystem.Size.settingsHeight)
}

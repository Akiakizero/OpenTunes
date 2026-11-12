// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MediaCore

extension AppModel {
    /// Modello con un brano finto e preferenze isolate (non tocca `UserDefaults.standard`).
    @MainActor
    static func preview(size: FloatingSize = .large, track: Track? = nil) -> AppModel {
        // Valori predefiniti e nessun salvataggio: le anteprime non toccano le preferenze reali.
        let settings = AppSettings(defaults: UserDefaults(suiteName: "org.opentunes.preview") ?? .standard, persists: false)
        settings.floatingSize = size
        let model = AppModel(settings: settings)
        let snapshot = NowPlayingSnapshot(
            track: track ?? PreviewData.track, playback: PreviewData.playing, sourceID: "preview")
        model.store.looksUpMissingArtwork = false
        model.store.inject(snapshot)
        model.startDerivedState()
        model.updateArtwork(force: true)
        return model
    }
}

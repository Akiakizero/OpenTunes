// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation
import Sparkle

/// Aggiornamenti automatici con Sparkle 2: feed `appcast.xml` allegato all'ultima release di GitHub,
/// firmato con EdDSA (la chiave pubblica è nell'Info.plist, quella privata solo nei secret della CI).
///
/// Senza chiave pubblica (build locali e di sviluppo) l'updater resta spento: Sparkle rifiuterebbe comunque
/// gli aggiornamenti non firmati, e così non compaiono errori all'avvio.
@Observable
@MainActor
final class Updater {
    @ObservationIgnored private let controller: SPUStandardUpdaterController?

    /// `false` nelle build senza chiave pubblica.
    let isAvailable: Bool

    init(bundle: Bundle = .main) {
        let key = (bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        isAvailable = !key.isEmpty
        controller = isAvailable
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        automaticallyChecks = controller?.updater.automaticallyChecksForUpdates ?? false
    }

    /// Controllo automatico in background (Sparkle salva la scelta nelle sue preferenze).
    var automaticallyChecks: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    var canCheck: Bool { controller?.updater.canCheckForUpdates ?? false }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

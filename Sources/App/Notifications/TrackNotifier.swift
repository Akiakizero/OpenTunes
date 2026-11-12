// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MediaCore
import UserNotifications

/// Notifica di sistema al cambio brano, con la copertina come allegato.
@MainActor
final class TrackNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let model: AppModel
    private let center = UNUserNotificationCenter.current()
    private var authorizationRequested = false
    private static let identifier = "org.opentunes.track"

    init(model: AppModel) {
        self.model = model
        super.init()
        center.delegate = self
    }

    func trackChanged() {
        guard shouldNotify, let track = model.track else { return }
        let artworkPNG = model.artwork.flatMap(Self.pngData)
        let title = track.title
        let subtitle = [track.artist, track.album].compactMap { $0 }.joined(separator: " — ")
        let player = model.player?.name
        Task {
            guard await ensureAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = subtitle
            if let player { content.body = player }
            if let artworkPNG, let attachment = Self.attachment(artworkPNG) {
                content.attachments = [attachment]
            }
            // Stesso identificativo: la notifica nuova sostituisce la precedente invece di accumularsi.
            let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil)
            try? await center.add(request)
        }
    }

    private var shouldNotify: Bool {
        switch model.settings.notificationMode {
        case .off: false
        case .always: true
        case .whenFloatingHidden: !model.settings.floatingVisible
        }
    }

    /// Chiede l'autorizzazione la prima volta che serve davvero (cioè con le notifiche attive).
    private func ensureAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            guard !authorizationRequested else { return false }
            authorizationRequested = true
            return (try? await center.requestAuthorization(options: [.alert])) ?? false
        default: return false
        }
    }

    private static func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func attachment(_ png: Data) -> UNNotificationAttachment? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("opentunes-artwork-\(UUID().uuidString).png")
        guard (try? png.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "artwork", url: url)
    }

    // Mostra il banner anche quando l'app è attiva (es. popover aperto).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Punto d'ingresso: app AppKit da menu bar (`LSUIElement`), le viste sono SwiftUI.
@main
enum OpenTunesApp {
    static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.run()
        }
    }
}

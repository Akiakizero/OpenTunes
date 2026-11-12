// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

private final class BundleToken {}

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: name])
        }
        return try Data(contentsOf: url)
    }
}

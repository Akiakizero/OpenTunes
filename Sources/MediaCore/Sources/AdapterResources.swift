// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Percorsi assoluti delle risorse di mediaremote-adapter incluse nel bundle.
public struct AdapterResources: Sendable, Equatable {
    public static let directoryName = "MediaRemoteAdapter"
    public static let perl = URL(fileURLWithPath: "/usr/bin/perl")

    public let script: URL
    public let framework: URL
    public let testClient: URL

    public init(script: URL, framework: URL, testClient: URL) {
        self.script = script
        self.framework = framework
        self.testClient = testClient
    }

    /// Cerca in `<bundle>/Contents/Resources/MediaRemoteAdapter/`.
    public static func inBundle(_ bundle: Bundle = .main) -> AdapterResources? {
        guard let base = bundle.resourceURL?.appendingPathComponent(directoryName, isDirectory: true) else {
            return nil
        }
        return inDirectory(base)
    }

    public static func inDirectory(_ base: URL) -> AdapterResources? {
        let resources = AdapterResources(
            script: base.appendingPathComponent("mediaremote-adapter.pl"),
            framework: base.appendingPathComponent("MediaRemoteAdapter.framework", isDirectory: true),
            testClient: base.appendingPathComponent("MediaRemoteAdapterTestClient"))
        let fm = FileManager.default
        guard fm.fileExists(atPath: resources.script.path),
              fm.fileExists(atPath: resources.framework.path),
              fm.isExecutableFile(atPath: resources.testClient.path)
        else { return nil }
        return resources
    }

    /// Argomenti per `/usr/bin/perl`: script, framework, test client, comando.
    public func arguments(_ command: [String]) -> [String] {
        [script.path, framework.path, testClient.path] + command
    }
}

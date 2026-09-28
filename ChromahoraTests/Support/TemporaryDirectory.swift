//
//  TemporaryDirectory.swift
//  ChromahoraTests
//

import Foundation

/// A directory of its own under the temporary directory, removed with its contents when the
/// last reference goes. Swift Testing makes a suite instance for each test and drops it after,
/// so a suite holding one cleans up after every test; the simulator doesn't empty `tmp` between runs.
final class TemporaryDirectory: Sendable {
    let url: URL

    /// `name` starts the directory's name, so a leftover one says which suite made it.
    init(_ name: String) {
        url = URL.temporaryDirectory.appending(path: "\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

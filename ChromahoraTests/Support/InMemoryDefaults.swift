//
//  InMemoryDefaults.swift
//  ChromahoraTests
//

import Foundation

/// Defaults held in memory for as long as the instance lives. A real suite leaves its plist
/// in the test host's preferences on every run: cfprefsd writes it back, empty, even after
/// `removePersistentDomain` and deleting the file. Unchecked, since `DevicePlaceProvider` and its
/// tests only reach it from the main actor.
final class InMemoryDefaults: UserDefaults, @unchecked Sendable {
    private var values: [String: Any] = [:]

    override func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        values[defaultName] = nil
    }
}

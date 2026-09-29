//
//  AppGroup.swift
//  Chromahora
//

import Foundation

/// The container the app shares with its widgets, so they read the sun times, forecasts, last
/// fix and town name the app already has rather than asking for them again.
nonisolated enum AppGroup {
    static let identifier = "group.com.afollestad.Chromahora"

    /// Defaults the app and its widgets share. A build without the group's entitlement gets a
    /// suite private to its process, which only stops the sharing.
    static let defaults = UserDefaults(suiteName: identifier) ?? .standard

    /// Caches in the shared container, where the system can still purge them like the app's
    /// own. The app's own Caches without the entitlement.
    static var cachesDirectory: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)?
            .appending(path: "Library/Caches", directoryHint: .isDirectory)
            ?? .cachesDirectory
    }
}

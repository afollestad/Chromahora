//
//  StoredPlaceName.swift
//  Chromahora
//

import Foundation

/// Identifies a place by its rounded coordinates alone, like the caches.
nonisolated struct PlaceCell: Hashable, Codable, Sendable {
    let latitudeTenths: Int
    let longitudeTenths: Int

    init(_ place: Place) {
        latitudeTenths = place.latitudeTenths
        longitudeTenths = place.longitudeTenths
    }
}

/// The town the device's newest place lies in, kept so a relaunch names it at once, even
/// offline, and so the widgets name it without a lookup of their own.
nonisolated struct StoredPlaceName: Codable, Equatable, Sendable {
    private static let storageKey = "lastDevicePlaceName"

    let cell: PlaceCell
    let name: String

    static func read(from defaults: UserDefaults) -> StoredPlaceName? {
        defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(StoredPlaceName.self, from: $0) }
    }

    /// The stored town, if it was found for `place`'s cell. Nil for a chosen place, which has
    /// its own name, and for a time zone's city, which the zone names.
    static func name(for place: Place, in defaults: UserDefaults) -> String? {
        guard case .device = place.source, let stored = read(from: defaults), stored.cell == PlaceCell(place) else {
            return nil
        }
        return stored.name
    }

    func write(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

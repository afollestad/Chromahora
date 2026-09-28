//
//  RecentPlaces.swift
//  Chromahora
//

import Foundation
import Observation

/// The last few places the person chose, newest first, which the location sheet lists. They stay
/// on the device, with coordinates rounded like every place's. Built once and shared by every
/// window, so a place chosen in one is listed in the others.
@Observable
final class RecentPlaces {
    /// Enough to hop between a trip's spots without scrolling the sheet, and few enough that
    /// `ForecastCache` keeps a forecast for each beside the device's.
    static let capacity = 5

    private static let storageKey = "recentPlaces"

    private(set) var places: [Place]
    private let defaults: UserDefaults?

    /// Nil `defaults` keeps them only in memory, for previews and snapshots.
    init(defaults: UserDefaults? = .standard, places: [Place] = []) {
        self.defaults = defaults
        let stored = defaults?.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode([Place].self, from: $0) }
        self.places = stored ?? places
    }

    /// Puts `place` first, moving it up if it's listed already, and lets the oldest go past
    /// `capacity`. Only chosen places are kept, since the device's is always in the sheet.
    func add(_ place: Place) {
        guard case .chosen = place.source else {
            return
        }
        places.removeAll { $0 == place }
        places.insert(place, at: 0)
        places.removeLast(max(0, places.count - Self.capacity))
        save()
    }

    func clear() {
        places = []
        save()
    }

    private func save() {
        guard let defaults else {
            return
        }
        if places.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else if let data = try? JSONEncoder().encode(places) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

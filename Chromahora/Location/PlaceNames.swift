//
//  PlaceNames.swift
//  Chromahora
//

import Foundation
import Observation

/// The town each place the device is found in lies in, for the title. Each is looked up once,
/// and the last is kept, so a relaunch names it at once, even offline. Built once and shared by
/// every window, which then share their lookups too.
@Observable
final class PlaceNames {
    /// Identifies a place by its rounded coordinates alone, like the caches.
    private struct Cell: Hashable, Codable {
        let latitudeTenths: Int
        let longitudeTenths: Int

        init(_ place: Place) {
            latitudeTenths = place.latitudeTenths
            longitudeTenths = place.longitudeTenths
        }
    }

    /// A town and the cell it was found for.
    private struct StoredName: Codable {
        let cell: Cell
        let name: String
    }

    private static let storageKey = "lastDevicePlaceName"

    private var names: [Cell: String] = [:]
    /// Lookups still out, which later calls join, so two windows showing one place ask once. Each
    /// runs in a task no caller owns, so a caller cancelled as the place's lookup restarts
    /// doesn't throw away the answer the next caller waits for.
    @ObservationIgnored private var lookups: [Cell: Task<String?, Never>] = [:]
    /// The device's newest place, whose name alone is kept for the next launch, so a slower
    /// lookup for a place the device has left can't replace it.
    @ObservationIgnored private var latestCell: Cell?
    private let search: any PlaceSearch
    private let defaults: UserDefaults?

    /// Nil `defaults` keeps names only in memory, for previews and snapshots.
    init(search: any PlaceSearch, defaults: UserDefaults? = .standard) {
        self.search = search
        self.defaults = defaults
        if let stored = defaults?.data(forKey: Self.storageKey).flatMap({ try? JSONDecoder().decode(StoredName.self, from: $0) }) {
            names[stored.cell] = stored.name
        }
    }

    /// The town a device place lies in, once found. Nil for a chosen place, which has its own
    /// name, and for a time zone's city, which the zone names.
    func name(for place: Place?) -> String? {
        guard let place, case .device = place.source else {
            return nil
        }
        return names[Cell(place)]
    }

    /// Looks up the town a device place lies in, unless it's known, joining a lookup already out.
    /// A failure leaves it unnamed, so a later call asks again.
    func load(_ place: Place) async {
        guard case .device = place.source else {
            return
        }
        let cell = Cell(place)
        latestCell = cell
        guard names[cell] == nil else {
            return
        }
        let lookup = lookups[cell] ?? Task { [search] in
            try? await search.townName(of: place)
        }
        lookups[cell] = lookup
        let found = await lookup.value
        if lookups[cell] == lookup {
            lookups[cell] = nil
        }
        guard let name = found else {
            return
        }
        names[cell] = name
        if cell == latestCell, let data = try? JSONEncoder().encode(StoredName(cell: cell, name: name)) {
            defaults?.set(data, forKey: Self.storageKey)
        }
    }
}

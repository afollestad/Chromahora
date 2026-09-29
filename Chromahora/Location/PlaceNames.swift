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
    /// What a lookup found: a town, none at all, or nothing yet, as when offline.
    private enum Lookup {
        case named(String)
        case townless
        case failed
    }

    /// How long a lookup may take. A slow network answers within a few seconds, and one that hasn't
    /// in twenty won't, while waiting on would keep later lookups for the place joined to it.
    static let lookupTimeout: Duration = .seconds(20)

    private var names: [PlaceCell: String] = [:]
    /// Places a finished lookup found in no town, such as out at sea, which this session doesn't
    /// ask about again.
    @ObservationIgnored private var townless: Set<PlaceCell> = []
    /// Lookups still out, which later calls join, so two windows showing one place ask once. Each
    /// runs in a task no caller owns, so a caller cancelled as the place's lookup restarts
    /// doesn't throw away the answer the next caller waits for.
    @ObservationIgnored private var lookups: [PlaceCell: Task<Lookup, Never>] = [:]
    /// The device's newest place, whose name alone is kept for the next launch, so a slower
    /// lookup for a place the device has left can't replace it.
    @ObservationIgnored private var latestCell: PlaceCell?
    private let search: any PlaceSearch
    private let defaults: UserDefaults?
    /// Waits out `lookupTimeout`, and tests replace it so they never wait for real.
    private let sleep: @Sendable (Duration) async throws -> Void

    /// Nil `defaults` keeps names only in memory, for previews and snapshots. The shared
    /// defaults otherwise, where the widgets read the name too.
    init(
        search: any PlaceSearch,
        defaults: UserDefaults? = AppGroup.defaults,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.search = search
        self.defaults = defaults
        self.sleep = sleep
        if let stored = defaults.flatMap(StoredPlaceName.read(from:)) {
            names[stored.cell] = stored.name
        }
    }

    /// The town a device place lies in, once found. Nil for a chosen place, which has its own
    /// name, and for a time zone's city, which the zone names.
    func name(for place: Place?) -> String? {
        guard let place, case .device = place.source else {
            return nil
        }
        return names[PlaceCell(place)]
    }

    /// Looks up the town a device place lies in, unless it's known, joining a lookup already out.
    /// A failure or a timeout leaves it unnamed, so a later call asks again.
    func load(_ place: Place) async {
        guard case .device = place.source else {
            return
        }
        let cell = PlaceCell(place)
        latestCell = cell
        guard names[cell] == nil, !townless.contains(cell) else {
            return
        }
        let lookup = lookups[cell] ?? Task { [search, sleep] in
            await Self.lookUp(place, in: search, sleep: sleep)
        }
        lookups[cell] = lookup
        let found = await lookup.value
        if lookups[cell] == lookup {
            lookups[cell] = nil
        }
        switch found {
        case .named(let name):
            names[cell] = name
            if cell == latestCell, let defaults {
                StoredPlaceName(cell: cell, name: name).write(to: defaults)
            }
        case .townless:
            townless.insert(cell)
        case .failed:
            break
        }
    }

    /// Asks `search` for the town `place` lies in, giving up after `lookupTimeout`.
    private static func lookUp(
        _ place: Place,
        in search: any PlaceSearch,
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) async -> Lookup {
        let lookup = Task {
            do {
                return try await search.townName(of: place).map(Lookup.named) ?? .townless
            } catch {
                return .failed
            }
        }
        let timeout = Task {
            try await sleep(lookupTimeout)
            lookup.cancel()
        }
        let found = await lookup.value
        timeout.cancel()
        return found
    }
}

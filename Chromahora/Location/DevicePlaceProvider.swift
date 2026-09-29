//
//  DevicePlaceProvider.swift
//  Chromahora
//

import CoreLocation
import Foundation

/// What a location source reports, reduced to what placing the device needs.
nonisolated enum LocationUpdate: Equatable, Sendable {
    /// The permission prompt is up, which can take as long as the person likes.
    case awaitingPermission
    /// Location is off for the app or the device.
    case denied
    /// Permission is settled, but there's no fix yet.
    case noFix
    /// A fix, and when it was taken, which a cached one reports as earlier than now.
    case fix(latitude: Double, longitude: Double, takenAt: Date = .now)
}

/// A stream of location updates, which ends when the caller stops listening.
/// A protocol so tests can script the updates.
protocol LocationSource {
    func updates() -> AsyncStream<LocationUpdate>
}

/// Places the device by its location, asking for When In Use permission the first time.
///
/// Without a fix, it falls back to the last fix taken in the same time zone, then to the
/// time zone's city. Fixes from another zone are skipped, since `tz` windowing would
/// then describe a day that isn't the one on the device's clock. Denied location forgets the
/// last fix, since a place the person has since withheld mustn't go on standing in for the
/// device, nor on to the services asked about it.
struct DevicePlaceProvider: PlaceProvider {
    /// Once permission is settled, how long the app waits for a fix before falling back.
    static let fixTimeout: Duration = .seconds(10)
    /// A fix nearer than this to the stored place keeps it. Every fix lies within 7.9 km of its
    /// cell's center, so a couple of km more stops a fix wavering over an edge or corner from
    /// swapping places, which reloads the day and spends a forecast request. It shifts sun times
    /// by about a minute, even at 60° N in June.
    static let moveThreshold: CLLocationDistance = 10_000

    private static let storageKey = "lastDevicePlace"

    /// A device fix, the zone the device was in when it was taken, and when that was. Nil for
    /// a fix stored before times were, which any new fix may replace.
    private struct StoredFix: Codable {
        let place: Place
        let timeZone: String
        var takenAt: Date?
    }

    /// What asking the source came to.
    private enum Outcome {
        case fix(CLLocation)
        case denied
        /// No fix in time, or the source ended without one.
        case none
    }

    var source: any LocationSource
    var fallback: any PlaceProvider = TimeZonePlaceProvider()
    /// Shared with the widgets, so the app and they start from the last fix either took.
    var defaults: UserDefaults = AppGroup.defaults
    /// Once permission is settled, how long to wait for a fix. A widget waits less than the app,
    /// since its reload runs on a time budget and the stored fix answers just as well.
    var timeout: Duration = Self.fixTimeout
    /// Waits out `timeout`, and tests replace it so they never wait for real.
    var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    func lastKnownPlace(in timeZone: TimeZone) -> Place? {
        storedFix(in: timeZone)?.place ?? fallback.lastKnownPlace(in: timeZone)
    }

    func currentPlace(in timeZone: TimeZone) async throws -> Place {
        switch await fix() {
        case .fix(let fix):
            let stored = storedFix(in: timeZone)
            // A widget's fix can come from CoreLocation's cache, older than one the app has since
            // stored, and an older fix never replaces a newer one.
            if let stored, let takenAt = stored.takenAt, fix.timestamp < takenAt {
                return stored.place
            }
            // Measured from the stored place's center, not the last fix, so small moves can't add up.
            if let stored, CLLocation(latitude: stored.place.latitude, longitude: stored.place.longitude).distance(from: fix) < Self.moveThreshold {
                // Noted as newer, so an older fix from elsewhere can't replace it after.
                store(stored.place, takenAt: fix.timestamp, in: timeZone)
                return stored.place
            }
            let place = Place(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude, source: .device)
            store(place, takenAt: fix.timestamp, in: timeZone)
            return place
        case .denied:
            forget()
            try Task.checkCancellation()
            return try await fallback.currentPlace(in: timeZone)
        case .none:
            // A cancelled wait isn't an answer, so it mustn't replace a device place with the fallback.
            try Task.checkCancellation()
            if let stored = storedFix(in: timeZone) {
                return stored.place
            }
            return try await fallback.currentPlace(in: timeZone)
        }
    }

    #if DEBUG
    /// Drops the stored fix, for the debug drawer.
    func forgetLastFix() {
        forget()
    }
    #endif

    /// The first fix, unrounded, with the time it was taken, or whether permission is denied.
    /// None if no fix arrives within `timeout` of permission settling.
    private func fix() async -> Outcome {
        let (settled, settle) = AsyncStream<Void>.makeStream()
        let updates = source.updates()
        return await withTaskGroup(of: Outcome.self) { group in
            group.addTask {
                for await update in updates {
                    switch update {
                    case .awaitingPermission:
                        continue
                    case .denied:
                        return .denied
                    case .noFix:
                        settle.yield()
                    case let .fix(latitude, longitude, takenAt):
                        return .fix(CLLocation(
                            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                            altitude: 0,
                            horizontalAccuracy: 0,
                            verticalAccuracy: -1,
                            timestamp: takenAt
                        ))
                    }
                }
                return .none
            }
            group.addTask { [sleep, timeout] in
                // Only a settled permission starts the clock, so a slow answer to the prompt isn't a timeout.
                for await _ in settled {
                    try? await sleep(timeout)
                    return .none
                }
                return .none
            }
            let first = await group.next() ?? .none
            group.cancelAll()
            settle.finish()
            return first
        }
    }

    private func storedFix(in timeZone: TimeZone) -> StoredFix? {
        defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(StoredFix.self, from: $0) }
            .flatMap { $0.timeZone == timeZone.identifier ? $0 : nil }
    }

    private func store(_ place: Place, takenAt: Date, in timeZone: TimeZone) {
        if let data = try? JSONEncoder().encode(StoredFix(place: place, timeZone: timeZone.identifier, takenAt: takenAt)) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private func forget() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}

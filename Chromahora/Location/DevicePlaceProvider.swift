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
    case fix(latitude: Double, longitude: Double)
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
/// then describe a day that isn't the one on the device's clock.
struct DevicePlaceProvider: PlaceProvider {
    /// Once permission is settled, how long to wait for a fix before falling back.
    static let fixTimeout: Duration = .seconds(10)
    /// A fix nearer than this to the stored place keeps it. Every fix lies within 7.9 km of its
    /// cell's center, so a couple of km more stops a fix wavering over an edge or corner from
    /// swapping places, which reloads the day and spends a forecast request. It shifts sun times
    /// by about a minute, even at 60° N in June.
    static let moveThreshold: CLLocationDistance = 10_000

    private static let storageKey = "lastDevicePlace"

    /// A device fix and the zone the device was in when it was taken.
    private struct StoredFix: Codable {
        let place: Place
        let timeZone: String
    }

    var source: any LocationSource = CoreLocationSource()
    var fallback: any PlaceProvider = TimeZonePlaceProvider()
    var defaults: UserDefaults = .standard
    /// Waits out `fixTimeout`, and tests replace it so they never wait for real.
    var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    func lastKnownPlace(in timeZone: TimeZone) -> Place? {
        storedFix(in: timeZone) ?? fallback.lastKnownPlace(in: timeZone)
    }

    func currentPlace(in timeZone: TimeZone) async throws -> Place {
        if let fix = await fix() {
            // Measured from the stored place's center, not the last fix, so small moves can't add up.
            if let stored = storedFix(in: timeZone),
               CLLocation(latitude: stored.latitude, longitude: stored.longitude).distance(from: fix) < Self.moveThreshold {
                return stored
            }
            let place = Place(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude, source: .device)
            store(place, in: timeZone)
            return place
        }
        // A cancelled wait isn't an answer, so it mustn't replace a device place with the fallback.
        try Task.checkCancellation()
        if let place = storedFix(in: timeZone) {
            return place
        }
        return try await fallback.currentPlace(in: timeZone)
    }

    #if DEBUG
    /// Drops the stored fix, for the debug drawer.
    func forgetLastFix() {
        defaults.removeObject(forKey: Self.storageKey)
    }
    #endif

    /// The first fix, unrounded, or nil if permission is denied or no fix arrives within
    /// `fixTimeout` of permission settling.
    private func fix() async -> CLLocation? {
        let (settled, settle) = AsyncStream<Void>.makeStream()
        let updates = source.updates()
        return await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                for await update in updates {
                    switch update {
                    case .awaitingPermission:
                        continue
                    case .denied:
                        return nil
                    case .noFix:
                        settle.yield()
                    case let .fix(latitude, longitude):
                        return CLLocation(latitude: latitude, longitude: longitude)
                    }
                }
                return nil
            }
            group.addTask { [sleep] in
                // Only a settled permission starts the clock, so a slow answer to the prompt isn't a timeout.
                for await _ in settled {
                    try? await sleep(Self.fixTimeout)
                    return nil
                }
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            settle.finish()
            return first
        }
    }

    private func storedFix(in timeZone: TimeZone) -> Place? {
        defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(StoredFix.self, from: $0) }
            .flatMap { $0.timeZone == timeZone.identifier ? $0.place : nil }
    }

    private func store(_ place: Place, in timeZone: TimeZone) {
        if let data = try? JSONEncoder().encode(StoredFix(place: place, timeZone: timeZone.identifier)) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

/// CoreLocation's live updates, under a When In Use service session, which shows the
/// permission prompt the first time.
struct CoreLocationSource: LocationSource {
    func updates() -> AsyncStream<LocationUpdate> {
        AsyncStream { continuation in
            let task = Task {
                // Held for as long as updates are wanted.
                let session = CLServiceSession(authorization: .whenInUse)
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        continuation.yield(LocationUpdate(update))
                    }
                } catch {
                    // The stream ends either way.
                }
                session.invalidate()
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private extension LocationUpdate {
    init(_ update: CLLocationUpdate) {
        if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
            self = .denied
        } else if update.authorizationRequestInProgress {
            self = .awaitingPermission
        } else if let coordinate = update.location?.coordinate {
            self = .fix(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } else {
            self = .noFix
        }
    }
}

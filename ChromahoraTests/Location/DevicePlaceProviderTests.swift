//
//  DevicePlaceProviderTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// A wait that never ends would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct DevicePlaceProviderTests {
    private let source = StubLocationSource()
    private let fallback = StubPlaceProvider()
    private let defaults = InMemoryDefaults()
    private let chicago = TimeZone(identifier: "America/Chicago") ?? .gmt
    private let tokyo = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
    private let sanFrancisco = Place(latitude: 37.77, longitude: -122.42, source: .device)
    private let timeZoneCity = Place(latitude: 41.85, longitude: -87.65, source: .timeZone("America/Chicago"))

    init() {
        fallback.lastKnown = timeZoneCity
        fallback.current = timeZoneCity
    }

    /// `timeoutSleep` stands in for the fix timeout, which by default passes at once.
    private func makeProvider(timeoutSleep: @escaping @Sendable (Duration) async throws -> Void = { _ in }) -> DevicePlaceProvider {
        DevicePlaceProvider(source: source, fallback: fallback, defaults: defaults, sleep: timeoutSleep)
    }

    @Test func aFixPlacesTheDeviceAndIsRemembered() async throws {
        source.script = [.awaitingPermission, .fix(latitude: 37.77, longitude: -122.42)]
        let provider = makeProvider()

        #expect(try await provider.currentPlace(in: chicago) == sanFrancisco)
        #expect(provider.lastKnownPlace(in: chicago) == sanFrancisco)
    }

    /// A fix wavering over a cell's edge would otherwise reload the day and spend a forecast request.
    @Test func aNearbyFixKeepsTheStoredPlace() async throws {
        source.script = [.fix(latitude: 37.77, longitude: -122.42)]
        _ = try await makeProvider().currentPlace(in: chicago)

        // Rounds to the next cell south, about 7 km from the stored place's center.
        source.script = [.fix(latitude: 37.74, longitude: -122.42)]
        #expect(try await makeProvider().currentPlace(in: chicago) == sanFrancisco)
        #expect(makeProvider().lastKnownPlace(in: chicago) == sanFrancisco)
    }

    @Test func aDistantFixReplacesTheStoredPlace() async throws {
        source.script = [.fix(latitude: 37.77, longitude: -122.42)]
        _ = try await makeProvider().currentPlace(in: chicago)

        source.script = [.fix(latitude: 37.34, longitude: -121.89)]
        let sanJose = Place(latitude: 37.34, longitude: -121.89, source: .device)
        #expect(try await makeProvider().currentPlace(in: chicago) == sanJose)
        #expect(makeProvider().lastKnownPlace(in: chicago) == sanJose)
    }

    /// Windowed to another zone, a remembered fix would describe a day off the device's clock.
    @Test func aFixFromAnotherZoneIsntReused() async throws {
        source.script = [.fix(latitude: 37.77, longitude: -122.42)]
        _ = try await makeProvider().currentPlace(in: chicago)

        #expect(makeProvider().lastKnownPlace(in: tokyo) == timeZoneCity)
    }

    /// A place the person has since withheld mustn't go on standing in for the device.
    @Test func deniedForgetsTheLastFix() async throws {
        source.script = [.fix(latitude: 37.77, longitude: -122.42)]
        _ = try await makeProvider().currentPlace(in: chicago)

        source.script = [.denied]
        #expect(try await makeProvider().currentPlace(in: chicago) == timeZoneCity)
        #expect(makeProvider().lastKnownPlace(in: chicago) == timeZoneCity)
    }

    /// No fix in time says nothing about permission, so the last fix in the zone stands.
    @Test func noFixFallsBackToTheLastFixInTheZone() async throws {
        source.script = [.fix(latitude: 37.77, longitude: -122.42)]
        _ = try await makeProvider().currentPlace(in: chicago)

        source.script = [.noFix]
        #expect(try await makeProvider().currentPlace(in: chicago) == sanFrancisco)
        #expect(try await makeProvider().currentPlace(in: tokyo) == timeZoneCity)
    }

    /// A widget's fix can come from CoreLocation's cache, older than the app's stored one.
    @Test func anOlderFixNeverReplacesANewerOne() async throws {
        let now = Date.now
        source.script = [.fix(latitude: 37.77, longitude: -122.42, takenAt: now)]
        _ = try await makeProvider().currentPlace(in: chicago)

        source.script = [.fix(latitude: 37.34, longitude: -121.89, takenAt: now.addingTimeInterval(-600))]
        #expect(try await makeProvider().currentPlace(in: chicago) == sanFrancisco)

        source.script = [.fix(latitude: 37.34, longitude: -121.89, takenAt: now.addingTimeInterval(60))]
        #expect(try await makeProvider().currentPlace(in: chicago) == Place(latitude: 37.34, longitude: -121.89, source: .device))
    }

    /// A fix nearby keeps the stored place but its newer time, so a stale fix from elsewhere
    /// can't replace it after.
    @Test func aNearbyFixRefreshesTheStoredTime() async throws {
        let now = Date.now
        source.script = [.fix(latitude: 37.77, longitude: -122.42, takenAt: now.addingTimeInterval(-3600))]
        _ = try await makeProvider().currentPlace(in: chicago)
        source.script = [.fix(latitude: 37.74, longitude: -122.42, takenAt: now)]
        _ = try await makeProvider().currentPlace(in: chicago)

        source.script = [.fix(latitude: 37.34, longitude: -121.89, takenAt: now.addingTimeInterval(-600))]
        #expect(try await makeProvider().currentPlace(in: chicago) == sanFrancisco)
    }

    /// A fix stored before fixes carried their time still loads, and any new fix may replace it.
    @Test func aFixStoredWithoutATimeStillLoads() async throws {
        let stored = #"{"place":{"latitudeTenths":378,"longitudeTenths":-1224,"source":{"device":{}}},"timeZone":"America/Chicago"}"#
        defaults.set(Data(stored.utf8), forKey: "lastDevicePlace")
        #expect(makeProvider().lastKnownPlace(in: chicago) == sanFrancisco)

        source.script = [.fix(latitude: 37.34, longitude: -121.89, takenAt: .distantPast)]
        #expect(try await makeProvider().currentPlace(in: chicago) == Place(latitude: 37.34, longitude: -121.89, source: .device))
    }

    @Test func noFixInTimeFallsBackToTheTimeZone() async throws {
        source.script = [.noFix]

        #expect(try await makeProvider().currentPlace(in: chicago) == timeZoneCity)
    }

    /// A widget passes a shorter wait, since its reload runs on a budget.
    @Test func noFixWaitsOutTheGivenTimeout() async throws {
        source.script = [.noFix]
        let (waits, recordWait) = AsyncStream<Duration>.makeStream()
        var provider = makeProvider { recordWait.yield($0) }
        provider.timeout = .seconds(5)

        #expect(try await provider.currentPlace(in: chicago) == timeZoneCity)
        recordWait.finish()
        #expect(await waits.reduce(into: []) { $0.append($1) } == [.seconds(5)])
    }

    /// The prompt can stay up as long as the person likes, so it never times out, and
    /// cancelling the wait throws rather than settling for the fallback.
    @Test func awaitingPermissionWaitsUntilCancelled() async throws {
        source.script = [.awaitingPermission]
        let provider = makeProvider { _ in
            Issue.record("Timed out while the permission prompt was up")
        }

        let locating = Task { try await provider.currentPlace(in: chicago) }
        locating.cancel()

        await #expect(throws: CancellationError.self) {
            try await locating.value
        }
    }

    @Test func withNoFixAndNoCityItFails() async throws {
        source.script = [.denied]
        fallback.error = PlaceError.unavailable(timeZone: "GMT")

        await #expect(throws: PlaceError.unavailable(timeZone: "GMT")) {
            try await makeProvider().currentPlace(in: .gmt)
        }
    }
}

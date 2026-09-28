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

    @Test func deniedFallsBackToTheLastFixInTheZone() async throws {
        source.script = [.fix(latitude: 37.77, longitude: -122.42)]
        _ = try await makeProvider().currentPlace(in: chicago)

        source.script = [.denied]
        #expect(try await makeProvider().currentPlace(in: chicago) == sanFrancisco)
        #expect(try await makeProvider().currentPlace(in: tokyo) == timeZoneCity)
    }

    @Test func noFixInTimeFallsBackToTheTimeZone() async throws {
        source.script = [.noFix]

        #expect(try await makeProvider().currentPlace(in: chicago) == timeZoneCity)
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

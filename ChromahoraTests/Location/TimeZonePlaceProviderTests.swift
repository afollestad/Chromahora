//
//  TimeZonePlaceProviderTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Reads the `zone.tab` and links bundled with the app, which also checks they ship.
@MainActor
struct TimeZonePlaceProviderTests {
    private let provider = TimeZonePlaceProvider()

    @Test func placesAZoneAtItsCity() throws {
        let chicago = try place(for: "America/Chicago")

        #expect(abs(chicago.latitude - 41.85) <= 0.05)
        #expect(abs(chicago.longitude - -87.65) <= 0.05)
        #expect(chicago.source == .timeZone("America/Chicago"))
    }

    /// `zone.tab` writes New York as `+404251-0740023`, with seconds.
    @Test func readsCoordinatesWithSeconds() throws {
        let newYork = try place(for: "America/New_York")

        #expect(newYork.latitude == 40.7)
        #expect(newYork.longitude == -74.0)
    }

    /// iOS can report `Asia/Calcutta`, which `zone.tab` lists as `Asia/Kolkata`.
    @Test func followsLegacyNamesToTheirZone() throws {
        let calcutta = try place(for: "Asia/Calcutta")

        #expect(calcutta.latitude == 22.5)
        #expect(calcutta.longitude == 88.4)
        #expect(calcutta.source == .timeZone("Asia/Calcutta"))
    }

    @Test func zonesWithoutACityHaveNoPlace() async throws {
        let gmt = try #require(TimeZone(identifier: "GMT"))

        #expect(provider.lastKnownPlace(in: gmt) == nil)
        await #expect(throws: PlaceError.unavailable(timeZone: "GMT")) {
            try await provider.currentPlace(in: gmt)
        }
    }

    @Test func roundingNeverSplitsZero() {
        let place = Place(latitude: -0.04, longitude: 0.04, source: .device)

        #expect(place.latitudeTenths == 0)
        #expect(place == Place(latitude: 0.04, longitude: -0.04, source: .device))
        #expect(!String(place.latitude).hasPrefix("-"))
    }

    @Test func summariesNameTheCity() {
        #expect(Place(latitude: 34, longitude: -118, source: .timeZone("America/Los_Angeles")).summary == "Near Los Angeles, from your time zone")
        #expect(Place(latitude: 34, longitude: -118, source: .device).summary == "At your location")
    }

    private func place(for identifier: String) throws -> Place {
        let timeZone = try #require(TimeZone(identifier: identifier))
        return try #require(provider.lastKnownPlace(in: timeZone))
    }
}

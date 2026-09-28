//
//  SnapshotTests+PlaceSearch.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
@testable import Chromahora

/// The location sheet, snapshotted directly rather than presented from the title. Its background
/// follows the color scheme, which the harness leaves to the simulator, so each pins light.
extension SnapshotTests {
    /// As it opens at the device's town, above two recent places.
    @Test func placeSearchRecents() async throws {
        let recents = RecentPlaces(defaults: nil, places: [MockPlaceSearch.kyoto, MockPlaceSearch.reykjavik])
        let chooser = PlaceChooser(search: MockPlaceSearch(), recents: recents) { _ in }
        await assertScreenSnapshot(of: sheet(PlaceSearchSheet(place: MockPlaceProvider.sanFrancisco, deviceName: "San Francisco", chooser: chooser)))
    }

    /// Suggestions for a query, whose first search runs as the sheet opens.
    @Test func placeSearchResults() async throws {
        await assertScreenSnapshot(of: sheet(PlaceSearchSheet(place: MockPlaceSearch.kyoto, deviceName: nil, chooser: .preview, query: "Yo")))
    }

    /// Offline, the search says so in place of suggestions.
    @Test func placeSearchOffline() async throws {
        let offline = MockPlaceSearch(failure: URLError(.notConnectedToInternet))
        let chooser = PlaceChooser(search: offline, recents: RecentPlaces(defaults: nil)) { _ in }
        let sheet = PlaceSearchSheet(place: MockPlaceProvider.sanFrancisco, deviceName: "San Francisco", chooser: chooser, query: "Yo")
        await assertScreenSnapshot(of: self.sheet(sheet))
    }

    /// The sheet has no text size cap, unlike the popovers, and the Apple Maps credit stacks when
    /// its line no longer fits. No recent places, so the credit stays in view.
    @Test func placeSearchAtLargestTextSize() async throws {
        let sheet = sheet(PlaceSearchSheet(place: MockPlaceProvider.sanFrancisco, deviceName: "San Francisco", chooser: .preview))
        await assertScreenSnapshot(of: sheet.environment(\.dynamicTypeSize, .accessibility5))
    }

    /// Only the time zone places the device, so the current location says so and links to Settings.
    @Test func placeSearchApproximate() async throws {
        let losAngeles = Place(latitude: 34.1, longitude: -118.2, source: .timeZone("America/Los_Angeles"))
        await assertScreenSnapshot(of: sheet(PlaceSearchSheet(place: losAngeles, deviceName: nil, chooser: .preview)))
    }

    private func sheet(_ sheet: PlaceSearchSheet) -> some View {
        sheet.environment(\.colorScheme, .light)
    }
}

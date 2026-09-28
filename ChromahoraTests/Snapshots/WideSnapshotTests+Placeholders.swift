//
//  WideSnapshotTests+Placeholders.swift
//  ChromahoraTests
//

import Testing
@testable import Chromahora

extension WideSnapshotTests {
    /// The dawn glow's note centers beside the panel, which offers only the calendar.
    @Test func loading() async throws {
        let noon = try june(12)
        await assertScreenSnapshot(of: screen(.loading(nil), selectedDate: noon, now: noon, place: MockPlaceProvider.sanFrancisco), on: .wide)
    }

    /// The panel's calendar is the way off a failed day, with the calendar button gone, and a
    /// place approximated from the time zone links to Settings.
    @Test func failedToLoad() async throws {
        let noon = try june(12)
        let place = Place(latitude: 34.1, longitude: -118.2, source: .timeZone("America/Los_Angeles"))
        await assertScreenSnapshot(of: screen(.failed(StubError()), selectedDate: noon, now: noon, place: place), on: .wide)
    }
}

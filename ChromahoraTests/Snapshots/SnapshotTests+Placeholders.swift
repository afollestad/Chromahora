//
//  SnapshotTests+Placeholders.swift
//  ChromahoraTests
//

import Testing
@testable import Chromahora

extension SnapshotTests {
    /// The dawn glow, which the harness's transaction stops at its end state: gold.
    @Test func loading() async throws {
        let noon = try time(12)
        await assertScreenSnapshot(of: screen(.loading(nil), selectedDate: noon, now: noon))
    }

    @Test func failedToLoad() async throws {
        let noon = try time(12)
        await assertScreenSnapshot(of: screen(.failed(StubError()), selectedDate: noon, now: noon))
    }

    /// Location is off and the zone has no city to stand in, so only Settings can help.
    @Test func locationNeeded() async throws {
        let noon = try time(12)
        await assertScreenSnapshot(of: screen(.failed(PlaceError.unavailable(timeZone: "GMT")), selectedDate: noon, now: noon))
    }
}

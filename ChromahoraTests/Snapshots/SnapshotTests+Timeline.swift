//
//  SnapshotTests+Timeline.swift
//  ChromahoraTests
//

import Testing

extension SnapshotTests {
    @Test func afternoon() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(16, 30)))
    }

    /// The timeline can't center this early, so it rests at midnight, with the
    /// navigation bar in its dark scheme over night.
    @Test func beforeDawn() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(3)))
    }

    /// Now lands two minutes after sunrise, so its label is pushed below Sunrise's.
    @Test func justAfterSunrise() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(7)))
    }

    /// With now on another day there's no now marker, and the timeline centers on daylight.
    @Test func anotherDay() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(day: 17, 9)))
    }
}

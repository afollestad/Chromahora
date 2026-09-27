//
//  SnapshotTests+Timeline.swift
//  ChromahoraTests
//

import SwiftUI
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

    /// The title sits about five hours above now, so these put it over the blend between
    /// blue and golden hour on either side of the bar's scheme flip, clear of its margin.
    @Test func titleOverDawnBeforeFlip() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(11, 35)))
    }

    @Test func titleOverDawnAfterFlip() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(11, 55)))
    }

    /// The labels stop growing at accessibility1, and phase labels that can land beside a
    /// marker drop their time range to fit.
    @Test func largestTextSize() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(7)).environment(\.dynamicTypeSize, .accessibility5))
    }

    /// With now on another day there's no now marker, and the timeline centers on daylight.
    @Test func anotherDay() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(day: 17, 9)))
    }
}

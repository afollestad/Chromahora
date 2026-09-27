//
//  SnapshotTests+Timeline.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
@testable import Chromahora

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

    // MARK: High-latitude days, on the dates their scenarios come from

    /// Reykjavík's December golden hour lasts all day and holds its color, with no daylight.
    @Test func allDayGolden() async throws {
        try await assertScreenSnapshot(of: timeline(.allDayGolden, now: time(month: 12, day: 21, 12)))
    }

    /// Trondheim's June night is golden hour, with no night or blue hour.
    @Test func goldenNight() async throws {
        try await assertScreenSnapshot(of: timeline(.goldenNight, now: time(month: 6, day: 21, 1)))
    }

    /// St. Petersburg's June blue hour runs past midnight at both ends. Near either end,
    /// the short cut-off phase's label slides clear of the bar and home indicator.
    @Test func blueHourPastMidnightAtStart() async throws {
        try await assertScreenSnapshot(of: timeline(.blueHourPastMidnight, now: time(month: 6, day: 21, 0, 5)))
    }

    @Test func blueHourPastMidnightAtEnd() async throws {
        try await assertScreenSnapshot(of: timeline(.blueHourPastMidnight, now: time(month: 6, day: 21, 23, 50)))
    }

    /// Tromsø's December twilight never reaches sunrise.
    @Test func polarTwilight() async throws {
        try await assertScreenSnapshot(of: timeline(.polarTwilight, now: time(month: 12, day: 10, 11, 30)))
    }

    /// A day in one phase labels it as lasting all day.
    @Test func midnightSun() async throws {
        try await assertScreenSnapshot(of: timeline(.midnightSun, now: time(month: 6, day: 21, 12)))
    }

    @Test func polarNight() async throws {
        try await assertScreenSnapshot(of: timeline(.polarNight, now: time(month: 12, day: 21, 12)))
    }
}

//
//  WideSnapshotTests+Timeline.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
@testable import Chromahora

extension WideSnapshotTests {
    /// The panel marks daylight as now, while the timeline's labels, lines and sources button
    /// keep clear of it. The panel's weather and its Apple Weather mark sit below the fold.
    @Test func afternoon() async throws {
        try await assertScreenSnapshot(of: timeline(now: june(16, 30), weather: WeatherSpell.mock(for: june(12))), on: .wide)
    }

    /// Night is now, under the bar's dark scheme.
    @Test func beforeDawn() async throws {
        try await assertScreenSnapshot(of: timeline(now: june(3)), on: .wide)
    }

    /// With now on another day, no phase is marked as now.
    @Test func anotherDay() async throws {
        try await assertScreenSnapshot(of: timeline(now: june(day: 22, 9)), on: .wide)
    }

    /// The timeline's labels stop growing at accessibility1 in the column beside the panel,
    /// and so does the panel's text, which wraps.
    @Test func largestTextSize() async throws {
        let timeline = try timeline(now: june(7), weather: WeatherSpell.mock(for: june(12)))
        await assertScreenSnapshot(of: timeline.environment(\.dynamicTypeSize, .accessibility5), on: .wide)
    }

    /// Longyearbyen's June: one phase all day with no duration, and no sunrise or sunset to list.
    @Test func midnightSun() async throws {
        try await assertScreenSnapshot(of: timeline(.midnightSun, now: june(12)), on: .wide)
    }

    /// St. Petersburg's June: the phases midnight cuts off give only their side on this day,
    /// with no duration.
    @Test func blueHourPastMidnightAtEnd() async throws {
        try await assertScreenSnapshot(of: timeline(.blueHourPastMidnight, now: june(23, 50)), on: .wide)
    }

    /// Kyoto, chosen from another zone: the title names it, and the panel's calendar marks the
    /// day on Kyoto's clock. Early morning there is still the day before across the Americas, so a
    /// title or calendar reading the device's zone would name June 20.
    @Test func chosenPlace() async throws {
        let kyoto = try calendar(in: "Asia/Tokyo")
        let now = try june(7, in: kyoto)
        await assertScreenSnapshot(of: timeline(of: SolarDay.mock(for: now, calendar: kyoto), now: now, place: MockPlaceSearch.kyoto), on: .wide)
    }
}

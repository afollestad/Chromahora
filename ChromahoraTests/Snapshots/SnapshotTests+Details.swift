//
//  SnapshotTests+Details.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
@testable import Chromahora

extension SnapshotTests {
    /// The page beside the timeline for `scenario` on the day containing `now`, with the mock
    /// forecast's spells and `hours` for that day.
    private func details(_ scenario: MockScenario = .typical, now: Date, hours: [SkyHour]? = nil) -> some View {
        let day = SolarDay.mock(scenario, for: now)
        return screen(
            .loaded(day),
            selectedDate: day.dayStart,
            now: now,
            weather: WeatherSpell.mock(for: now),
            hours: hours ?? SkyHour.mock(for: now),
            initialPane: .details
        )
    }

    /// Daylight is now, and the rows' details sit on the trailing side, with the sky of the
    /// timeline's afternoon behind the card and the second dot marked under the sources button.
    @Test func detailsThisAfternoon() async throws {
        try await assertScreenSnapshot(of: details(now: time(16, 30)))
    }

    /// Before dawn the timeline rests at midnight, so night behind the title darkens the bar,
    /// while the morning under the sources button lightens it and the dots.
    @Test func detailsBeforeDawn() async throws {
        try await assertScreenSnapshot(of: details(now: time(3)))
    }

    /// The details stop growing at accessibility1, and each name keeps its line while its details wrap.
    @Test func detailsAtLargestTextSize() async throws {
        try await assertScreenSnapshot(of: details(now: time(16, 30)).environment(\.dynamicTypeSize, .accessibility5))
    }

    /// Longyearbyen's June: one phase and no sunrise or sunset, so the moon and the weather's
    /// rows come into view, and a sky that never gets fully dark has no dark sky.
    @Test func detailsInMidnightSun() async throws {
        try await assertScreenSnapshot(of: details(.midnightSun, now: time(month: 6, day: 21, 12)))
    }

    /// Longyearbyen's December: with neither a moonrise nor a moonset, where the moon is is
    /// unknown, so there's no dark sky row. Without a sunrise or sunset there are no sky rows,
    /// and with the UV index at 0 all day, no UV row.
    @Test func detailsInPolarNight() async throws {
        let now = try time(month: 12, day: 21, 12)
        let sunless = SkyHour.mock(for: now).map { hour in
            SkyHour(
                date: hour.date,
                uvIndex: 0,
                lowCloud: hour.lowCloud,
                midCloud: hour.midCloud,
                highCloud: hour.highCloud,
                visibility: hour.visibility
            )
        }
        await assertScreenSnapshot(of: details(.polarNight, now: now, hours: sunless))
    }
}

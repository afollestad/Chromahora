//
//  WidgetRowsTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Which golden and blue hours the widgets list beside a sunrise or sunset.
@MainActor
struct WidgetRowsTests {
    /// GMT, so the mock days' clock times read the same wherever the tests run.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// A time in September 2026, on the 16th unless given another day.
    private func time(day: Int = 16, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute)))
    }

    /// Two days of `scenario` from September 16.
    private func run(_ scenario: MockScenario) throws -> DayRun {
        DayRun(
            SolarDay.mock(scenario, for: try time(12), calendar: calendar),
            then: [SolarDay.mock(scenario, for: try time(day: 17, 12), calendar: calendar)]
        )
    }

    private func starts(_ segments: [DaySegment]) -> [Date] {
        segments.map(\.interval.start)
    }

    @Test func aSunsetListsItsGoldenHourThenTheBlueHourAfter() throws {
        let run = try run(.typical)
        let sunset = try #require(run.days[0].events.first { $0.kind == .sunset })

        let rows = SunTimesView.magicHours(around: sunset, in: run)

        #expect(rows.map(\.phase) == [.goldenHour, .blueHour])
        #expect(starts(rows) == [try time(18, 5), try time(19, 10)])
    }

    @Test func aSunriseListsTheBlueHourBeforeThenItsGoldenHour() throws {
        let run = try run(.typical)
        let sunrise = try #require(run.days[0].events.first { $0.kind == .sunrise })

        let rows = SunTimesView.magicHours(around: sunrise, in: run)

        #expect(rows.map(\.phase) == [.blueHour, .goldenHour])
        #expect(starts(rows) == [try time(6, 12), try time(6, 38)])
    }
}

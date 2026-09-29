//
//  WidgetRowsTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Which golden and blue hours the widgets list beside a sunrise or sunset, and at either end of a day.
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

    @Test func aTypicalDayPartsAtNoon() throws {
        let run = try run(.typical)

        let ends = MorningEveningView.ends(of: run.days[0], in: run)

        #expect(starts(ends.morning.magicHours) == [try time(6, 12), try time(6, 38)])
        #expect(starts(ends.evening.magicHours) == [try time(18, 5), try time(19, 10)])
        #expect(ends.morning.event?.kind == .sunrise)
        #expect(ends.evening.event?.kind == .sunset)
    }

    /// The blue hour that ends at 12:10 AM began the evening before, and the evening's own runs
    /// on into the next day whole.
    @Test func aBlueHourAcrossMidnightBelongsToTheEveningItStarts() throws {
        let run = try run(.blueHourPastMidnight)

        let ends = MorningEveningView.ends(of: run.days[0], in: run)

        #expect(starts(ends.morning.magicHours) == [try time(1, 50), try time(2, 43)])
        #expect(starts(ends.evening.magicHours) == [try time(21, 6), try time(23, 17)])
        #expect(ends.evening.magicHours.last?.interval.end == (try time(day: 17, 0, 10)))
    }

    /// Reykjavík's December has no daylight, so its day parts in the middle of its golden hour.
    @Test func aDayWithoutDaylightPartsInItsBrightestPhase() throws {
        let run = try run(.allDayGolden)

        let ends = MorningEveningView.ends(of: run.days[0], in: run)

        #expect(starts(ends.morning.magicHours) == [try time(10, 3), try time(10, 30)])
        #expect(starts(ends.evening.magicHours) == [try time(16, 21)])
    }

    /// Near the poles in early May, the sun dips into golden hour just after midnight, parting
    /// daylight in two, so noon is the middle of the longer part.
    @Test func aDipAroundMidnightDoesNotMoveNoon() throws {
        let dayStart = try time(0)
        let day = SolarDay(
            calendar: calendar,
            dayStart: dayStart,
            dayEnd: try time(day: 17, 0),
            initialPhase: .daylight,
            transitions: [
                PhaseTransition(date: try time(0, 4), from: .daylight, into: .goldenHour),
                PhaseTransition(date: try time(1, 24), from: .goldenHour, into: .daylight)
            ],
            sunrise: nil,
            sunset: nil
        )

        let ends = MorningEveningView.ends(of: day, in: DayRun(day))

        #expect(starts(ends.morning.magicHours) == [try time(0, 4)])
        #expect(ends.evening.magicHours.isEmpty)
    }

    @Test func aMidnightSunHasNeitherEnd() throws {
        let run = try run(.midnightSun)

        let ends = MorningEveningView.ends(of: run.days[0], in: run)

        #expect(ends.morning.magicHours.isEmpty && ends.morning.event == nil)
        #expect(ends.evening.magicHours.isEmpty && ends.evening.event == nil)
    }
}

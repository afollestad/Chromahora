//
//  SolarDayTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

struct SolarDayTests {
    private let day = SolarDay.mock(
        for: Date(timeIntervalSince1970: 1_790_000_000),
        calendar: Calendar(identifier: .gregorian)
    )

    @Test func segmentsTileTheWholeDayInOrder() {
        let segments = day.segments

        #expect(segments.map(\.phase) == [.night, .blueHour, .goldenHour, .daylight, .goldenHour, .blueHour, .night])
        #expect(segments.first?.interval.start == day.dayStart)
        #expect(segments.last?.interval.end == day.dayEnd)

        for (earlier, later) in zip(segments, segments.dropFirst()) {
            #expect(earlier.interval.end == later.interval.start)
            #expect(earlier.interval.duration >= 0)
        }
    }

    @Test func sunriseAndSunsetFallInsideGoldenHours() {
        let goldenHours = day.segments.filter { $0.phase == .goldenHour }

        #expect(goldenHours.count == 2)
        #expect(goldenHours[0].interval.contains(day.sunrise))
        #expect(goldenHours[1].interval.contains(day.sunset))
    }

    @Test func fractionMapsTheDayOntoUnitRangeAndClamps() {
        #expect(day.fraction(of: day.dayStart) == 0)
        #expect(day.fraction(of: day.dayEnd) == 1)
        #expect(day.fraction(of: day.dayStart.addingTimeInterval(-3600)) == 0)
        #expect(day.fraction(of: day.dayEnd.addingTimeInterval(3600)) == 1)

        let noon = day.dayStart.addingTimeInterval(day.duration / 2)
        #expect(abs(day.fraction(of: noon) - 0.5) < 0.0001)
    }

    @Test func phaseAtDateFollowsSegmentsAndTreatsOutsideAsNight() {
        #expect(day.phase(at: day.dayStart) == .night)
        #expect(day.phase(at: day.morningBlueHourStart) == .blueHour)
        #expect(day.phase(at: day.sunrise) == .goldenHour)
        #expect(day.phase(at: day.morningGoldenHourEnd) == .daylight)
        #expect(day.phase(at: day.sunset) == .goldenHour)
        #expect(day.phase(at: day.eveningBlueHourStart) == .blueHour)
        #expect(day.phase(at: day.eveningBlueHourEnd) == .night)
        #expect(day.phase(at: day.dayStart.addingTimeInterval(-60)) == .night)
        #expect(day.phase(at: day.dayEnd) == .night)
    }

    @Test func containsOnlyDatesFromStartUpToButExcludingEnd() {
        #expect(day.contains(day.dayStart))
        #expect(day.contains(day.sunrise))
        #expect(!day.contains(day.dayEnd))
        #expect(!day.contains(day.dayStart.addingTimeInterval(-1)))
    }

    @Test func hourMarksCoverEveryHourBetweenMidnights() {
        let marks = day.hourMarks

        #expect(marks.map(\.hour) == Array(1...23))
        #expect(marks.allSatisfy { day.dayStart < $0.date && $0.date < day.dayEnd })
    }

    /// In the US, 2 AM is skipped on March 8, 2026 and 1 AM repeats on November 1, 2026.
    @Test func hourMarksFollowTheClockAcrossDaylightSavingChanges() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        func day(month: Int, day: Int) throws -> SolarDay {
            let noon = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)))
            return SolarDay.mock(for: noon, calendar: calendar)
        }

        let springForward = try day(month: 3, day: 8)
        #expect(springForward.hourMarks.map(\.hour) == [1] + Array(3...23))

        let fallBack = try day(month: 11, day: 1)
        #expect(fallBack.hourMarks.map(\.hour) == [1, 1] + Array(2...23))
        #expect(Set(fallBack.hourMarks.map(\.id)).count == fallBack.hourMarks.count)
        #expect(fallBack.hourMarks.allSatisfy { fallBack.dayStart < $0.date && $0.date < fallBack.dayEnd })
    }
}

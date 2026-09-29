//
//  SolarDayFocusTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

struct SolarDayFocusTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func focusesOnNowWithinTheDay() {
        let day = SolarDay.mock(for: date, calendar: calendar)

        #expect(day.focusDate(now: date) == date)
    }

    @Test func focusesOnDaylightOnAnotherDay() throws {
        let day = SolarDay.mock(for: date, calendar: calendar)
        let daylight = try #require(day.segments.first { $0.phase == .daylight })

        #expect(day.focusDate(now: day.dayEnd.addingTimeInterval(3600)) == daylight.midpoint)
    }

    /// A winter day that never reaches daylight centers on its golden hour instead.
    @Test func focusesOnGoldenHourWithoutDaylight() throws {
        let day = SolarDay.mock(.allDayGolden, for: date, calendar: calendar)
        let golden = try #require(day.segments.first { $0.phase == .goldenHour })

        #expect(day.focusDate(now: day.dayEnd.addingTimeInterval(3600)) == golden.midpoint)
    }

    @Test func focusesOnTheMiddleOfAPolarNight() {
        let day = SolarDay.mock(.polarNight, for: date, calendar: calendar)

        #expect(day.focusDate(now: day.dayEnd.addingTimeInterval(3600)) == day.dayStart.addingTimeInterval(day.duration / 2))
    }
}

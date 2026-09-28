//
//  SkyHourTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

struct SkyHourTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    private var day: SolarDay {
        .mock(for: date, calendar: calendar)
    }

    /// An hour starting `hours` into the mock's day.
    private func hour(_ hours: Double, uvIndex: Int = 0) -> SkyHour {
        SkyHour(
            date: day.dayStart.addingTimeInterval(hours * SkyHour.duration),
            uvIndex: uvIndex,
            lowCloud: 0,
            midCloud: 0,
            highCloud: 0,
            visibility: 10_000
        )
    }

    /// An hour holds its start but not its end, so a time on the hour belongs to the one it starts.
    @Test func anHourHoldsItsStartButNotItsEnd() {
        let hours = [hour(18), hour(19)]

        #expect(SkyHour.hour(containing: hours[1].date, in: hours) == hours[1])
        #expect(SkyHour.hour(containing: hours[1].date.addingTimeInterval(-1), in: hours) == hours[0])
        #expect(SkyHour.hour(containing: hours[1].interval.end, in: hours) == nil)
    }

    /// In a zone half an hour off UTC, an hour that starts before midnight still reaches the day.
    @Test func thePeakIsTheEarliestHighestHourReachingTheDay() {
        let hours = [hour(-0.5, uvIndex: 9), hour(12, uvIndex: 6), hour(13, uvIndex: 6), hour(24, uvIndex: 11)]

        #expect(SkyHour.peakUV(on: day, in: hours) == hours[0])
        #expect(SkyHour.peakUV(on: day, in: Array(hours.dropFirst())) == hours[1])
    }

    @Test func noPeakWhenTheForecastMissesTheDayOrTheIndexStaysAtZero() {
        #expect(SkyHour.peakUV(on: day, in: [hour(24, uvIndex: 5)]) == nil)
        #expect(SkyHour.peakUV(on: day, in: [hour(10), hour(12)]) == nil)
    }

    @Test(arguments: [(0, "Low"), (2, "Low"), (3, "Moderate"), (5, "Moderate"), (6, "High"), (7, "High"),
                      (8, "Very high"), (10, "Very high"), (11, "Extreme"), (14, "Extreme")])
    func categoriesFollowTheWHOsBands(uvIndex: Int, title: String) {
        #expect(hour(12, uvIndex: uvIndex).uvCategory.title == title)
    }

    @Test func theMockCoversTheWholeDayAndPeaksAtNoon() throws {
        let hours = SkyHour.mock(for: date, calendar: calendar)

        #expect(hours.count == 24)
        #expect(hours.first?.date == day.dayStart)
        #expect(try #require(SkyHour.peakUV(on: day, in: hours)).date == day.dayStart.addingTimeInterval(12 * SkyHour.duration))
    }
}

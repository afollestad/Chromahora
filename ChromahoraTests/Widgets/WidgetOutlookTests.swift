//
//  WidgetOutlookTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Which outlook the widgets show, and when they credit Apple Weather for it.
@MainActor
struct WidgetOutlookTests {
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

    /// The typical day on September 16 and 17, with the mock forecast up to `forecastEnd`.
    private func content(forecastEnd: Date = .distantFuture) throws -> SkyContent {
        let today = SolarDay.mock(for: try time(12), calendar: calendar)
        let tomorrow = SolarDay.mock(for: try time(day: 17, 12), calendar: calendar)
        let hours = SkyHour.mock(for: today.dayStart, calendar: calendar) + SkyHour.mock(for: tomorrow.dayStart, calendar: calendar)
        return SkyContent(
            place: MockPlaceProvider.sanFrancisco,
            deviceName: nil,
            run: DayRun(today, then: [tomorrow]),
            spells: [],
            hours: hours.filter { $0.interval.end <= forecastEnd }
        )
    }

    /// The summary rates the session of the golden or blue hour it shows: the evening's ahead of
    /// it and while its blue hour is under way, then tomorrow's morning once the evening is over.
    @Test(arguments: [(16, 30, OutlookSession.Kind.evening, 16), (19, 20, .evening, 16), (22, 0, .morning, 17)])
    func theSummaryRatesTheSessionItShows(hour: Int, minute: Int, kind: OutlookSession.Kind, day: Int) throws {
        let content = try content()
        let session = try #require(MagicHourSummary.session(in: content, at: try time(hour, minute)))

        #expect(session.kind == kind)
        #expect(calendar.component(.day, from: session.start) == day)
        #expect(MagicHourSummary.showsWeather(in: content, at: try time(hour, minute)))
    }

    /// Without a forecast there's no outlook, and no weather for Apple Weather's mark to credit.
    @Test func noForecastRatesNothing() throws {
        let content = try content(forecastEnd: try time(0))

        #expect(MagicHourSummary.session(in: content, at: try time(16, 30)) == nil)
        #expect(!MagicHourSummary.showsWeather(in: content, at: try time(16, 30)))
        #expect(content.sessions(on: content.run.days[0]).isEmpty)
    }

    /// A forecast that ends at noon covers the small hours and the morning, but not the daylight,
    /// evening or night past it.
    @Test func aForecastEndingAtNoonRatesOnlyTheSmallHoursAndTheMorning() throws {
        let content = try content(forecastEnd: try time(12))

        #expect(content.sessions(on: content.run.days[0]).map(\.kind) == [.beforeDawn, .morning])
        #expect(content.cloudCover(over: DateInterval(start: try time(6), end: try time(8))) != nil)
        #expect(content.cloudCover(over: DateInterval(start: try time(11), end: try time(13))) == nil)
    }
}

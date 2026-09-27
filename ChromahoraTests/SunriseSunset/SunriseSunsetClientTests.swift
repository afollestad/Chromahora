//
//  SunriseSunsetClientTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Requests, checked without touching the network.
struct SunriseSunsetClientTests {
    private let chicago = TimeZone(identifier: "America/Chicago") ?? .gmt
    private let place = Place(latitude: 41.85, longitude: -87.65, source: .timeZone("America/Chicago"))

    @Test func asksForAWholeMonthInTheDevicesZone() throws {
        let query = try query(for: CalendarMonth(year: 2026, month: 9, timeZone: chicago), at: place)

        #expect(query["lat"] == String(place.latitude))
        #expect(query["lng"] == String(place.longitude))
        #expect(query["date_start"] == "2026-09-01")
        #expect(query["date_end"] == "2026-09-30")
        #expect(query["tz"] == "America/Chicago")
        #expect(query["time_format"] == "unix")
    }

    @Test(arguments: [(2026, "2026-02-28"), (2028, "2028-02-29")])
    func februaryEndsOnItsLastDay(year: Int, lastDay: String) throws {
        let query = try query(for: CalendarMonth(year: year, month: 2, timeZone: chicago), at: place)

        #expect(query["date_end"] == lastDay)
    }

    /// Chicago springs forward on March 8, 2026, which leaves the month's days alone.
    @Test func aDaylightSavingMonthKeepsItsDays() throws {
        let query = try query(for: CalendarMonth(year: 2026, month: 3, timeZone: chicago), at: place)

        #expect(query["date_start"] == "2026-03-01")
        #expect(query["date_end"] == "2026-03-31")
    }

    /// Thai devices default to the Buddhist calendar, where 2026 is 2569.
    @Test func monthsAreGregorianWhateverTheDevicesCalendar() throws {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = chicago
        let noon = try #require(CalendarMonth.gregorian(in: chicago).date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 12)))
        let month = CalendarMonth(containing: buddhist.startOfDay(for: noon), in: buddhist.timeZone)

        #expect(month.name == "2026-09")
        #expect(month.dayName(of: noon) == "2026-09-26")
    }

    @Test func coordinatesNearZeroNeverGoNegative() throws {
        let query = try query(
            for: CalendarMonth(year: 2026, month: 9, timeZone: .gmt),
            at: Place(latitude: -0.04, longitude: -0.04, source: .device)
        )

        #expect(query["lat"] == "0.0")
        #expect(query["lng"] == "0.0")
    }

    private func query(for month: CalendarMonth, at place: Place) throws -> [String: String] {
        let url = SunriseSunsetClient.url(for: month, at: place)
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.host() == "api.sunrise-sunset.org")
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
}

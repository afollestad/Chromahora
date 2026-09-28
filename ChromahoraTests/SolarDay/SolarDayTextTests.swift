//
//  SolarDayTextTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

struct SolarDayTextTests {
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    /// The typical mock in GMT: night until 6:12 AM, blue hour to 6:38, golden hour to 7:42,
    /// and night again from 7:36 PM.
    private var day: SolarDay { .mock(for: date, calendar: calendar(.gmt)) }

    @Test func rangesGiveBothEndsOrOnlyTheSideOnThisDay() {
        let segments = day.segments

        #expect(plain(day.rangeText(of: segments[0])) == "until 6:12 AM")
        #expect(plain(day.rangeText(of: segments[1])) == "6:12 – 6:38 AM")
        #expect(plain(day.rangeText(of: segments[6])) == "from 7:36 PM")
        #expect(plain(allDay.rangeText(of: allDay.segments[0])) == "all day")
    }

    @Test func startingALineCapitalizesTheWordsOnly() {
        let segments = day.segments

        #expect(plain(day.rangeText(of: segments[0], startsLine: true)) == "Until 6:12 AM")
        #expect(plain(day.rangeText(of: segments[1], startsLine: true)) == "6:12 – 6:38 AM")
        #expect(plain(day.rangeText(of: segments[6], startsLine: true)) == "From 7:36 PM")
        #expect(plain(allDay.rangeText(of: allDay.segments[0], startsLine: true)) == "All day")
    }

    /// Two zones 14 hours apart can't both match the process's, so a time read in the
    /// process's zone fails one of them.
    @Test func timesReadInTheDaysOwnZone() throws {
        for zone in [TimeZone.gmt, try #require(TimeZone(identifier: "Pacific/Kiritimati"))] {
            let day = SolarDay.mock(for: date, calendar: calendar(zone))

            #expect(plain(day.timeText(try #require(day.sunrise))) == "6:58 AM")
            #expect(plain(day.rangeText(of: day.segments[1])) == "6:12 – 6:38 AM")
        }
    }

    @Test func durationsRoundToMinutes() {
        let segments = day.segments

        #expect(segments[1].durationText() == "26 min")
        #expect(segments[2].durationText() == "1 hr, 4 min")
        #expect(segments[2].durationText(width: .wide) == "1 hour, 4 minutes")
    }

    /// The part of a phase on this day isn't its length.
    @Test func phasesMidnightCutsOffHaveNoDuration() {
        let segments = day.segments

        #expect(segments[0].durationText() == nil)
        #expect(segments[6].durationText() == nil)
        #expect(allDay.segments[0].durationText() == nil)
    }

    // MARK: Helpers

    private var allDay: SolarDay { .mock(.midnightSun, for: date, calendar: calendar(.gmt)) }

    private func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    /// Time formats put a narrow no-break space before AM and PM, and thin spaces around a
    /// range's dash.
    private func plain(_ text: String) -> String {
        text.replacing("\u{202F}", with: " ").replacing("\u{2009}", with: " ")
    }
}

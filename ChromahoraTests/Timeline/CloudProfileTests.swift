//
//  CloudProfileTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

struct CloudProfileTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private var day: SolarDay {
        .mock(for: Date(timeIntervalSince1970: 1_790_000_000), calendar: calendar)
    }

    /// An hour starting `hours` into the day, with `cover` of the sky covered.
    private func hour(_ hours: Double, cover: Double) -> SkyHour {
        SkyHour(
            date: day.dayStart.addingTimeInterval(hours * SkyHour.duration),
            uvIndex: 0,
            lowCloud: 0,
            midCloud: 0,
            highCloud: 0,
            cloudCover: cover,
            visibility: 10_000,
            precipitation: nil,
            precipitationChance: 0,
            windSpeed: 0
        )
    }

    private func fraction(_ hours: Double) -> Double {
        hours * SkyHour.duration / day.duration
    }

    /// Each hour's cover sits at its middle, and the first and last hold flat to the run's ends.
    @Test func coverSitsAtEachHoursMiddleAndHoldsToTheEnds() {
        let profile = CloudProfile(day: day, hours: [hour(6, cover: 0.2), hour(7, cover: 0.8)])

        #expect(profile.runs == [[
            .init(fraction: fraction(6), cover: 0.2),
            .init(fraction: fraction(6.5), cover: 0.2),
            .init(fraction: fraction(7.5), cover: 0.8),
            .init(fraction: fraction(8), cover: 0.8)
        ]])
    }

    /// A missing hour leaves a gap rather than a guess across it.
    @Test func aMissingHourSplitsTheRuns() {
        let profile = CloudProfile(day: day, hours: [hour(6, cover: 0.2), hour(8, cover: 0.8)])

        #expect(profile.runs.count == 2)
        #expect(profile.runs.map { $0.first?.fraction } == [fraction(6), fraction(8)])
    }

    /// The next day's hours carry the band on across midnight, past the end of the day.
    @Test func neighboringHoursCarryOnAcrossMidnight() {
        let profile = CloudProfile(day: day, hours: [hour(23, cover: 0.2), hour(24, cover: 0.8)])

        #expect(profile.runs.count == 1)
        #expect(profile.runs[0].dropLast() == [
            .init(fraction: fraction(23), cover: 0.2),
            .init(fraction: fraction(23.5), cover: 0.2),
            .init(fraction: fraction(24.5), cover: 0.8),
            .init(fraction: fraction(25), cover: 0.8)
        ])
    }

    /// Where the forecast stops at or past one of the day's ends, its last cover holds out to
    /// the reach. In a zone half an hour off UTC, the hours at either midnight run past it.
    @Test func coverHoldsPastAnEndWhereTheForecastStops() {
        let reach = CloudProfile.reach / SkyHour.duration
        let profile = CloudProfile(day: day, hours: [hour(-0.5, cover: 0.4), hour(23.5, cover: 0.6)])

        #expect(profile.runs.count == 2)
        #expect(profile.runs[0] == [
            .init(fraction: fraction(-reach), cover: 0.4),
            .init(fraction: fraction(-0.5), cover: 0.4),
            .init(fraction: fraction(0), cover: 0.4),
            .init(fraction: fraction(0.5), cover: 0.4)
        ])
        #expect(profile.runs[1].map(\.fraction) == [fraction(23.5), fraction(24), fraction(24.5), fraction(24 + reach)])
    }

    /// A run that stops short of the day's ends leaves its gap there too.
    @Test func aRunShortOfAnEndHoldsNoFurther() {
        let profile = CloudProfile(day: day, hours: [hour(1, cover: 0.5), hour(22, cover: 0.5)])

        #expect(profile.runs.map { $0.first?.fraction } == [fraction(1), fraction(22)])
        #expect(profile.runs.map { $0.last?.fraction } == [fraction(2), fraction(23)])
    }

    @Test func hoursPastTheReachAreLeftOut() {
        let reach = CloudProfile.reach / SkyHour.duration
        let profile = CloudProfile(day: day, hours: [hour(-reach - 1, cover: 0.5), hour(12, cover: 0.5), hour(24 + reach, cover: 0.5)])

        #expect(profile.runs.map { $0.first?.fraction } == [fraction(12)])
    }

    @Test func coverStaysWithinTheSky() {
        let profile = CloudProfile(day: day, hours: [hour(6, cover: -0.1), hour(7, cover: 1.2)])

        #expect(profile.runs[0].map(\.cover) == [0, 0, 1, 1])
    }

    @Test func noHoursDrawNoBand() {
        #expect(CloudProfile(day: day, hours: []).runs.isEmpty)
    }
}

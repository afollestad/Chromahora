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

    /// In a zone half an hour off UTC, the hours at either midnight are cut there, and hours off
    /// the day are left out.
    @Test func hoursAreKeptToTheDay() {
        let profile = CloudProfile(day: day, hours: [hour(-2, cover: 0.5), hour(-0.5, cover: 0.4), hour(23.5, cover: 0.6), hour(25, cover: 1)])

        #expect(profile.runs.count == 2)
        #expect(profile.runs[0].map(\.fraction) == [0, 0, fraction(0.5)])
        #expect(profile.runs[1].map(\.fraction) == [fraction(23.5), 1, 1])
    }

    @Test func coverStaysWithinTheSky() {
        let profile = CloudProfile(day: day, hours: [hour(6, cover: -0.1), hour(7, cover: 1.2)])

        #expect(profile.runs[0].map(\.cover) == [0, 0, 1, 1])
    }

    @Test func noHoursDrawNoBand() {
        #expect(CloudProfile(day: day, hours: []).runs.isEmpty)
    }
}

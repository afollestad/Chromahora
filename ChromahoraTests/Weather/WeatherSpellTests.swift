//
//  WeatherSpellTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

struct WeatherSpellTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Midnight, so hour offsets from it double as clock hours.
    private var start: Date { calendar.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000)) }

    // MARK: Classification

    /// Light rain often never reaches even odds, like a real morning of drizzle whose chance
    /// peaked at 46%, so precipitation counts from 30%.
    @Test func possiblePrecipitationBeatsFogWhichBeatsCloud() {
        #expect(hour(cover: 0.1, precipitation: .rain, chance: 0.3, foggy: true).condition == .rain)
        #expect(hour(cover: 0.1, foggy: true).condition == .fog)
        #expect(hour(cover: 0.1, precipitation: .snow, chance: 0.29).condition == .clear)
    }

    /// Up to two eighths of the sky reads as clear, and six or more as cloudy.
    @Test func cloudCoverSplitsAtTwoAndSixEighths() {
        #expect(hour(cover: 0.25).condition == .clear)
        #expect(hour(cover: 0.26).condition == .partlyCloudy)
        #expect(hour(cover: 0.74).condition == .partlyCloudy)
        #expect(hour(cover: 0.75).condition == .cloudy)
    }

    // MARK: Grouping

    @Test func matchingHoursJoinAndEndAnHourAfterTheLast() {
        let spells = WeatherSpell.spells(from: hours([.cloudy, .cloudy, .cloudy, .rain, .rain]))

        #expect(spells.map(\.condition) == [.cloudy, .rain])
        #expect(spells.map(offsets) == [0..<3, 3..<5])
    }

    @Test func aMissingHourSplitsASpell() {
        let spells = WeatherSpell.spells(from: [hour(0, .rain), hour(1, .rain), hour(3, .rain)])

        #expect(spells.map(offsets) == [0..<2, 3..<4])
    }

    @Test func precipitationThatChangesTypeIsOneMixedSpell() {
        let spells = WeatherSpell.spells(from: hours([.rain, .snow, .snow]))

        #expect(spells.map(\.condition) == [.mixed])
        #expect(spells.map(offsets) == [0..<3])
    }

    @Test func hoursAreSortedFirst() {
        let ordered = hours([.clear, .clear, .rain, .cloudy, .cloudy])

        #expect(WeatherSpell.spells(from: ordered.reversed()) == WeatherSpell.spells(from: ordered))
    }

    // MARK: Folding

    /// Cloud cover crossing a threshold for an hour and back leaves one spell.
    @Test func aShortSkyRunFoldsIntoTheOneBeforeAndRejoinsItsMatch() {
        let rejoined = WeatherSpell.spells(from: hours([.cloudy, .cloudy, .partlyCloudy, .cloudy, .cloudy]))
        #expect(rejoined.map(\.condition) == [.cloudy])
        #expect(rejoined.map(offsets) == [0..<5])

        let folded = WeatherSpell.spells(from: hours([.clear, .clear, .partlyCloudy, .cloudy, .cloudy]))
        #expect(folded.map(\.condition) == [.clear, .cloudy])
        #expect(folded.map(offsets) == [0..<3, 3..<5])
    }

    @Test func aShortFirstSkyRunFoldsIntoTheNext() {
        let spells = WeatherSpell.spells(from: hours([.clear, .cloudy, .cloudy]))

        #expect(spells.map(\.condition) == [.cloudy])
        #expect(spells.map(offsets) == [0..<3])
    }

    /// Even an hour of rain matters, so it never folds, and a short sky run with only
    /// precipitation beside it has nowhere to fold.
    @Test func precipitationNeverFolds() {
        let rain = WeatherSpell.spells(from: hours([.cloudy, .cloudy, .rain, .cloudy, .cloudy]))
        #expect(rain.map(\.condition) == [.cloudy, .rain, .cloudy])
        #expect(rain.map(offsets) == [0..<2, 2..<3, 3..<5])

        let between = WeatherSpell.spells(from: hours([.rain, .cloudy, .rain]))
        #expect(between.map(\.condition) == [.rain, .cloudy, .rain])
    }

    // MARK: Values

    @Test func precipitationKeepsItsPeakChanceAndSkyItsMeanCover() throws {
        let rain = try #require(WeatherSpell.spells(from: [hour(0, .rain, chance: 0.6), hour(1, .rain, chance: 0.9)]).first)
        #expect(rain.precipitationChance == 0.9)

        let cloudy = try #require(WeatherSpell.spells(from: [hour(0, cover: 0.8), hour(1, cover: 1)]).first)
        #expect(cloudy.condition == .cloudy)
        #expect(abs(cloudy.cloudCover - 0.9) < 0.0001)
    }

    @Test func precipitationThatNeverGetsLikelyReadsAsAChance() {
        #expect(spell(.rain, 0..<2, chance: 0.46).title == "Chance of rain")
        #expect(spell(.rain, 0..<2, chance: 0.5).title == "Rain")
        #expect(spell(.cloudy, 0..<2, cover: 0.9).title == "Cloudy")
    }

    @Test func summariesGiveTheChanceOrTheCover() {
        #expect(spell(.rain, 0..<2, chance: 0.8).summary == "80% chance")
        #expect(spell(.partlyCloudy, 0..<2, cover: 0.4).summary == "40% cloud cover")
        #expect(spell(.fog, 0..<2).summary == nil)
    }

    @Test func descriptionsReadTheTitleRangeAndSummary() {
        #expect(spell(.rain, 0..<2, chance: 0.8).description(range: "3:00 – 5:00 PM") == "Rain, 3:00 – 5:00 PM, 80% chance")
        #expect(spell(.fog, 0..<2).description(range: "all day") == "Fog, all day")
    }

    /// The typical mock in GMT is night until 6:12 AM, golden hour from 6:38 to 7:42, and
    /// night again from 7:36 PM.
    @Test func aSpellUnderWayAtMidnightStartsThereAndShowsTheSunOnlyInLight() {
        let day = SolarDay.mock(for: start, calendar: calendar)

        #expect(spell(.clear, -2..<3).start(on: day) == day.dayStart)
        #expect(spell(.clear, 3..<5).start(on: day) == date(3))
        #expect(!spell(.clear, -2..<3).startsInDaylight(on: day))
        #expect(spell(.clear, 7..<9).startsInDaylight(on: day))
        #expect(spell(.clear, 12..<14).startsInDaylight(on: day))
        #expect(!spell(.clear, 20..<22).startsInDaylight(on: day))
    }

    /// A spell under way at midnight shows on the day it continues into, but not on a day
    /// it only touches.
    @Test func spanSaysWhichEndsMidnightCutsOff() {
        let day = SolarDay.mock(for: start, calendar: calendar)

        #expect(spell(.rain, 3..<5).span(within: day) == .range)
        #expect(spell(.rain, -2..<5).span(within: day) == .until)
        #expect(spell(.rain, 0..<5).span(within: day) == .until)
        #expect(spell(.rain, 20..<26).span(within: day) == .from)
        #expect(spell(.rain, -1..<25).span(within: day) == .allDay)
        #expect(spell(.rain, -3..<0).span(within: day) == nil)
        #expect(spell(.rain, 24..<26).span(within: day) == nil)
    }

    // MARK: Helpers

    private func date(_ offset: Int) -> Date {
        start.addingTimeInterval(TimeInterval(offset) * 60 * 60)
    }

    private func hour(
        _ offset: Int = 0,
        cover: Double = 0.5,
        precipitation: SkyCondition? = nil,
        chance: Double = 0,
        foggy: Bool = false
    ) -> WeatherHour {
        WeatherHour(date: date(offset), cloudCover: cover, precipitation: precipitation, precipitationChance: chance, isFoggy: foggy)
    }

    /// An hour that reads as `condition`, with a likely chance for precipitation.
    private func hour(_ offset: Int, _ condition: SkyCondition, chance: Double = 0.8) -> WeatherHour {
        switch condition {
        case .clear: hour(offset, cover: 0.1)
        case .partlyCloudy: hour(offset, cover: 0.5)
        case .cloudy: hour(offset, cover: 0.9)
        case .fog: hour(offset, cover: 0.9, foggy: true)
        case .rain, .snow, .sleet, .hail, .mixed: hour(offset, cover: 1, precipitation: condition, chance: chance)
        }
    }

    /// Consecutive hours from midnight, one per condition.
    private func hours(_ conditions: [SkyCondition]) -> [WeatherHour] {
        conditions.enumerated().map { offset, condition in hour(offset, condition) }
    }

    private func spell(_ condition: SkyCondition, _ hours: Range<Int>, chance: Double = 0, cover: Double = 0) -> WeatherSpell {
        WeatherSpell(
            condition: condition,
            interval: DateInterval(start: date(hours.lowerBound), end: date(hours.upperBound)),
            precipitationChance: chance,
            cloudCover: cover
        )
    }

    /// The spell's hours as offsets from midnight.
    private func offsets(_ spell: WeatherSpell) -> Range<Int> {
        let hour: TimeInterval = 60 * 60
        return Int(spell.interval.start.timeIntervalSince(start) / hour)..<Int(spell.interval.end.timeIntervalSince(start) / hour)
    }
}

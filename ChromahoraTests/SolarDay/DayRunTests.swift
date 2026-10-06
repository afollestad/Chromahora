//
//  DayRunTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

struct DayRunTests {
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

    /// `days` days of `scenario` from September 16.
    private func run(_ scenario: MockScenario, days: Int = 2) throws -> DayRun {
        let first = SolarDay.mock(scenario, for: try time(12), calendar: calendar)
        let later = try (1..<days).map { SolarDay.mock(scenario, for: try time(day: 16 + $0, 12), calendar: calendar) }
        return DayRun(first, then: later)
    }

    private func starts(_ segments: [DaySegment]) -> [Date] {
        segments.map(\.interval.start)
    }

    @Test(arguments: MockScenario.allCases)
    func segmentsTileTheRunWithoutRepeatingAPhase(scenario: MockScenario) throws {
        let run = try run(scenario)

        #expect(run.segments.first?.interval.start == run.start)
        #expect(run.segments.last?.interval.end == run.end)
        for (earlier, later) in zip(run.segments, run.segments.dropFirst()) {
            #expect(earlier.interval.end == later.interval.start)
            #expect(earlier.phase != later.phase)
        }
        #expect(run.segments.map(\.id) == Array(run.segments.indices))
    }

    @Test func mergesAPhaseAcrossMidnight() throws {
        let run = try run(.typical)
        let lateNight = try time(23)
        let night = try #require(run.segments.first { $0.interval.contains(lateNight) })

        #expect(night.interval == DateInterval(start: try time(19, 36), end: try time(day: 17, 6, 12)))
        #expect(night.span == .range)
        // Seven phases a day, with the night between them counted once.
        #expect(run.segments.count == 13)
        #expect(run.segments.first?.span == .until)
        #expect(run.segments.last?.span == .from)
    }

    @Test func midnightSunIsOneSegmentAllRun() throws {
        let run = try run(.midnightSun)

        #expect(run.segments.count == 1)
        #expect(run.segments.first?.span == .allDay)
    }

    /// Santiago's clocks spring forward at midnight on September 6, so that day starts at 1 AM,
    /// and the next still follows it at midnight.
    @Test func aDayStartingAtOneStillLeadsIntoTheNext() throws {
        var santiago = Calendar(identifier: .gregorian)
        santiago.timeZone = try #require(TimeZone(identifier: "America/Santiago"))
        let noon = try #require(santiago.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12)))
        let today = SolarDay.mock(for: noon, calendar: santiago)
        let tomorrow = SolarDay.mock(for: today.dayEnd, calendar: santiago)

        #expect(today.duration == 23 * 60 * 60)
        #expect(DayRun(today, then: [tomorrow]).days.count == 2)
    }

    @Test func dropsADayThatDoesNotFollow() throws {
        let first = SolarDay.mock(for: try time(12), calendar: calendar)
        let skipped = SolarDay.mock(for: try time(day: 18, 12), calendar: calendar)

        #expect(DayRun(first, then: [skipped]).days == [first])
    }

    @Test func magicHourIsTheNextToStart() throws {
        let magicHour = try #require(try run(.typical).magicHour(at: try time(16, 30)))

        #expect(magicHour.phase == .goldenHour)
        #expect(magicHour.interval == DateInterval(start: try time(18, 5), end: try time(19, 10)))
    }

    @Test func magicHourUnderWayHoldsUntilItEnds() throws {
        let run = try run(.typical)

        #expect(run.magicHour(at: try time(18, 30))?.phase == .goldenHour)
        // At a change of phase, the one starting is under way.
        #expect(run.magicHour(at: try time(19, 10))?.phase == .blueHour)
    }

    @Test func magicHourAfterDarkIsTomorrowMorning() throws {
        let magicHour = try #require(try run(.typical).magicHour(at: try time(22)))

        #expect(magicHour.phase == .blueHour)
        #expect(magicHour.interval.start == (try time(day: 17, 6, 12)))
    }

    @Test func blueHourPastMidnightReadsAsOne() throws {
        let magicHour = try #require(try run(.blueHourPastMidnight).magicHour(at: try time(23, 30)))

        #expect(magicHour.interval == DateInterval(start: try time(23, 17), end: try time(day: 17, 0, 10)))
        #expect(magicHour.span == .range)
    }

    @Test func magicHourCutOffByTheRunKeepsItsSpan() throws {
        let run = try run(.blueHourPastMidnight, days: 1)

        #expect(run.magicHour(at: try time(0, 5))?.span == .until)
        #expect(run.magicHour(at: try time(23, 30))?.span == .from)
    }

    @Test(arguments: [MockScenario.midnightSun, .polarNight])
    func noMagicHourComesInAPolarRun(scenario: MockScenario) throws {
        #expect(try run(scenario).magicHour(at: try time(12)) == nil)
    }

    @Test func segmentsFromStartWithTheOneUnderWay() throws {
        let segments = try run(.typical).segments(from: try time(18, 30))

        #expect(segments.prefix(3).map(\.phase) == [.goldenHour, .blueHour, .night])
    }

    @Test func nextSunEventCrossesMidnight() throws {
        let run = try run(.typical)

        #expect(run.nextSunEvent(after: try time(12))?.kind == .sunset)
        #expect(run.nextSunEvent(after: try time(20))?.date == (try time(day: 17, 6, 58)))
        #expect(try self.run(.polarNight).nextSunEvent(after: try time(12)) == nil)
    }

    @Test func darkSkyJoinsAcrossMidnight() throws {
        let run = try run(.typical)
        // The moon sets at 10:07 PM, and astronomical night lasts until 5:23 AM.
        let tonight = DayRun.DarkSky.stretch(DateInterval(start: try time(22, 7), end: try time(day: 17, 5, 23)), span: .range)

        #expect(run.darkSky(at: try time(12)) == tonight)
        #expect(run.darkSky(at: try time(23)) == tonight)
    }

    @Test(arguments: [MockScenario.midnightSun, .goldenNight])
    func darkSkyNeverComesWhenNightDoesNot(scenario: MockScenario) throws {
        #expect(try run(scenario).darkSky(at: try time(12)) == .neverDark)
    }

    /// Reykjavík's December moon is up through both of its nights.
    @Test func darkSkyNeverComesWithTheMoonUpAllNight() throws {
        #expect(try run(.allDayGolden).darkSky(at: try time(12)) == .moonUp)
    }

    /// Longyearbyen's December moon neither rises nor sets, so there's no telling.
    @Test func darkSkyIsUnknownWithoutMoonTimes() throws {
        #expect(try run(.polarNight).darkSky(at: try time(12)) == nil)
    }

    /// The evening can't place its moon, but after midnight it's down, so tonight is dark until
    /// dawn from whenever it set.
    @Test func darkSkyAfterAnUnknownEveningReadsUntil() throws {
        let unknown = SolarDay.mock(.polarNight, for: try time(12), calendar: calendar)
        let known = SolarDay.mock(.typical, for: try time(day: 17, 12), calendar: calendar)
        let tonight = DayRun.DarkSky.stretch(DateInterval(start: try time(day: 17, 0), end: try time(day: 17, 5, 23)), span: .until)

        #expect(DayRun(unknown, then: [known]).darkSky(at: try time(12)) == tonight)
    }

    /// After midnight, tonight's dark sky still began the evening before.
    @Test func darkSkyAfterMidnightKeepsItsEveningStart() throws {
        let tonight = DayRun.DarkSky.stretch(DateInterval(start: try time(22, 7), end: try time(day: 17, 5, 23)), span: .range)

        #expect(try run(.typical).darkSky(at: try time(day: 17, 0, 30)) == tonight)
    }

    /// Tonight the moon rises before the sky is fully dark, so tomorrow night's short dark sky,
    /// before its later moonrise, mustn't stand in for tonight's.
    @Test func tomorrowNightsDarkSkyIsNotTonights() throws {
        var today = SolarDay.mock(for: try time(12), calendar: calendar)
        today.moon = SolarDay.Moon(phase: .waningGibbous, illumination: 0.9, rise: try time(20, 30), set: try time(6))
        var tomorrow = SolarDay.mock(for: try time(day: 17, 12), calendar: calendar)
        tomorrow.moon = SolarDay.Moon(phase: .waningGibbous, illumination: 0.85, rise: try time(day: 17, 21, 20), set: try time(day: 17, 7))
        let run = DayRun(today, then: [tomorrow])

        #expect(run.darkSky(at: try time(20)) == .moonUp)
        let tomorrowNight = DateInterval(start: try time(day: 17, 20, 44), end: try time(day: 17, 21, 20))
        #expect(run.darkSky(at: try time(day: 17, 12)) == .stretch(tomorrowNight, span: .range))
    }

    /// Tomorrow can't place its moon, so tonight's dark sky may run on past midnight.
    @Test func darkSkyRunningIntoAnUnknownDayReadsFrom() throws {
        let known = SolarDay.mock(.typical, for: try time(12), calendar: calendar)
        let unknown = SolarDay.mock(.polarNight, for: try time(day: 17, 12), calendar: calendar)
        let tonight = DayRun.DarkSky.stretch(DateInterval(start: try time(22, 7), end: try time(day: 17, 0)), span: .from)

        #expect(DayRun(known, then: [unknown]).darkSky(at: try time(12)) == tonight)
    }

    /// The interval style would name both dates for a range that crosses midnight.
    @Test func aRangeAcrossMidnightGivesOnlyItsTimes() throws {
        let run = try run(.typical)
        let tonight = DateInterval(start: try time(22, 7), end: try time(day: 17, 5, 23))
        let evening = DateInterval(start: try time(18, 5), end: try time(19, 10))

        #expect(run.rangeText(tonight, span: .range) == "\(run.timeText(tonight.start))\u{2009}–\u{2009}\(run.timeText(tonight.end))")
        #expect(run.rangeText(evening, span: .range) == run.days[0].rangeText(evening, span: .range))
        #expect(!run.rangeText(tonight, span: .range).contains("2026"))
    }

    @Test func featuredDayTurnsOverOnceItsLastMagicHourEnds() throws {
        let run = try run(.typical)

        #expect(run.featuredDay(at: try time(19, 35)) == run.days[0])
        #expect(run.featuredDay(at: try time(19, 36)) == run.days[1])
        #expect(try self.run(.typical, days: 1).featuredDay(at: try time(20)) == run.days[0])
    }

    @Test func featuredDayStaysWithoutAMagicHour() throws {
        let run = try run(.midnightSun)

        #expect(run.featuredDay(at: try time(20)) == run.days[0])
    }

    @Test func aTypicalDayPartsAtNoon() throws {
        let run = try run(.typical)

        let ends = run.ends(of: run.days[0])

        #expect(starts(ends.morning.magicHours) == [try time(6, 12), try time(6, 38)])
        #expect(starts(ends.evening.magicHours) == [try time(18, 5), try time(19, 10)])
        #expect(ends.morning.event?.kind == .sunrise)
        #expect(ends.evening.event?.kind == .sunset)
    }

    /// The blue hour that ends at 12:10 AM began the evening before, and the evening's own runs
    /// on into the next day whole.
    @Test func aBlueHourAcrossMidnightBelongsToTheEveningItStarts() throws {
        let run = try run(.blueHourPastMidnight)

        let ends = run.ends(of: run.days[0])

        #expect(starts(ends.morning.magicHours) == [try time(1, 50), try time(2, 43)])
        #expect(starts(ends.evening.magicHours) == [try time(21, 6), try time(23, 17)])
        #expect(ends.evening.magicHours.last?.interval.end == (try time(day: 17, 0, 10)))
    }

    /// Reykjavík's December has no daylight, so its day parts in the middle of its golden hour.
    @Test func aDayWithoutDaylightPartsInItsBrightestPhase() throws {
        let run = try run(.allDayGolden)

        let ends = run.ends(of: run.days[0])

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

        let ends = DayRun(day).ends(of: day)

        #expect(starts(ends.morning.magicHours) == [try time(0, 4)])
        #expect(ends.evening.magicHours.isEmpty)
    }

    @Test func aMidnightSunHasNeitherEnd() throws {
        let run = try run(.midnightSun)

        let ends = run.ends(of: run.days[0])

        #expect(ends.morning.magicHours.isEmpty && ends.morning.event == nil)
        #expect(ends.evening.magicHours.isEmpty && ends.evening.event == nil)
    }
}

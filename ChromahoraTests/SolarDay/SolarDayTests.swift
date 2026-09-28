//
//  SolarDayTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

struct SolarDayTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let date = Date(timeIntervalSince1970: 1_790_000_000)
    private var day: SolarDay { .mock(for: date, calendar: calendar) }

    @Test(arguments: MockScenario.allCases)
    func segmentsTileTheWholeDayInOrder(scenario: MockScenario) {
        let day = SolarDay.mock(scenario, for: date, calendar: calendar)
        let segments = day.segments

        #expect(segments.first?.interval.start == day.dayStart)
        #expect(segments.last?.interval.end == day.dayEnd)
        for (earlier, later) in zip(segments, segments.dropFirst()) {
            #expect(earlier.interval.end == later.interval.start)
            #expect(earlier.phase.borders(later.phase))
        }
        #expect(segments.allSatisfy { $0.interval.duration > 0 })
    }

    @Test func eachScenarioPassesThroughItsPhases() {
        let sequences = Dictionary(uniqueKeysWithValues: MockScenario.allCases.map { scenario in
            (scenario, SolarDay.mock(scenario, for: date, calendar: calendar).phaseSequence)
        })

        #expect(sequences[.typical] == [.night, .blueHour, .goldenHour, .daylight, .goldenHour, .blueHour, .night])
        #expect(sequences[.allDayGolden] == [.night, .blueHour, .goldenHour, .blueHour, .night])
        #expect(sequences[.goldenNight] == [.goldenHour, .daylight, .goldenHour])
        #expect(sequences[.blueHourPastMidnight] == [.blueHour, .night, .blueHour, .goldenHour, .daylight, .goldenHour, .blueHour])
        #expect(sequences[.polarTwilight] == [.night, .blueHour, .goldenHour, .blueHour, .night])
        #expect(sequences[.midnightSun] == [.daylight])
        #expect(sequences[.polarNight] == [.night])
    }

    /// The mocks skip `make`'s checks, so this holds them to the same rules as API data.
    @Test(arguments: MockScenario.allCases)
    func everyScenarioPassesMake(scenario: MockScenario) throws {
        let mock = SolarDay.mock(scenario, for: date, calendar: calendar)
        let made = try SolarDay.make(
            calendar: calendar,
            dayStart: mock.dayStart,
            dayEnd: mock.dayEnd,
            readings: scenario.readings(from: mock.dayStart, calendar: calendar)
        )

        #expect(made == mock)
    }

    /// The memberwise init skips `make`, so `segments` itself keeps changes outside the day
    /// from breaking the tiling or recoloring its ends.
    @Test func segmentsIgnoreUncheckedChangesOutsideTheDay() {
        let unchecked = SolarDay(
            calendar: calendar,
            dayStart: day.dayStart,
            dayEnd: day.dayEnd,
            initialPhase: .blueHour,
            transitions: [
                change(hours: -1, .blueHour, .night),
                change(hours: 5, .night, .blueHour),
                change(hours: 25, .blueHour, .night)
            ],
            sunrise: nil,
            sunset: nil
        )

        #expect(unchecked.phaseSequence == [.night, .blueHour])
        #expect(unchecked.segments.last?.interval.end == day.dayEnd)
        #expect(unchecked.segments.allSatisfy { $0.interval.duration > 0 })
    }

    @Test func sunriseAndSunsetFallInsideGoldenHours() throws {
        let goldenHours = day.segments.filter { $0.phase == .goldenHour }

        #expect(goldenHours.count == 2)
        #expect(goldenHours[0].interval.contains(try #require(day.sunrise)))
        #expect(goldenHours[1].interval.contains(try #require(day.sunset)))
    }

    @Test func eventsListOnlyTheSunrisesAndSunsetsThatHappen() {
        #expect(day.events.map(\.title) == ["Sunrise", "Sunset"])
        #expect(day.events.map(\.symbolName) == ["sunrise.fill", "sunset.fill"])
        #expect(SolarDay.mock(.polarTwilight, for: date, calendar: calendar).events.isEmpty)
    }

    @Test func spansSayWhichEndsMidnightCutsOff() {
        let typical = day.segments.map(\.span)
        #expect(typical.first == .until)
        #expect(typical.last == .from)
        #expect(typical.dropFirst().dropLast().allSatisfy { $0 == .range })

        #expect(SolarDay.mock(.midnightSun, for: date, calendar: calendar).segments.map(\.span) == [.allDay])
    }

    /// The typical mock's night gives way to blue hour at 6:12 AM.
    @Test func phaseAtFollowsTheSegmentsAndClampsToTheDay() throws {
        let blueHour = try #require(day.transitions.first).date

        #expect(day.phase(at: day.dayStart) == .night)
        #expect(day.phase(at: blueHour.addingTimeInterval(-1)) == .night)
        #expect(day.phase(at: blueHour) == .blueHour)
        #expect(day.phase(at: day.dayStart.addingTimeInterval(12 * 60 * 60)) == .daylight)
        #expect(day.phase(at: day.dayStart.addingTimeInterval(-60 * 60)) == .night)
        #expect(day.phase(at: day.dayEnd.addingTimeInterval(60 * 60)) == .night)
        #expect(SolarDay.mock(.midnightSun, for: date, calendar: calendar).phase(at: date) == .daylight)
    }

    /// At a change of phase the segment starting holds the instant, and the day's end belongs
    /// to the next day.
    @Test func segmentAtFindsTheOneUnderWayOnlyWithinTheDay() throws {
        let blueHour = try #require(day.transitions.first).date

        #expect(day.segment(at: day.dayStart)?.phase == .night)
        #expect(day.segment(at: blueHour.addingTimeInterval(-1))?.phase == .night)
        #expect(day.segment(at: blueHour)?.phase == .blueHour)
        #expect(day.segment(at: day.dayEnd.addingTimeInterval(-1))?.phase == .night)
        #expect(day.segment(at: day.dayEnd) == nil)
        #expect(day.segment(at: day.dayStart.addingTimeInterval(-1)) == nil)
    }

    @Test func heldColorRangeNarrowsToTheMidpointForShortPhases() {
        let start = date
        func held(minutes: Double) -> ClosedRange<Date> {
            segment(from: start, minutes: minutes).heldColorRange
        }

        let short = held(minutes: 60)
        #expect(short.lowerBound == start.addingTimeInterval(30 * 60))
        #expect(short.upperBound == short.lowerBound)

        let twoBlends = held(minutes: 90)
        #expect(twoBlends.lowerBound == start.addingTimeInterval(45 * 60))
        #expect(twoBlends.upperBound == twoBlends.lowerBound)

        let long = held(minutes: 6 * 60)
        #expect(long.lowerBound == start.addingTimeInterval(45 * 60))
        #expect(long.upperBound == start.addingTimeInterval((6 * 60 - 45) * 60))
    }

    @Test func altitudeBandsMatchTheTwilightAngles() {
        #expect(DayPhase.band(forAltitude: 35) == .daylight)
        #expect(DayPhase.band(forAltitude: 2) == .goldenHour)
        #expect(DayPhase.band(forAltitude: -5) == .blueHour)
        #expect(DayPhase.band(forAltitude: -12) == .night)
    }

    // MARK: make

    @Test func makeSortsChangesAndStartsFromTheFirstOnesPhase() throws {
        let made = try make([
            change(hours: 20, .blueHour, .night),
            change(hours: 1, .night, .blueHour),
            change(hours: 2, .blueHour, .goldenHour),
            change(hours: 19, .goldenHour, .blueHour)
        ])

        #expect(made.initialPhase == .night)
        #expect(made.phaseSequence == [.night, .blueHour, .goldenHour, .blueHour, .night])
    }

    /// The sun touching -6° and turning back crosses into blue hour and out again at once.
    @Test func makeDropsATouchAndReturn() throws {
        let made = try make([
            change(hours: 3, .night, .blueHour),
            change(hours: 3, .blueHour, .night)
        ], noonAltitude: -10)

        #expect(made.phaseSequence == [.night])
    }

    @Test func makeFoldsChangesOutsideTheDayIntoItsEnds() throws {
        let made = try make([
            change(hours: 0, .blueHour, .night),
            change(hours: 5, .night, .blueHour),
            change(hours: 24, .blueHour, .goldenHour)
        ])

        #expect(made.initialPhase == .night)
        #expect(made.transitions.map(\.into) == [.blueHour])
        #expect(made.segments.allSatisfy { $0.interval.duration > 0 })
    }

    @Test func makeTakesTheWholeDaysPhaseFromTheNoonAltitudeWithoutChanges() throws {
        #expect(try make([], noonAltitude: 35).phaseSequence == [.daylight])
        #expect(try make([], noonAltitude: 2.4).phaseSequence == [.goldenHour])
        #expect(try make([], noonAltitude: -11.7).phaseSequence == [.night])
    }

    @Test func makeRejectsChangesThatDontChain() {
        #expect(throws: SolarDayError.inconsistentPhases) {
            try make([change(hours: 5, .night, .blueHour), change(hours: 6, .goldenHour, .daylight)])
        }
        #expect(throws: SolarDayError.inconsistentPhases) {
            try make([change(hours: 5, .night, .goldenHour)])
        }
    }

    /// In the US, March 8, 2026 lasts 23 hours and November 1, 2026 lasts 25.
    @Test(arguments: [(3, 8, 23.0), (11, 1, 25.0)])
    func makeTilesDaylightSavingDays(month: Int, day: Int, hours: Double) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        let noon = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)))
        let mock = SolarDay.mock(for: noon, calendar: calendar)

        let made = try SolarDay.make(
            calendar: calendar,
            dayStart: mock.dayStart,
            dayEnd: mock.dayEnd,
            readings: SolarDay.Readings(transitions: mock.transitions, noonAltitude: 40, sunrise: mock.sunrise, sunset: mock.sunset)
        )

        #expect(made.duration == hours * 60 * 60)
        #expect(made.segments.last?.interval.end == made.dayEnd)
        #expect(made.segments.allSatisfy { $0.interval.duration > 0 })
    }

    // MARK: Day geometry

    @Test func fractionMapsTheDayOntoUnitRangeAndClamps() {
        #expect(day.fraction(of: day.dayStart) == 0)
        #expect(day.fraction(of: day.dayEnd) == 1)
        #expect(day.fraction(of: day.dayStart.addingTimeInterval(-3600)) == 0)
        #expect(day.fraction(of: day.dayEnd.addingTimeInterval(3600)) == 1)

        let noon = day.dayStart.addingTimeInterval(day.duration / 2)
        #expect(abs(day.fraction(of: noon) - 0.5) < 0.0001)
    }

    @Test func containsOnlyDatesFromStartUpToButExcludingEnd() throws {
        #expect(day.contains(day.dayStart))
        #expect(day.contains(try #require(day.sunrise)))
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

    // MARK: Night sky

    @Test func astronomicalNightRunsUntilDawnAndFromDusk() {
        let night = SolarDay.astronomicalNight(dawn: at(5), dusk: at(21), noonAltitude: 50, in: range)

        #expect(night == [span(0, 5), span(21, 24)])
    }

    /// Windowed to a far time zone, the evening's crossing comes first, so the night falls between them.
    @Test func astronomicalNightFallsBetweenAnEarlierDuskAndALaterDawn() {
        #expect(SolarDay.astronomicalNight(dawn: at(15), dusk: at(3), noonAltitude: 50, in: range) == [span(3, 15)])
    }

    @Test func aCrossingBeforeTheDaySetsHowItOpens() {
        #expect(SolarDay.astronomicalNight(dawn: at(5), dusk: at(-1), noonAltitude: 50, in: range) == [span(0, 5)])
    }

    /// Summer near the poles never gets that dark, and only a sun below -18° even at noon stays dark all day.
    @Test func withoutCrossingsNoonAltitudeDecidesTheWholeDay() {
        #expect(SolarDay.astronomicalNight(dawn: nil, dusk: nil, noonAltitude: 50, in: range).isEmpty)
        #expect(SolarDay.astronomicalNight(dawn: nil, dusk: nil, noonAltitude: -11.66, in: range).isEmpty)
        #expect(SolarDay.astronomicalNight(dawn: nil, dusk: nil, noonAltitude: -20, in: range) == [span(0, 24)])
    }

    @Test func makeKeepsOnlyTheMoonsCrossingsWithinTheDay() throws {
        var readings = SolarDay.Readings(transitions: day.transitions, noonAltitude: 49, sunrise: day.sunrise, sunset: day.sunset)
        readings.moon = SolarDay.Moon(phase: .full, illumination: 1, rise: at(-2), set: at(7))
        let made = try SolarDay.make(calendar: calendar, dayStart: day.dayStart, dayEnd: day.dayEnd, readings: readings)

        #expect(made.moon == SolarDay.Moon(phase: .full, illumination: 1, rise: nil, set: at(7)))
    }

    /// With only a set, the moon was up at midnight, and with only a rise, it was down.
    @Test func theFirstMoonCrossingTellsWhetherItWasUpAtMidnight() {
        #expect(night(moonrise: nil, moonset: 4).moonUp == [span(0, 4)])
        #expect(night(moonrise: 15, moonset: nil).moonUp == [span(15, 24)])
        #expect(night(moonrise: 12, moonset: 22).moonUp == [span(12, 22)])
        #expect(night(moonrise: 22, moonset: 12).moonUp == [span(0, 12), span(22, 24)])
    }

    @Test func withNeitherMoonCrossingTheSkysDarknessIsUnknown() {
        let polar = night(moonrise: nil, moonset: nil, astronomicalNight: [span(0, 5)])

        #expect(polar.moonUp == nil)
        #expect(polar.darkSky == nil)
        #expect(SolarDay.mock(.polarNight, for: date, calendar: calendar).darkSky == nil)
    }

    /// A summer's day near the pole with the moon up or down throughout still has no dark sky,
    /// since the sky never gets that dark wherever the moon is.
    @Test func withoutAstronomicalNightThereIsNoDarkSkyEvenWithTheMoonUnknown() {
        let day = night(moonrise: nil, moonset: nil)

        #expect(day.moonUp == nil)
        #expect(day.darkSky?.isEmpty == true)
    }

    @Test func darkSkyIsAstronomicalNightWithTheMoonDown() {
        let day = night(moonrise: 22, moonset: 3, astronomicalNight: [span(0, 5), span(21, 24)])

        #expect(day.darkSky == [span(3, 5), span(21, 22)])
    }

    /// San Francisco's waxing crescent sets at 10:07 PM, after astronomical dusk at 8:44.
    @Test func theTypicalDayHasDarkSkyBeforeDawnAndAfterMoonset() {
        #expect(day.darkSky == [span(0, 5 + 23.0 / 60), span(22 + 7.0 / 60, 24)])
    }

    /// Longyearbyen's June never reaches astronomical night, so there's no dark sky though the moon is known.
    @Test func noAstronomicalNightMeansNoDarkSky() {
        #expect(SolarDay.mock(.midnightSun, for: date, calendar: calendar).darkSky?.isEmpty == true)
    }

    // MARK: Helpers

    private var range: Range<Date> {
        day.dayStart..<day.dayEnd
    }

    /// `hours` into the mock's day.
    private func at(_ hours: Double) -> Date {
        day.dayStart.addingTimeInterval(hours * 60 * 60)
    }

    private func span(_ start: Double, _ end: Double) -> DateInterval {
        DateInterval(start: at(start), end: at(end))
    }

    /// The mock day with the moon crossing at the given hours and `astronomicalNight` in place of its own.
    private func night(moonrise: Double?, moonset: Double?, astronomicalNight: [DateInterval] = []) -> SolarDay {
        var day = self.day
        day.moon = SolarDay.Moon(phase: .full, illumination: 1, rise: moonrise.map(at), set: moonset.map(at))
        day.astronomicalNight = astronomicalNight
        return day
    }

    /// A change `hours` into the mock's day.
    private func change(hours: Double, _ from: DayPhase, _ into: DayPhase) -> PhaseTransition {
        PhaseTransition(date: day.dayStart.addingTimeInterval(hours * 60 * 60), from: from, into: into)
    }

    private func make(
        _ transitions: [PhaseTransition],
        noonAltitude: Double = 40,
        sunrise: Date? = nil,
        sunset: Date? = nil
    ) throws -> SolarDay {
        try SolarDay.make(
            calendar: calendar,
            dayStart: day.dayStart,
            dayEnd: day.dayEnd,
            readings: SolarDay.Readings(transitions: transitions, noonAltitude: noonAltitude, sunrise: sunrise, sunset: sunset)
        )
    }

    private func segment(from start: Date, minutes: Double) -> DaySegment {
        DaySegment(id: 0, phase: .goldenHour, interval: DateInterval(start: start, duration: minutes * 60), span: .range)
    }
}

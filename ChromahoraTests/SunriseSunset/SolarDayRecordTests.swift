//
//  SolarDayRecordTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Real responses, decoded the way the client does, drawn as the day each came from.
struct SolarDayRecordTests {
    @Test func aTypicalDayPassesThroughEveryPhase() throws {
        let day = try solarDay(from: SunriseSunsetFixtures.sanFrancisco)

        #expect(day.phaseSequence == SolarDay.mock().phaseSequence)
        #expect(day.events.map(\.title) == ["Sunrise", "Sunset"])
    }

    /// Windowed to Tokyo, San Francisco's day opens in the previous afternoon's daylight
    /// and its evening crossings come first.
    @Test func aFarTimeZoneStillChains() throws {
        let day = try solarDay(from: SunriseSunsetFixtures.sanFranciscoInTokyo)

        #expect(day.phaseSequence == [.daylight, .goldenHour, .blueHour, .night, .blueHour, .goldenHour, .daylight])
    }

    @Test(arguments: [
        (SunriseSunsetFixtures.reykjavik, MockScenario.allDayGolden),
        (SunriseSunsetFixtures.trondheim, .goldenNight),
        (SunriseSunsetFixtures.stPetersburg, .blueHourPastMidnight),
        (SunriseSunsetFixtures.tromso, .polarTwilight),
        (SunriseSunsetFixtures.longyearbyenJune, .midnightSun),
        (SunriseSunsetFixtures.longyearbyenDecember, .polarNight)
    ])
    func highLatitudeDaysMatchTheirScenarios(fixture: SunriseSunsetFixtures.Fixture, scenario: MockScenario) throws {
        let day = try solarDay(from: fixture)

        #expect(day.phaseSequence == SolarDay.mock(scenario).phaseSequence)
    }

    @Test(arguments: [(SunriseSunsetFixtures.chicagoSpringForward, 23.0), (SunriseSunsetFixtures.chicagoFallBack, 25.0)])
    func daylightSavingDaysTile(fixture: SunriseSunsetFixtures.Fixture, hours: Double) throws {
        let day = try solarDay(from: fixture)

        #expect(day.duration == hours * 60 * 60)
        #expect(day.phaseSequence == SolarDay.mock().phaseSequence)
        #expect(day.segments.allSatisfy { $0.interval.duration > 0 })
    }

    /// The full moon sets at 7 AM, just before sunrise, and rises at 6:53 PM, just before sunset.
    @Test func theMoonAndAstronomicalNightComeThrough() throws {
        let day = try solarDay(from: SunriseSunsetFixtures.sanFrancisco)
        let moon = try #require(day.moon)

        #expect(moon.phase == .full)
        #expect(moon.illumination == 0.9992)
        #expect(moon.rise == Date(timeIntervalSince1970: 1_790_474_010))
        #expect(moon.set == Date(timeIntervalSince1970: 1_790_431_250))
        #expect(day.astronomicalNight == [
            DateInterval(start: day.dayStart, end: Date(timeIntervalSince1970: 1_790_426_005)),
            DateInterval(start: Date(timeIntervalSince1970: 1_790_479_647), end: day.dayEnd)
        ])
    }

    /// Windowed to Tokyo, astronomical dusk comes before dawn, so the night falls mid-day.
    @Test func aFarTimeZonesAstronomicalNightFallsBetweenItsCrossings() throws {
        let day = try solarDay(from: SunriseSunsetFixtures.sanFranciscoInTokyo)

        #expect(day.astronomicalNight == [
            DateInterval(start: Date(timeIntervalSince1970: 1_790_393_344), end: Date(timeIntervalSince1970: 1_790_426_005))
        ])
    }

    /// Longyearbyen's December has astronomical twilight around noon but no moonrise or moonset,
    /// and Trondheim's June never reaches astronomical night.
    @Test func highLatitudesLeaveTheNightSkyPartlyUnknown() throws {
        let december = try solarDay(from: SunriseSunsetFixtures.longyearbyenDecember)
        #expect(december.astronomicalNight.count == 2)
        #expect(december.moon?.phase == .waxingGibbous)
        #expect(december.moonUp == nil)
        #expect(december.darkSky == nil)

        let june = try solarDay(from: SunriseSunsetFixtures.trondheim)
        #expect(june.astronomicalNight.isEmpty)
        #expect(june.darkSky?.isEmpty == true)
    }

    /// A name the app doesn't know only hides the moon's phase, and a response without any
    /// of the night sky still draws the day.
    @Test func anUnknownOrMissingNightSkyStillDrawsTheDay() throws {
        let json = """
            {"days": [{
                "date": "2026-09-26", "sunrise": null, "sunset": null,
                "golden_hour": {"morning": {"begin": null, "end": null}, "evening": {"begin": null, "end": null}},
                "blue_hour": {"morning": {"begin": null, "end": null}, "evening": {"begin": null, "end": null}},
                "solar_position": {"solar_noon_altitude": 50},
                "moon_phase": "Blue Moon", "moon_illumination": 100
            }]}
            """
        let day = try solarDay(from: SunriseSunsetFixtures.Fixture(timeZone: "America/Los_Angeles", json: json))

        #expect(day.phaseSequence == [.daylight])
        #expect(day.moon == SolarDay.Moon(phase: nil, illumination: 1))
        #expect(day.astronomicalNight.isEmpty)
    }

    @Test func crossingsThatDontChainAreRejected() throws {
        // Golden hour ends into daylight, then blue hour ends into night, with nothing between.
        let json = """
            {"days": [{
                "date": "2026-09-26", "sunrise": null, "sunset": null,
                "golden_hour": {"morning": {"begin": null, "end": 1790433343}, "evening": {"begin": null, "end": null}},
                "blue_hour": {"morning": {"begin": null, "end": null}, "evening": {"begin": null, "end": 1790475970}},
                "solar_position": {"solar_noon_altitude": 50}
            }]}
            """
        let fixture = SunriseSunsetFixtures.Fixture(timeZone: "America/Los_Angeles", json: json)

        #expect(throws: SolarDayError.inconsistentPhases) {
            try solarDay(from: fixture)
        }
    }

    /// St. Petersburg's June has no astronomical twilight, while San Francisco's day has every field.
    @Test(arguments: [SunriseSunsetFixtures.stPetersburg, SunriseSunsetFixtures.sanFrancisco])
    func recordsSurviveTheCachesRoundTrip(fixture: SunriseSunsetFixtures.Fixture) throws {
        let records = try SunriseSunsetClient.records(from: Data(fixture.json.utf8))
        let data = try SolarDayRecord.makeEncoder().encode(records)

        #expect(try SolarDayRecord.makeDecoder().decode([SolarDayRecord].self, from: data) == records)
    }

    /// Chicago's March 8 has a moonset but no moonrise, so the waning moon is up from midnight until it sets.
    @Test func aDayWithOnlyAMoonsetHasTheMoonUpUntilIt() throws {
        let day = try solarDay(from: SunriseSunsetFixtures.chicagoSpringForward)

        #expect(day.moonUp == [DateInterval(start: day.dayStart, end: Date(timeIntervalSince1970: 1_772_979_269))])
    }

    /// The fixture's only day, from midnight to midnight in the zone it was windowed to.
    private func solarDay(from fixture: SunriseSunsetFixtures.Fixture) throws -> SolarDay {
        let record = try #require(try SunriseSunsetClient.records(from: Data(fixture.json.utf8)).first)
        let timeZone = try #require(TimeZone(identifier: fixture.timeZone))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = record.date.split(separator: "-").compactMap { Int($0) }
        let dayStart = try #require(calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])))
        let dayEnd = try #require(calendar.date(byAdding: .day, value: 1, to: dayStart))
        return try record.solarDay(calendar: calendar, dayStart: dayStart, dayEnd: dayEnd)
    }
}

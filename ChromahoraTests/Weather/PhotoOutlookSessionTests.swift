//
//  PhotoOutlookSessionTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Which stretches of a day the outlook rates, and what it reads of the hours over them.
struct PhotoOutlookSessionTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    private func day(_ scenario: MockScenario = .typical) -> SolarDay {
        .mock(scenario, for: date, calendar: calendar)
    }

    private var hours: [SkyHour] {
        SkyHour.mock(for: date, calendar: calendar)
    }

    /// A clock time on the mock's day, which starts at midnight GMT.
    private func time(_ hour: Int, _ minute: Int = 0, on day: SolarDay? = nil) -> Date {
        (day ?? self.day()).dayStart.addingTimeInterval(TimeInterval(hour * 60 * 60 + minute * 60))
    }

    // MARK: The typical day

    /// The mock's cloudier small hours, its low morning cloud, its afternoon shower and the
    /// clear evening and night after it. The small hours don't dim tonight, which reads only its own sky.
    @Test func theMockDayRatesEachSession() throws {
        let sessions = PhotoOutlook.sessions(on: day(), hours: hours)

        #expect(sessions.map(\.kind) == [.beforeDawn, .morning, .daylight, .evening, .night])
        #expect(sessions.map(\.rating) == [.good, .poor, .poor, .great, .excellent])
        #expect(sessions[0].reasons == ["Cloud hides some stars"])
        #expect(sessions[1].reasons == ["Low cloud blocks the sun", "Calm air for reflections"])
        #expect(sessions[2].reasons == ["80% chance of rain", "Harsh light, UV 6", "Broken cloud, uneven light"])
        #expect(sessions[3].reasons == ["Clean air after rain", "Little cloud to catch color", "Calm air for reflections"])
        #expect(sessions[4].reasons == ["Clear sky for stars"])
        #expect(abs(sessions[3].cloudCover - 0.2) < 0.0001)
    }

    /// The dark sky parts at noon, before dawn and tonight.
    @Test func sessionsCoverTheMagicHoursTheDaylightAndTheDarkSky() throws {
        let sessions = PhotoOutlook.sessions(on: day(), hours: hours)
        let darkSky = try #require(day().darkSky)

        #expect(sessions[0].intervals == darkSky.filter { $0.end <= time(12) })
        #expect(sessions[1].intervals == [DateInterval(start: time(6, 12), end: time(6, 38)), DateInterval(start: time(6, 38), end: time(7, 42))])
        #expect(sessions[2].intervals == [DateInterval(start: time(7, 42), end: time(18, 5))])
        #expect(sessions[3].start == time(18, 5))
        #expect(sessions[3].end == time(19, 36))
        #expect(sessions[4].intervals == darkSky.filter { $0.start >= time(12) })
        #expect(sessions[0].intervals + sessions[4].intervals == darkSky)
    }

    /// The golden hour, the longest stretch of an end, is where the timeline centers.
    @Test func aSessionFocusesOnItsLongestStretch() throws {
        let evening = try #require(PhotoOutlook.sessions(on: day(), hours: hours).first { $0.kind == .evening })

        #expect(evening.focusDate == time(18, 37).addingTimeInterval(30))
    }

    /// The timeline's golden- and blue-hour labels carry their end's session, the daylight's its
    /// own, and each night the dark sky it holds.
    @Test func theLabelsCarryTheirSessions() {
        let sessions = PhotoOutlook.sessions(on: day(), hours: hours)

        #expect(PhotoOutlook.labelSessions(on: day(), hours: hours) == [
            time(0): sessions[0], time(6, 12): sessions[1], time(6, 38): sessions[1], time(7, 42): sessions[2],
            time(18, 5): sessions[3], time(19, 10): sessions[3], time(19, 36): sessions[4]
        ])
    }

    @Test func aGoldenOrBlueHourFindsItsSession() throws {
        let run = DayRun(day())
        let blueHour = try #require(day().segments.first { $0.phase == .blueHour && $0.interval.start > time(12) })
        let evening = PhotoOutlook.sessions(on: day(), hours: hours).first { $0.kind == .evening }

        #expect(PhotoOutlook.session(for: blueHour, in: run, hours: hours) == evening)
    }

    // MARK: Missing hours

    @Test func noHoursRateNothing() {
        #expect(PhotoOutlook.sessions(on: day(), hours: []).isEmpty)
        #expect(PhotoOutlook.labelSessions(on: day(), hours: []).isEmpty)
    }

    /// A missing hour leaves out only the session it falls in.
    @Test func aGapLeavesOutOnlyTheSessionItTouches() {
        let gapped = hours.filter { $0.date != time(12) }

        #expect(PhotoOutlook.sessions(on: day(), hours: gapped).map(\.kind) == [.beforeDawn, .morning, .evening, .night])
    }

    /// Each hour counts for the share of the session it covers: a quarter of clear sky and
    /// three quarters of overcast read as 75% cover.
    @Test func hoursAreWeightedByHowMuchOfTheSessionTheyCover() throws {
        func sky(at hour: Int, cover: Double) -> SkyHour {
            SkyHour(
                date: time(hour), uvIndex: 0, lowCloud: cover, midCloud: cover, highCloud: cover, cloudCover: cover,
                visibility: 10_000, precipitation: nil, precipitationChance: 0, windSpeed: 0
            )
        }
        let session = DateInterval(start: time(18, 45), end: time(19, 45))
        let readings = try #require(PhotoOutlook.Readings(over: [session], hours: [sky(at: 18, cover: 0), sky(at: 19, cover: 1)]))

        #expect(abs(readings.cloudCover - 0.75) < 0.0001)
        #expect(PhotoOutlook.Readings(over: [session], hours: [sky(at: 18, cover: 0)]) == nil)
    }

    // MARK: High latitudes

    /// Reykjavík in December: the moon is up through all of astronomical night, which holds the
    /// small hours and tonight at Fair, and the evening has only a blue hour, whose label carries its rating.
    @Test func aMoonUpAllNightHoldsTheNightAtFair() throws {
        let day = day(.allDayGolden)
        let sessions = PhotoOutlook.sessions(on: day, hours: hours)
        let nights = sessions.filter(\.kind.isNight)

        #expect(sessions.map(\.kind) == [.beforeDawn, .morning, .evening, .night])
        #expect(nights.flatMap(\.intervals) == day.astronomicalNight)
        #expect(nights.map(\.rating) == [.fair, .fair])
        #expect(nights.allSatisfy { $0.reasons.contains("Moonlight washes out stars") })
        #expect(Set(PhotoOutlook.labelSessions(on: day, hours: hours).keys) == [
            time(0, on: day), time(10, 3, on: day), time(10, 30, on: day), time(16, 21, on: day), time(16, 48, on: day)
        ])
    }

    /// Longyearbyen's polar night can't place its moon, so astronomical night is rated without
    /// it, on each side of the twilight at noon. Its one night's label carries tonight's.
    @Test func aNightWithoutAMoonRatesAstronomicalNight() throws {
        let day = day(.polarNight)
        let sessions = PhotoOutlook.sessions(on: day, hours: hours)

        #expect(sessions.map(\.kind) == [.beforeDawn, .night])
        #expect(sessions.flatMap(\.intervals) == day.astronomicalNight)
        #expect(!sessions.contains { $0.reasons.contains("Moonlight washes out stars") })
        #expect(PhotoOutlook.labelSessions(on: day, hours: hours) == [day.dayStart: sessions[1]])
    }

    @Test(arguments: [MockScenario.goldenNight, .blueHourPastMidnight, .midnightSun])
    func aDayThatNeverGetsFullyDarkHasNoNight(scenario: MockScenario) {
        #expect(!PhotoOutlook.sessions(on: day(scenario), hours: hours).contains { $0.kind.isNight })
    }

    @Test func aMidnightSunRatesOnlyItsDaylight() {
        #expect(PhotoOutlook.sessions(on: day(.midnightSun), hours: hours).map(\.kind) == [.daylight])
    }

    /// Tromsø in December: the morning's blue and golden hours and the evening's lone blue hour
    /// carry their ends' sessions, and each night a night session of its own.
    @Test func polarTwilightLabelsEveryMagicHour() {
        let day = day(.polarTwilight)

        #expect(Set(PhotoOutlook.labelSessions(on: day, hours: hours).keys) == [
            time(0, on: day), time(9, 14, on: day), time(10, 6, on: day), time(13, 7, on: day), time(13, 58, on: day)
        ])
    }

    /// St. Petersburg in June: a blue hour that began the evening before belongs to no session
    /// today, and tonight's runs past midnight, so the evening needs tomorrow's hours too.
    @Test func anEveningPastMidnightNeedsTomorrowsHours() throws {
        let today = day(.blueHourPastMidnight)
        let tomorrow = SolarDay.mock(.blueHourPastMidnight, for: today.dayEnd, calendar: calendar)
        let run = DayRun(today, then: [tomorrow])
        let bothDays = hours + SkyHour.mock(for: today.dayEnd, calendar: calendar)

        #expect(!PhotoOutlook.sessions(on: today, in: run, hours: hours).contains { $0.kind == .evening })
        let evening = try #require(PhotoOutlook.sessions(on: today, in: run, hours: bothDays).first { $0.kind == .evening })
        #expect(evening.end == time(0, 10, on: tomorrow))
        #expect(PhotoOutlook.sessions(on: today, hours: bothDays).first { $0.kind == .morning }?.start == time(1, 50, on: today))
    }
}

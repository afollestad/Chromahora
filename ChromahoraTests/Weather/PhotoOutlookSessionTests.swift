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

    /// The mock's low morning cloud, its afternoon shower and the clear evening after it.
    @Test func theMockDayRatesEachSession() throws {
        let sessions = PhotoOutlook.sessions(on: day(), hours: hours)

        #expect(sessions.map(\.kind) == [.morning, .daylight, .evening, .night])
        #expect(sessions.map(\.rating) == [.poor, .poor, .great, .good])
        #expect(sessions[0].reasons == ["Low cloud may block the sun", "Calm air for reflections"])
        #expect(sessions[1].reasons == ["80% chance of rain", "Harsh light, UV 6", "Broken cloud"])
        #expect(sessions[2].reasons == ["Clearing after rain", "Clear sky", "Calm air for reflections"])
        #expect(sessions[3].reasons == ["Partly cloudy"])
        #expect(abs(sessions[2].cloudCover - 0.2) < 0.0001)
    }

    @Test func sessionsCoverTheMagicHoursTheDaylightAndTheDarkSky() {
        let sessions = PhotoOutlook.sessions(on: day(), hours: hours)

        #expect(sessions[0].intervals == [DateInterval(start: time(6, 12), end: time(6, 38)), DateInterval(start: time(6, 38), end: time(7, 42))])
        #expect(sessions[1].intervals == [DateInterval(start: time(7, 42), end: time(18, 5))])
        #expect(sessions[2].start == time(18, 5))
        #expect(sessions[2].end == time(19, 36))
        #expect(sessions[3].intervals == day().darkSky)
    }

    /// The golden hour, the longest stretch of an end, is where the timeline centers.
    @Test func aSessionFocusesOnItsLongestStretch() {
        let evening = PhotoOutlook.sessions(on: day(), hours: hours)[2]

        #expect(evening.focusDate == time(18, 37).addingTimeInterval(30))
    }

    /// The timeline's golden-hour labels carry their end's rating.
    @Test func goldenHoursCarryTheirEndsRating() {
        #expect(PhotoOutlook.labelRatings(on: day(), hours: hours) == [time(6, 38): .poor, time(18, 5): .great])
    }

    @Test func aGoldenOrBlueHourFindsItsSession() throws {
        let run = DayRun(day())
        let blueHour = try #require(day().segments.first { $0.phase == .blueHour && $0.interval.start > time(12) })
        let evening = PhotoOutlook.sessions(on: day(), hours: hours)[2]

        #expect(PhotoOutlook.session(for: blueHour, in: run, hours: hours) == evening)
    }

    // MARK: Missing hours

    @Test func noHoursRateNothing() {
        #expect(PhotoOutlook.sessions(on: day(), hours: []).isEmpty)
        #expect(PhotoOutlook.labelRatings(on: day(), hours: []).isEmpty)
    }

    /// A missing hour leaves out only the session it falls in.
    @Test func aGapLeavesOutOnlyTheSessionItTouches() {
        let gapped = hours.filter { $0.date != time(12) }

        #expect(PhotoOutlook.sessions(on: day(), hours: gapped).map(\.kind) == [.morning, .evening, .night])
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

    /// Reykjavík in December: the moon is up through all of astronomical night, and the
    /// evening has only a blue hour, whose label carries its rating.
    @Test func aMoonUpAllNightHoldsTheNightAtFair() throws {
        let day = day(.allDayGolden)
        let sessions = PhotoOutlook.sessions(on: day, hours: hours)
        let night = try #require(sessions.last)

        #expect(sessions.map(\.kind) == [.morning, .evening, .night])
        #expect(night.intervals == day.astronomicalNight)
        #expect(night.rating == .fair)
        #expect(night.reasons.contains("Moon up"))
        #expect(Set(PhotoOutlook.labelRatings(on: day, hours: hours).keys) == [time(10, 30, on: day), time(16, 21, on: day)])
    }

    /// Longyearbyen's polar night can't place its moon, so astronomical night is rated without it.
    @Test func aNightWithoutAMoonRatesAstronomicalNight() throws {
        let day = day(.polarNight)
        let sessions = PhotoOutlook.sessions(on: day, hours: hours)

        #expect(sessions.map(\.kind) == [.night])
        #expect(sessions[0].intervals == day.astronomicalNight)
        #expect(!sessions[0].reasons.contains("Moon up"))
    }

    @Test(arguments: [MockScenario.goldenNight, .blueHourPastMidnight, .midnightSun])
    func aDayThatNeverGetsFullyDarkHasNoNight(scenario: MockScenario) {
        #expect(!PhotoOutlook.sessions(on: day(scenario), hours: hours).contains { $0.kind == .night })
    }

    @Test func aMidnightSunRatesOnlyItsDaylight() {
        #expect(PhotoOutlook.sessions(on: day(.midnightSun), hours: hours).map(\.kind) == [.daylight])
    }

    /// Tromsø in December: the morning's golden hour and the evening's lone blue hour carry the labels.
    @Test func polarTwilightLabelsTheGoldenHourAndTheEveningsBlueHour() {
        let day = day(.polarTwilight)

        #expect(Set(PhotoOutlook.labelRatings(on: day, hours: hours).keys) == [time(10, 6, on: day), time(13, 7, on: day)])
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

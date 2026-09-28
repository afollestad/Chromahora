//
//  SnapshotTests+Timeline.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
@testable import Chromahora

extension SnapshotTests {
    @Test func afternoon() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(16, 30)))
    }

    /// The timeline can't center this early, so it rests at midnight, with the
    /// navigation bar in its dark scheme over night.
    @Test func beforeDawn() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(3)))
    }

    /// Now lands two minutes after sunrise, so its label is pushed below Sunrise's.
    @Test func justAfterSunrise() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(7)))
    }

    /// The title sits about five hours above now, so these put it over the blend between
    /// blue and golden hour on either side of the bar's scheme flip, clear of its margin.
    @Test func titleOverDawnBeforeFlip() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(11, 35)))
    }

    @Test func titleOverDawnAfterFlip() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(11, 55)))
    }

    /// The labels stop growing at accessibility1, and phase labels that can land beside a
    /// marker drop their time range to fit.
    @Test func largestTextSize() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(7)).environment(\.dynamicTypeSize, .accessibility5))
    }

    /// With now on another day there's no now marker, and the timeline centers on daylight.
    @Test func anotherDay() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(day: 17, 9)))
    }

    // MARK: Weather

    /// A spell for forecasts that `WeatherSpell.mock(for:)` doesn't shape.
    private func spell(_ condition: SkyCondition, _ start: Date, _ end: Date, chance: Double = 0, cover: Double) -> WeatherSpell {
        WeatherSpell(condition: condition, interval: DateInterval(start: start, end: end), precipitationChance: chance, cloudCover: cover)
    }

    /// Rain at 3 PM draws a dashed line, and the clear sky after it shows the sun just below Now.
    @Test func weatherThisAfternoon() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(16, 30), weather: WeatherSpell.mock(for: time(12))))
    }

    /// The clear night under way at midnight is marked there with the moon, clear of the
    /// bar, above the clouds that arrive at 4 AM.
    @Test func weatherBeforeDawn() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(3), weather: WeatherSpell.mock(for: time(12))))
    }

    /// Now, Sunset and rain starting ten minutes after it stack in time order, and the
    /// clear night after the rain shows the moon.
    @Test func rainJustAfterSunset() async throws {
        let weather = [
            spell(.partlyCloudy, try time(12), try time(19), cover: 0.5),
            spell(.rain, try time(19), try time(21), chance: 0.7, cover: 1),
            spell(.clear, try time(21), try time(day: 17, 0), cover: 0.1)
        ]
        try await assertScreenSnapshot(of: timeline(now: time(18, 40), weather: weather))
    }

    /// The icon for clouds arriving fifteen minutes before sunset rises to make room, so
    /// Sunset's label stays on its line.
    @Test func cloudsJustBeforeSunset() async throws {
        let weather = [
            spell(.partlyCloudy, try time(12), try time(18, 35), cover: 0.5),
            spell(.cloudy, try time(18, 35), try time(day: 17, 0), cover: 0.9)
        ]
        try await assertScreenSnapshot(of: timeline(now: time(16, 30), weather: weather))
    }

    /// Weather icons keep their place among marker labels that have grown.
    @Test func weatherAtLargestTextSize() async throws {
        let timeline = try timeline(now: time(7), weather: WeatherSpell.mock(for: time(12)))
        await assertScreenSnapshot(of: timeline.environment(\.dynamicTypeSize, .accessibility5))
    }

    /// The sunset line passes behind the Apple Weather mark near the sky's scheme crossover,
    /// blurred by the bottom edge effect rather than showing through the mark's text.
    @Test func sunsetUnderWeatherMark() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(13, 25), weather: WeatherSpell.mock(for: time(12))))
    }

    /// A forecast that misses the day marks no weather, so the sources button reads Sources.
    @Test func weatherOnAnotherDay() async throws {
        try await assertScreenSnapshot(of: timeline(now: time(16, 30), weather: WeatherSpell.mock(for: time(day: 17, 12))))
    }

    // MARK: High-latitude days, on the dates their scenarios come from

    /// Reykjavík's December golden hour lasts all day and holds its color, with no daylight.
    @Test func allDayGolden() async throws {
        try await assertScreenSnapshot(of: timeline(.allDayGolden, now: time(month: 12, day: 21, 12)))
    }

    /// Trondheim's June night is golden hour, with no night or blue hour.
    @Test func goldenNight() async throws {
        try await assertScreenSnapshot(of: timeline(.goldenNight, now: time(month: 6, day: 21, 1)))
    }

    /// St. Petersburg's June blue hour runs past midnight at both ends. Near either end,
    /// the timeline scrolls far enough for the now marker and the short cut-off phase's
    /// label to clear the bar and home indicator.
    @Test func blueHourPastMidnightAtStart() async throws {
        try await assertScreenSnapshot(of: timeline(.blueHourPastMidnight, now: time(month: 6, day: 21, 0, 5)))
    }

    @Test func blueHourPastMidnightAtEnd() async throws {
        try await assertScreenSnapshot(of: timeline(.blueHourPastMidnight, now: time(month: 6, day: 21, 23, 50)))
    }

    /// Tromsø's December twilight never reaches sunrise.
    @Test func polarTwilight() async throws {
        try await assertScreenSnapshot(of: timeline(.polarTwilight, now: time(month: 12, day: 10, 11, 30)))
    }

    /// A day in one phase labels it as lasting all day.
    @Test func midnightSun() async throws {
        try await assertScreenSnapshot(of: timeline(.midnightSun, now: time(month: 6, day: 21, 12)))
    }

    @Test func polarNight() async throws {
        try await assertScreenSnapshot(of: timeline(.polarNight, now: time(month: 12, day: 21, 12)))
    }
}

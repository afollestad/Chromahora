//
//  SnapshotTests.swift
//  ChromahoraTests
//

import Foundation
import SwiftUI
import Testing
@testable import Chromahora

/// Full-screen snapshots on the iPhone, grouped into `+Topic` files by screen. Serialized,
/// since each snapshot puts its own window over the whole screen.
@MainActor
@Suite(.serialized)
struct SnapshotTests: ScreenSnapshotting {
    /// The timeline for September 16 at `now`, which may fall on another day, marked with
    /// `weather`. `ContentView` can't stand in, since its `TimelineView` reads the real clock
    /// and its stores load.
    func timeline(now: Date, weather: [WeatherSpell] = []) throws -> some View {
        timeline(of: SolarDay.mock(for: try time(12)), now: now, weather: weather)
    }
}

/// The dates and screens both snapshot suites build.
@MainActor
protocol ScreenSnapshotting {}

extension ScreenSnapshotting {
    /// A time in 2026, on September 16 unless given another day. Callers pick days
    /// with no daylight saving change in any time zone, like June 21 and December 21.
    /// Built from local components, so the mock day's times and the labels formatted
    /// from them read the same wherever the tests run.
    func time(month: Int = 9, day: Int = 16, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try time(month: month, day: day, hour, minute, in: .current)
    }

    /// A time in 2026 on the clock of `calendar`, as for a place chosen in another zone. Its mock
    /// day and labels read in that zone, so they read the same wherever the tests run.
    func time(month: Int = 9, day: Int = 16, _ hour: Int, _ minute: Int = 0, in calendar: Calendar) throws -> Date {
        let components = DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
        return try #require(calendar.date(from: components))
    }

    /// The device's calendar in the zone named `identifier`.
    func calendar(in identifier: String) throws -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        return calendar
    }

    /// The timeline for `scenario` on the day containing `now`.
    func timeline(_ scenario: MockScenario, now: Date) -> some View {
        timeline(of: SolarDay.mock(scenario, for: now), now: now)
    }

    /// The timeline for `day`, read in the day's own zone, as the store windows it.
    func timeline(of day: SolarDay, now: Date, weather: [WeatherSpell] = [], place: Place? = MockPlaceProvider.sanFrancisco) -> some View {
        screen(.loaded(day), selectedDate: day.dayStart, now: now, weather: weather, place: place, calendar: day.calendar)
    }

    /// The screen in `state`, with `selectedDate` chosen, at `now`, open on `initialPane`. The title
    /// names `place`, by `deviceName` when it's the device's, and dates read in `calendar`'s zone.
    func screen(
        _ state: SolarDayStore.LoadState,
        selectedDate: Date,
        now: Date,
        weather: [WeatherSpell] = [],
        hours: [SkyHour] = [],
        place: Place? = MockPlaceProvider.sanFrancisco,
        deviceName: String? = "San Francisco",
        calendar: Calendar = .current,
        initialPane: DayPager.Pane = .timeline
    ) -> some View {
        NavigationStack {
            DayScreen(
                state: state,
                now: now,
                selectedDate: .constant(selectedDate),
                calendar: calendar,
                place: place,
                deviceName: deviceName,
                chooser: .preview,
                weather: weather,
                hours: hours,
                initialPane: initialPane
            ) {}
        }
    }
}

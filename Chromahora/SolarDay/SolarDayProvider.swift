//
//  SolarDayProvider.swift
//  Chromahora
//

import Foundation

/// A source of solar schedules. Where the data comes from, and for which place,
/// is up to each provider, so replacing the mock with real data leaves callers alone.
protocol SolarDayProvider {
    /// The schedule for the day containing `date`, with day boundaries from `calendar`.
    func solarDay(for date: Date, calendar: Calendar) async throws -> SolarDay
}

/// Serves `SolarDay.mock(for:calendar:)` until real solar data is available.
struct MockSolarDayProvider: SolarDayProvider {
    func solarDay(for date: Date, calendar: Calendar) async throws -> SolarDay {
        .mock(for: date, calendar: calendar)
    }
}

//
//  SolarDayProvider.swift
//  Chromahora
//

import Foundation

/// A source of solar schedules. Where the data comes from is up to each provider, so
/// swapping one for another leaves callers alone.
protocol SolarDayProvider {
    /// The schedule at `place` for the day containing `date`, with day boundaries from `calendar`.
    func solarDay(for date: Date, at place: Place, calendar: Calendar) async throws -> SolarDay
}

/// Serves `scenario`'s times for any day and place, for previews, tests and the debug drawer.
struct MockSolarDayProvider: SolarDayProvider {
    var scenario: MockScenario = .typical

    func solarDay(for date: Date, at place: Place, calendar: Calendar) async throws -> SolarDay {
        .mock(scenario, for: date, calendar: calendar)
    }
}

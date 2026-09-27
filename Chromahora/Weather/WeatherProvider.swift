//
//  WeatherProvider.swift
//  Chromahora
//

import Foundation

/// A source of forecasts. Weather only adds to the timeline, so callers treat a failure as
/// no weather, never as a failed day.
protocol WeatherProvider {
    /// The weather spells at `place` from `start` to `end`, in time order.
    func spells(from start: Date, to end: Date, at place: Place) async throws -> [WeatherSpell]
}

/// Serves `WeatherSpell.mock`'s day for every day in the range, for previews and the debug drawer.
struct MockWeatherProvider: WeatherProvider {
    var calendar: Calendar = .current

    func spells(from start: Date, to end: Date, at place: Place) async throws -> [WeatherSpell] {
        var spells: [WeatherSpell] = []
        var day = calendar.startOfDay(for: start)
        while day < end {
            spells += WeatherSpell.mock(for: day, calendar: calendar)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = next
        }
        return spells
    }
}

nonisolated extension WeatherSpell {
    /// A day that passes through most conditions: clear until 4 AM, cloudy until 9, partly
    /// cloudy until 3 PM, rain until 5, then clear, in local clock time on the day containing `date`.
    static func mock(for date: Date = .now, calendar: Calendar = .current) -> [WeatherSpell] {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 60 * 60)

        func at(_ hour: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart)
                ?? dayStart.addingTimeInterval(TimeInterval(hour * 60 * 60))
        }

        let shape: [(condition: SkyCondition, start: Date)] = [
            (.clear, dayStart), (.cloudy, at(4)), (.partlyCloudy, at(9)), (.rain, at(15)), (.clear, at(17))
        ]
        func cover(_ condition: SkyCondition) -> Double {
            switch condition {
            case .clear: 0.1
            case .partlyCloudy: 0.45
            default: 0.9
            }
        }

        let ends = shape.dropFirst().map(\.start) + [dayEnd]
        return zip(shape, ends).map { spell, end in
            WeatherSpell(
                condition: spell.condition,
                interval: DateInterval(start: spell.start, end: end),
                precipitationChance: spell.condition == .rain ? 0.8 : 0.1,
                cloudCover: cover(spell.condition)
            )
        }
    }
}

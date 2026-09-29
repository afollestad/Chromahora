//
//  WeatherProvider.swift
//  Chromahora
//

import Foundation

/// What one forecast request brings back: the spells the timeline marks, and the hours the
/// day's light and sky readings come from.
nonisolated struct Forecast: Codable, Equatable, Sendable {
    /// WeatherKit forecasts hourly about ten days out, so one request covers every day it can.
    static let days = 10

    var spells: [WeatherSpell] = []
    var hours: [SkyHour] = []

    /// The window to ask for at `now`: `days` days from the start of its day in `calendar`,
    /// the zone days are windowed to. The app and its widgets ask for the same window, so
    /// each can answer from the other's request.
    static func window(at now: Date, calendar: Calendar) -> DateInterval? {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: days, to: start).map { DateInterval(start: start, end: $0) }
    }
}

/// A source of forecasts. Weather only adds to the timeline, so callers treat a failure as
/// no weather, never as a failed day.
protocol WeatherProvider {
    /// The forecast at `place` from `start` to `end`, its spells and hours each in time order.
    func forecast(from start: Date, to end: Date, at place: Place) async throws -> Forecast
}

/// Serves `WeatherSpell.mock`'s and `SkyHour.mock`'s day for every day in the range, for
/// previews and the debug drawer.
struct MockWeatherProvider: WeatherProvider {
    var calendar: Calendar = .current

    func forecast(from start: Date, to end: Date, at place: Place) async throws -> Forecast {
        var forecast = Forecast()
        var day = calendar.startOfDay(for: start)
        while day < end {
            forecast.spells += WeatherSpell.mock(for: day, calendar: calendar)
            forecast.hours += SkyHour.mock(for: day, calendar: calendar)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = next
        }
        return forecast
    }
}

nonisolated extension WeatherSpell {
    /// A day that passes through most conditions: clear until 4 AM, cloudy until 9, partly
    /// cloudy until 3 PM, rain until 5, then clear, in local clock time on the day containing `date`.
    static func mock(for date: Date = .now, calendar: Calendar = .current) -> [WeatherSpell] {
        let dayStart = calendar.startOfDay(for: date)
        // Where the next day starts, which a day added to this one's start misses by an hour
        // where clocks spring forward at midnight, as Santiago's do, and the day starts at 1 AM.
        let dayEnd = calendar.dateInterval(of: .day, for: dayStart)?.end
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

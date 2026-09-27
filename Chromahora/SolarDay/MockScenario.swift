//
//  MockScenario.swift
//  Chromahora
//

import Foundation

/// Day shapes for previews, tests and the debug drawer, in local clock time. Apart from
/// `typical`, they copy sunrise-sunset.org's answers for 2026 at high latitudes, where
/// days skip phases or carry them past midnight.
nonisolated enum MockScenario: String, CaseIterable, Identifiable, Sendable {
    /// Every phase in the usual order, on a late-September day.
    case typical
    /// Reykjavík on December 21: golden hour from 10:30 to 16:21, with no daylight.
    case allDayGolden
    /// Trondheim on June 21: golden hour across midnight, with no night or blue hour.
    case goldenNight
    /// St. Petersburg on June 21: the night before's blue hour runs to 00:10, and the
    /// evening's runs past midnight.
    case blueHourPastMidnight
    /// Tromsø on December 10: blue, golden and blue again, with no sunrise.
    case polarTwilight
    /// Longyearbyen on June 21: daylight all day.
    case midnightSun
    /// Longyearbyen on December 21: night all day.
    case polarNight

    var id: Self { self }

    var title: String {
        switch self {
        case .typical: "Typical"
        case .allDayGolden: "All-day golden (Reykjavík, Dec)"
        case .goldenNight: "Golden night (Trondheim, Jun)"
        case .blueHourPastMidnight: "Blue past midnight (St. Petersburg, Jun)"
        case .polarTwilight: "Polar twilight (Tromsø, Dec)"
        case .midnightSun: "Midnight sun (Longyearbyen, Jun)"
        case .polarNight: "Polar night (Longyearbyen, Dec)"
        }
    }

    /// The sun's altitude at solar noon, in degrees, which names the phase of a day
    /// with no phase changes.
    var noonAltitude: Double {
        switch self {
        case .typical: 49
        case .allDayGolden: 2.41
        case .goldenNight: 50.01
        case .blueHourPastMidnight: 53.5
        case .polarTwilight: -2.58
        case .midnightSun: 35.22
        case .polarNight: -11.66
        }
    }

    fileprivate typealias ClockTime = (hour: Int, minute: Int)

    fileprivate struct Shape {
        let initial: DayPhase
        /// Each change as the time it happens and the phase it enters.
        let changes: [(ClockTime, DayPhase)]
        var sunrise: ClockTime?
        var sunset: ClockTime?
    }

    fileprivate var shape: Shape {
        switch self {
        case .typical:
            Shape(initial: .night, changes: [
                ((6, 12), .blueHour), ((6, 38), .goldenHour), ((7, 42), .daylight),
                ((18, 5), .goldenHour), ((19, 10), .blueHour), ((19, 36), .night)
            ], sunrise: (6, 58), sunset: (18, 50))
        case .allDayGolden:
            Shape(initial: .night, changes: [
                ((10, 3), .blueHour), ((10, 30), .goldenHour), ((16, 21), .blueHour), ((16, 48), .night)
            ], sunrise: (11, 22), sunset: (15, 29))
        case .goldenNight:
            Shape(initial: .goldenHour, changes: [((4, 49), .daylight), ((21, 51), .goldenHour)], sunrise: (3, 2), sunset: (23, 38))
        case .blueHourPastMidnight:
            Shape(initial: .blueHour, changes: [
                ((0, 10), .night), ((1, 50), .blueHour), ((2, 43), .goldenHour),
                ((4, 54), .daylight), ((21, 6), .goldenHour), ((23, 17), .blueHour)
            ], sunrise: (3, 35), sunset: (22, 25))
        case .polarTwilight:
            Shape(initial: .night, changes: [((9, 14), .blueHour), ((10, 6), .goldenHour), ((13, 7), .blueHour), ((13, 58), .night)])
        case .midnightSun:
            Shape(initial: .daylight, changes: [])
        case .polarNight:
            Shape(initial: .night, changes: [])
        }
    }
}

nonisolated extension SolarDay {
    /// `scenario`'s times on the day containing `date`. Built through the unchecked
    /// init, since the scenarios are fixed data that tests run through `make`.
    static func mock(_ scenario: MockScenario = .typical, for date: Date = .now, calendar: Calendar = .current) -> SolarDay {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 60 * 60)

        func at(_ time: (hour: Int, minute: Int)) -> Date {
            calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: dayStart)
                ?? dayStart.addingTimeInterval(TimeInterval(time.hour * 60 * 60 + time.minute * 60))
        }

        let shape = scenario.shape
        var phase = shape.initial
        let transitions = shape.changes.map { time, next in
            defer { phase = next }
            return PhaseTransition(date: at(time), from: phase, into: next)
        }

        return SolarDay(
            calendar: calendar,
            dayStart: dayStart,
            dayEnd: dayEnd,
            initialPhase: shape.initial,
            transitions: transitions,
            sunrise: shape.sunrise.map(at),
            sunset: shape.sunset.map(at)
        )
    }
}

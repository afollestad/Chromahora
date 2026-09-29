//
//  MockScenario.swift
//  Chromahora
//

import Foundation

/// Day shapes for previews, tests and the debug drawer, in local clock time. Apart from
/// `typical`, they copy sunrise-sunset.org's answers for 2026 at high latitudes, where
/// days skip phases or carry them past midnight. `typical` takes its night sky from
/// San Francisco on September 16, 2026.
nonisolated enum MockScenario: String, CaseIterable, Identifiable, Sendable {
    /// Every phase in the usual order, on a September day.
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
        /// The crossings out of and into astronomical night.
        var astronomicalDawn: ClockTime?
        var astronomicalDusk: ClockTime?
        let moon: MoonShape
    }

    fileprivate struct MoonShape {
        let phase: MoonPhase
        /// In percent, as the API gives it.
        let illumination: Double
        var rise: ClockTime?
        var set: ClockTime?
    }

    fileprivate var shape: Shape {
        switch self {
        case .typical:
            Shape(
                initial: .night,
                changes: [
                    ((6, 12), .blueHour), ((6, 38), .goldenHour), ((7, 42), .daylight),
                    ((18, 5), .goldenHour), ((19, 10), .blueHour), ((19, 36), .night)
                ],
                sunrise: (6, 58),
                sunset: (18, 50),
                astronomicalDawn: (5, 23),
                astronomicalDusk: (20, 44),
                moon: MoonShape(phase: .waxingCrescent, illumination: 30.73, rise: (12, 47), set: (22, 7))
            )
        case .allDayGolden:
            Shape(
                initial: .night,
                changes: [((10, 3), .blueHour), ((10, 30), .goldenHour), ((16, 21), .blueHour), ((16, 48), .night)],
                sunrise: (11, 22),
                sunset: (15, 29),
                astronomicalDawn: (7, 53),
                astronomicalDusk: (18, 57),
                moon: MoonShape(phase: .waxingGibbous, illumination: 90.25, rise: (12, 33), set: (8, 40))
            )
        case .goldenNight:
            Shape(
                initial: .goldenHour,
                changes: [((4, 49), .daylight), ((21, 51), .goldenHour)],
                sunrise: (3, 2),
                sunset: (23, 38),
                moon: MoonShape(phase: .firstQuarter, illumination: 44.82, rise: (12, 55), set: (1, 1))
            )
        case .blueHourPastMidnight:
            Shape(
                initial: .blueHour,
                changes: [
                    ((0, 10), .night), ((1, 50), .blueHour), ((2, 43), .goldenHour),
                    ((4, 54), .daylight), ((21, 6), .goldenHour), ((23, 17), .blueHour)
                ],
                sunrise: (3, 35),
                sunset: (22, 25),
                moon: MoonShape(phase: .firstQuarter, illumination: 44.39, rise: (12, 31), set: (0, 38))
            )
        case .polarTwilight:
            Shape(
                initial: .night,
                changes: [((9, 14), .blueHour), ((10, 6), .goldenHour), ((13, 7), .blueHour), ((13, 58), .night)],
                astronomicalDawn: (6, 17),
                astronomicalDusk: (16, 56),
                moon: MoonShape(phase: .new, illumination: 1.92)
            )
        case .midnightSun:
            Shape(initial: .daylight, changes: [], moon: MoonShape(phase: .firstQuarter, illumination: 44.82, rise: (12, 29), set: (1, 17)))
        case .polarNight:
            Shape(
                initial: .night,
                changes: [],
                astronomicalDawn: (7, 36),
                astronomicalDusk: (16, 14),
                moon: MoonShape(phase: .waxingGibbous, illumination: 89.96)
            )
        }
    }
}

nonisolated extension MockScenario {
    /// What the API would report for this scenario on the day starting at `dayStart`, which
    /// `SolarDay.mock` builds unchecked and a test runs through `make`.
    func readings(from dayStart: Date, calendar: Calendar) -> SolarDay.Readings {
        func at(_ time: ClockTime) -> Date {
            calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: dayStart)
                ?? dayStart.addingTimeInterval(TimeInterval(time.hour * 60 * 60 + time.minute * 60))
        }

        var phase = shape.initial
        let transitions = shape.changes.map { time, next in
            defer { phase = next }
            return PhaseTransition(date: at(time), from: phase, into: next)
        }
        let moon = shape.moon
        return SolarDay.Readings(
            transitions: transitions,
            noonAltitude: noonAltitude,
            sunrise: shape.sunrise.map(at),
            sunset: shape.sunset.map(at),
            astronomicalDawn: shape.astronomicalDawn.map(at),
            astronomicalDusk: shape.astronomicalDusk.map(at),
            moon: SolarDay.Moon(phase: moon.phase, illumination: moon.illumination / 100, rise: moon.rise.map(at), set: moon.set.map(at))
        )
    }
}

nonisolated extension SolarDay {
    /// `scenario`'s times on the day containing `date`. Built through the unchecked
    /// init, since the scenarios are fixed data that tests run through `make`.
    static func mock(_ scenario: MockScenario = .typical, for date: Date = .now, calendar: Calendar = .current) -> SolarDay {
        let dayStart = calendar.startOfDay(for: date)
        // Where the next day starts, which a day added to this one's start misses by an hour
        // where clocks spring forward at midnight, as Santiago's do, and the day starts at 1 AM.
        let dayEnd = calendar.dateInterval(of: .day, for: dayStart)?.end
            ?? dayStart.addingTimeInterval(24 * 60 * 60)
        let readings = scenario.readings(from: dayStart, calendar: calendar)

        return SolarDay(
            calendar: calendar,
            dayStart: dayStart,
            dayEnd: dayEnd,
            initialPhase: scenario.shape.initial,
            transitions: readings.transitions,
            sunrise: readings.sunrise,
            sunset: readings.sunset,
            astronomicalNight: astronomicalNight(
                dawn: readings.astronomicalDawn,
                dusk: readings.astronomicalDusk,
                noonAltitude: readings.noonAltitude,
                in: dayStart..<dayEnd
            ),
            moon: readings.moon
        )
    }
}

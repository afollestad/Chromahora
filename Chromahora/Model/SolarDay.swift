//
//  SolarDay.swift
//  Chromahora
//

import SwiftUI

/// The lighting phases a day cycles through. Nonisolated so tests and other
/// off-main code can compare phases.
nonisolated enum DayPhase {
    case night
    case blueHour
    case goldenHour
    case daylight

    var title: String {
        switch self {
        case .night: "Night"
        case .blueHour: "Blue hour"
        case .goldenHour: "Golden hour"
        case .daylight: "Daylight"
        }
    }

    var color: Color {
        switch self {
        case .night: Color(red: 0.05, green: 0.07, blue: 0.20)
        case .blueHour: Color(red: 0.18, green: 0.30, blue: 0.66)
        case .goldenHour: Color(red: 0.92, green: 0.52, blue: 0.16)
        case .daylight: Color(red: 0.99, green: 0.82, blue: 0.30)
        }
    }

    /// Long phases hold their color across their whole span. Short transitional
    /// phases peak at their midpoint and fade into their neighbors.
    var holdsColor: Bool {
        switch self {
        case .night, .daylight: true
        case .blueHour, .goldenHour: false
        }
    }
}

/// A contiguous span of the day spent in a single phase.
struct DaySegment: Identifiable {
    let id: Int
    let phase: DayPhase
    let interval: DateInterval

    var midpoint: Date {
        interval.start.addingTimeInterval(interval.duration / 2)
    }
}

/// An instant worth marking on the timeline, like sunrise or sunset.
struct SolarEvent: Identifiable {
    let title: String
    let date: Date

    var id: String { title }
}

/// A whole hour within the day, used for the timeline ruler.
struct HourMark: Identifiable {
    /// The hour on the clock, which a daylight saving change skips or repeats.
    let hour: Int
    let date: Date

    /// Identified by date, since a fall-back day shows the same clock hour twice.
    var id: Date { date }
}

/// The sun-driven schedule for a single calendar day.
///
/// Blue hour runs from the sun at -6° to -4°, golden hour from -4° to +6°, so
/// sunrise and sunset fall inside their respective golden hours.
struct SolarDay: Equatable {
    let calendar: Calendar
    let dayStart: Date
    let dayEnd: Date

    let morningBlueHourStart: Date
    let morningGoldenHourStart: Date
    let sunrise: Date
    let morningGoldenHourEnd: Date

    let eveningGoldenHourStart: Date
    let sunset: Date
    let eveningBlueHourStart: Date
    let eveningBlueHourEnd: Date

    var segments: [DaySegment] {
        let starts: [(DayPhase, Date)] = [
            (.night, dayStart),
            (.blueHour, morningBlueHourStart),
            (.goldenHour, morningGoldenHourStart),
            (.daylight, morningGoldenHourEnd),
            (.goldenHour, eveningGoldenHourStart),
            (.blueHour, eveningBlueHourStart),
            (.night, eveningBlueHourEnd)
        ]
        return starts.enumerated().map { index, entry in
            let end = index + 1 < starts.count ? starts[index + 1].1 : dayEnd
            return DaySegment(id: index, phase: entry.0, interval: DateInterval(start: entry.1, end: end))
        }
    }

    var events: [SolarEvent] {
        [
            SolarEvent(title: "Sunrise", date: sunrise),
            SolarEvent(title: "Sunset", date: sunset)
        ]
    }

    /// Every whole hour between the day's midnights. Daylight saving changes make
    /// that 22 or 24 of them, and the clock skips or repeats an hour between two.
    var hourMarks: [HourMark] {
        var marks: [HourMark] = []
        var elapsed = 1
        while let date = calendar.date(byAdding: .hour, value: elapsed, to: dayStart), date < dayEnd {
            marks.append(HourMark(hour: calendar.component(.hour, from: date), date: date))
            elapsed += 1
        }
        return marks
    }

    var duration: TimeInterval {
        dayEnd.timeIntervalSince(dayStart)
    }

    func contains(_ date: Date) -> Bool {
        dayStart <= date && date < dayEnd
    }

    /// Where `date` falls within the day, from 0 at the start to 1 at the end.
    func fraction(of date: Date) -> Double {
        let offset = date.timeIntervalSince(dayStart)
        return min(max(offset / duration, 0), 1)
    }
}

extension SolarDay {
    /// Placeholder times for a late-September day, until real solar data is wired up.
    static func mock(for date: Date = .now, calendar: Calendar = .current) -> SolarDay {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 60 * 60)

        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)
                ?? dayStart.addingTimeInterval(TimeInterval(hour * 60 * 60 + minute * 60))
        }

        return SolarDay(
            calendar: calendar,
            dayStart: dayStart,
            dayEnd: dayEnd,
            morningBlueHourStart: at(6, 12),
            morningGoldenHourStart: at(6, 38),
            sunrise: at(6, 58),
            morningGoldenHourEnd: at(7, 42),
            eveningGoldenHourStart: at(18, 5),
            sunset: at(18, 50),
            eveningBlueHourStart: at(19, 10),
            eveningBlueHourEnd: at(19, 36)
        )
    }
}

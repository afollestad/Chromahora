//
//  SolarDay.swift
//  Chromahora
//

import SwiftUI

/// The lighting phases a day cycles through. Nonisolated so tests and other
/// off-main code can compare phases.
nonisolated enum DayPhase: Sendable {
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
    /// phases peak in their middle and fade into their neighbors.
    var holdsColor: Bool {
        switch self {
        case .night, .daylight: true
        case .blueHour, .goldenHour: false
        }
    }

    /// The phase with the sun at `degrees` above the horizon. Blue hour runs from -6° to
    /// -4° and golden hour from -4° to +6°, so sunrise and sunset fall inside golden hour.
    static func band(forAltitude degrees: Double) -> DayPhase {
        if degrees > 6 {
            .daylight
        } else if degrees > -4 {
            .goldenHour
        } else if degrees > -6 {
            .blueHour
        } else {
            .night
        }
    }

    /// The phases in order of the sun's altitude. The sun crosses one boundary at a
    /// time, so a day only ever moves between neighbors in this order.
    private var altitudeRank: Int {
        switch self {
        case .night: 0
        case .blueHour: 1
        case .goldenHour: 2
        case .daylight: 3
        }
    }

    func borders(_ other: DayPhase) -> Bool {
        abs(altitudeRank - other.altitudeRank) == 1
    }
}

/// The moment the sun crosses from one phase into a neighboring one.
nonisolated struct PhaseTransition: Equatable, Sendable {
    let date: Date
    let from: DayPhase
    let into: DayPhase
}

nonisolated enum SolarDayError: Error, Equatable {
    /// The phase changes don't chain, like one that leaves blue hour while the day is
    /// in daylight, or one that skips a phase.
    case inconsistentPhases
}

/// A contiguous span of the day spent in a single phase.
nonisolated struct DaySegment: Identifiable, Sendable {
    /// How a segment sits in the day, which decides how its time range reads.
    enum Span: Equatable, Sendable {
        /// Starts and ends within the day.
        case range
        /// Began before midnight and ends within the day.
        case until
        /// Starts within the day and runs past midnight.
        case from
        /// Fills the whole day.
        case allDay
    }

    /// Normal blue and golden hours last under 90 minutes, so they keep peaking at their
    /// midpoint. Longer ones at high latitudes, like Reykjavík's six-hour golden hour in
    /// December, hold their color between blends this long at each end.
    static let colorBlend: TimeInterval = 45 * 60

    let id: Int
    let phase: DayPhase
    let interval: DateInterval
    let span: Span

    var midpoint: Date {
        interval.start.addingTimeInterval(interval.duration / 2)
    }

    /// Where the phase shows its own color at full strength: all but `colorBlend` at
    /// each end, narrowing to the midpoint when the phase is shorter than two blends.
    var heldColorRange: ClosedRange<Date> {
        let blend = min(Self.colorBlend, interval.duration / 2)
        return interval.start.addingTimeInterval(blend)...interval.end.addingTimeInterval(-blend)
    }
}

/// An instant worth marking on the timeline, like sunrise or sunset.
nonisolated struct SolarEvent: Identifiable, Sendable {
    let title: String
    let date: Date
    /// The SF Symbol the day panel lists it with.
    let symbolName: String

    var id: String { title }
}

/// A whole hour within the day, used for the timeline ruler.
nonisolated struct HourMark: Identifiable, Sendable {
    /// The hour on the clock, which a daylight saving change skips or repeats.
    let hour: Int
    let date: Date

    /// Identified by date, since a fall-back day shows the same clock hour twice.
    var id: Date { date }
}

/// The sun-driven schedule for a single calendar day: the phase at midnight, and
/// each change of phase after it.
///
/// High latitudes skip phases, like Reykjavík's December with no daylight, and carry
/// them past midnight, like St. Petersburg's June blue hour. So a day never assumes a
/// phase, a sunrise or a sunset exists. The memberwise init doesn't check its input;
/// build days from outside data through `make`, which does.
nonisolated struct SolarDay: Equatable, Sendable {
    let calendar: Calendar
    let dayStart: Date
    let dayEnd: Date

    let initialPhase: DayPhase
    /// In time order, strictly between `dayStart` and `dayEnd`.
    let transitions: [PhaseTransition]

    let sunrise: Date?
    let sunset: Date?

    var segments: [DaySegment] {
        var segments: [DaySegment] = []
        var start = dayStart
        var phase = initialPhase

        func append(until end: Date, endsDay: Bool) {
            let span: DaySegment.Span = switch (segments.isEmpty, endsDay) {
            case (true, true): .allDay
            case (true, false): .until
            case (false, true): .from
            case (false, false): .range
            }
            segments.append(DaySegment(id: segments.count, phase: phase, interval: DateInterval(start: start, end: end), span: span))
        }

        // The memberwise init takes transitions unchecked, and `DateInterval` traps on an end
        // before its start. So a change at or past midnight belongs to the next day, and one
        // at or before the current segment's start only changes the phase.
        for transition in transitions {
            guard transition.date < dayEnd else {
                break
            }
            guard transition.date > start else {
                phase = transition.into
                continue
            }
            append(until: transition.date, endsDay: false)
            start = transition.date
            phase = transition.into
        }
        append(until: dayEnd, endsDay: true)
        return segments
    }

    /// The phases the day passes through, in order. Days that share one draw alike.
    var phaseSequence: [DayPhase] {
        segments.map(\.phase)
    }

    var events: [SolarEvent] {
        [("Sunrise", "sunrise.fill", sunrise), ("Sunset", "sunset.fill", sunset)].compactMap { title, symbolName, date in
            date.map { SolarEvent(title: title, date: $0, symbolName: symbolName) }
        }
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

    /// The phase at `date`: the day's first phase before it starts, and its last after it ends.
    func phase(at date: Date) -> DayPhase {
        segments.last { $0.interval.start <= date }?.phase ?? initialPhase
    }

    /// The segment under way at `date`, or nil outside the day. At a change of phase it's the
    /// one starting, so only one segment ever holds a given instant.
    func segment(at date: Date) -> DaySegment? {
        guard contains(date) else {
            return nil
        }
        return segments.last { $0.interval.start <= date }
    }

    /// Where `date` falls within the day, from 0 at the start to 1 at the end.
    func fraction(of date: Date) -> Double {
        let offset = date.timeIntervalSince(dayStart)
        return min(max(offset / duration, 0), 1)
    }
}

nonisolated extension SolarDay {
    /// What outside data reports the sun doing around a day, before `make` checks it.
    struct Readings: Sendable {
        /// In any order, possibly doubled up or outside the day, as data windowed to a time zone arrives.
        var transitions: [PhaseTransition]
        /// The sun's altitude at solar noon, in degrees, which names the phase of a day with no changes.
        var noonAltitude: Double
        var sunrise: Date?
        var sunset: Date?
    }

    /// Builds the day from `dayStart` to `dayEnd` out of `readings`, checking that its changes chain.
    ///
    /// A change at or before `dayStart` only sets the phase the day opens in, and one at
    /// or after `dayEnd` is dropped. With no change inside the day, the sun stays in one
    /// band all day, which the noon altitude names.
    static func make(calendar: Calendar, dayStart: Date, dayEnd: Date, readings: Readings) throws -> SolarDay {
        var chain: [PhaseTransition] = []
        for transition in readings.transitions.sorted(by: { $0.date < $1.date }) {
            // The sun touching a boundary and turning back crosses it twice at one instant.
            if let last = chain.last, last.date == transition.date, last.from == transition.into, last.into == transition.from {
                chain.removeLast()
            } else {
                chain.append(transition)
            }
        }

        let before = chain.last { $0.date <= dayStart }
        let inside = chain.filter { dayStart < $0.date && $0.date < dayEnd }
        let after = chain.first { $0.date >= dayEnd }

        let initialPhase = before?.into ?? inside.first?.from ?? after?.from ?? DayPhase.band(forAltitude: readings.noonAltitude)
        var phase = initialPhase
        for transition in inside + [after].compactMap(\.self) {
            guard transition.from == phase, transition.from.borders(transition.into) else {
                throw SolarDayError.inconsistentPhases
            }
            phase = transition.into
        }

        let range = dayStart..<dayEnd
        return SolarDay(
            calendar: calendar,
            dayStart: dayStart,
            dayEnd: dayEnd,
            initialPhase: initialPhase,
            transitions: inside,
            sunrise: readings.sunrise.flatMap { range.contains($0) ? $0 : nil },
            sunset: readings.sunset.flatMap { range.contains($0) ? $0 : nil }
        )
    }
}

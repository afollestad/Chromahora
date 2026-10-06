//
//  SolarDay+Text.swift
//  Chromahora
//

import Foundation

/// How the timeline and the day panel word a day's times. Each reads in the day's own
/// time zone, so a day keeps its local clock wherever the device is.
nonisolated extension SolarDay {
    /// A time of day, as in "6:58 AM".
    func timeText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: calendar.timeZone))
    }

    /// A time of day without its half of the day, as in "6:58", for where "6:58 AM" won't fit, like
    /// the ring of a complication counting down a golden or blue hour, whose end is never far off,
    /// or a circular complication's large time, with `dayHalfText(_:)` beneath it.
    ///
    /// The short time with its AM or PM taken out, since iOS and watchOS 26 pad a 12-hour clock's
    /// hour to "06:58" when asked for an hour with `amPM: .omitted`.
    func clockText(_ date: Date) -> String {
        let text = shortTimeText(date)
        return text.runs
            .filter { $0.dateField != .amPM }
            .map { String(text[$0.range].characters) }
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

    /// The half of the day `clockText(_:)` leaves out, as in "AM", or nil where the locale's clock
    /// runs through 24 hours and has none.
    func dayHalfText(_ date: Date) -> String? {
        let text = shortTimeText(date)
        return text.runs.first { $0.dateField == .amPM }.map { String(text[$0.range].characters) }
    }

    /// `timeText(_:)` with its fields marked, for taking it apart.
    private func shortTimeText(_ date: Date) -> AttributedString {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: calendar.timeZone).attributedStyle)
    }

    /// An hour on the ruler, as in "6 AM".
    func hourText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(timeZone: calendar.timeZone).hour())
    }

    /// A date, as in "Sat, Sep 26".
    func dayText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(timeZone: calendar.timeZone).weekday(.abbreviated).month(.abbreviated).day())
    }

    /// When `interval` runs within the day. A phase or spell cut off by midnight began or ends
    /// on another day, so its text gives only the side it has on this one. It reads
    /// mid-sentence, as in "until 4:00 AM", unless `startsLine` capitalizes it.
    func rangeText(_ interval: DateInterval, span: DaySegment.Span, startsLine: Bool = false) -> String {
        let text = switch span {
        case .range:
            (interval.start..<interval.end).formatted(Date.IntervalFormatStyle(date: .omitted, time: .shortened, timeZone: calendar.timeZone))
        case .until:
            "until \(timeText(interval.end))"
        case .from:
            "from \(timeText(interval.start))"
        case .allDay:
            "all day"
        }
        return startsLine ? text.prefix(1).uppercased() + text.dropFirst() : text
    }

    func rangeText(of segment: DaySegment, startsLine: Bool = false) -> String {
        rangeText(segment.interval, span: segment.span, startsLine: startsLine)
    }

    /// How `interval`, which lies within the day, sits in it, as a phase's span does.
    func span(of interval: DateInterval) -> DaySegment.Span {
        switch (interval.start <= dayStart, interval.end >= dayEnd) {
        case (true, true): .allDay
        case (true, false): .until
        case (false, true): .from
        case (false, false): .range
        }
    }
}

nonisolated extension DaySegment {
    /// How long the phase lasts, as in "1 hr, 4 min". Nil when midnight cuts it off, since
    /// the part on this day isn't its length.
    func durationText(width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated) -> String? {
        guard span == .range else {
            return nil
        }
        return Self.durationText(interval.duration, width: width)
    }

    /// A length of time, as in "1 hr, 4 min".
    static func durationText(_ duration: TimeInterval, width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated) -> String {
        Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: width))
    }
}

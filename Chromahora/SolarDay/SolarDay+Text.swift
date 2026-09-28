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
}

nonisolated extension DaySegment {
    /// How long the phase lasts, as in "1 hr, 4 min". Nil when midnight cuts it off, since
    /// the part on this day isn't its length.
    func durationText(width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated) -> String? {
        guard span == .range else {
            return nil
        }
        return Duration.seconds(interval.duration).formatted(.units(allowed: [.hours, .minutes], width: width))
    }
}

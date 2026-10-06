//
//  DayRun.swift
//  Chromahora
//

import Foundation

/// Consecutive days in one calendar, read as one stretch of time, so a phase or a dark sky
/// that runs past midnight reads as one rather than two halves. The widgets read what's under
/// way or next from today and tomorrow, which covers whatever comes before their next reload.
nonisolated struct DayRun: Sendable {
    /// The next dark sky, or why none comes.
    enum DarkSky: Equatable, Sendable {
        /// The stretch under way, or the next one.
        case stretch(DateInterval, span: DaySegment.Span)
        /// The sky never gets fully dark in what's left of the run.
        case neverDark
        /// Tonight's astronomical night comes, but the moon is up through all of it.
        case moonUp
    }

    /// In order, each starting where the one before ends.
    let days: [SolarDay]
    /// The phases the run passes through, each merged across the midnights inside the run. A
    /// phase cut off by either end of the run keeps that side's span, as a day's does.
    let segments: [DaySegment]

    /// Keeps `later` only as far as each day starts where the one before ends, so a gap never
    /// joins two days' phases.
    init(_ first: SolarDay, then later: [SolarDay] = []) {
        var days = [first]
        for day in later {
            guard let last = days.last, day.dayStart == last.dayEnd else {
                break
            }
            days.append(day)
        }
        self.days = days
        segments = Self.merge(days.flatMap(\.segments), from: first.dayStart, to: days.last?.dayEnd ?? first.dayEnd)
    }

    var start: Date {
        days[0].dayStart
    }

    /// Whether the run reaches past its first day, as it must before a widget can say none of
    /// something is coming, since a tomorrow that failed to load leaves only today.
    var reachesTomorrow: Bool {
        days.count > 1
    }

    var end: Date {
        days[days.count - 1].dayEnd
    }

    /// The day containing `date`, or nil outside the run.
    func day(containing date: Date) -> SolarDay? {
        days.first { $0.contains(date) }
    }

    /// The phases not yet over at `date`, the one under way first.
    func segments(from date: Date) -> [DaySegment] {
        segments.filter { $0.interval.end > date }
    }

    /// The golden or blue hour under way at `date`, or the next to start. Nil when neither
    /// comes before the run ends, as through a polar night or a midnight sun.
    func magicHour(at date: Date) -> DaySegment? {
        segments.first { $0.phase.isMagicHour && $0.interval.end > date }
    }

    /// The first sunrise or sunset after `date`.
    func nextSunEvent(after date: Date) -> SolarEvent? {
        days.flatMap(\.events).filter { $0.date > date }.min { $0.date < $1.date }
    }

    /// Tonight's dark sky: the stretch under way or next within the astronomical night under way
    /// or next, since a dark sky only comes in one, or why tonight has none. A later night's
    /// stretch never stands in for it. Where a day of that night can't place its moon, a
    /// stretch running into it keeps that side's span, and none is nil, which leaves no telling.
    /// Nil past the run.
    func darkSky(at date: Date) -> DarkSky? {
        guard date < end else {
            return nil
        }
        guard let night = Self.join(days.flatMap(\.astronomicalNight)).first(where: { $0.end > date }) else {
            return .neverDark
        }
        let nightDays = days.filter { $0.dayStart < night.end && $0.dayEnd > night.start }
        let unknown = nightDays.filter { $0.darkSky == nil }
        let stretches = Self.join(nightDays.flatMap { $0.darkSky ?? [] })
        guard let stretch = stretches.first(where: { $0.end > date && $0.start < night.end }) else {
            return unknown.isEmpty ? .moonUp : nil
        }
        let knownStart = unknown.map(\.dayEnd).filter { $0 <= stretch.start }.max() ?? start
        let knownEnd = unknown.map(\.dayStart).filter { $0 >= stretch.end }.min() ?? end
        return .stretch(stretch, span: Self.span(of: stretch, from: knownStart, to: knownEnd))
    }

    /// One end of a day: the golden and blue hours that begin in it, and its sunrise or sunset.
    struct End {
        let magicHours: [DaySegment]
        let event: SolarEvent?
    }

    /// `day`'s golden and blue hours that begin on it, parted where its sun is highest: the middle
    /// of its longest daylight, or where it has none, of its longest brightest phase, since near
    /// the poles a brief dip around midnight can part daylight in two. Near the poles an end can
    /// have several golden and blue hours, or none.
    func ends(of day: SolarDay) -> (morning: End, evening: End) {
        let brightness: [DayPhase] = [.night, .blueHour, .goldenHour, .daylight]
        let brightest = day.segments.max { lhs, rhs in
            let lhsRank = brightness.firstIndex(of: lhs.phase) ?? 0
            let rhsRank = brightness.firstIndex(of: rhs.phase) ?? 0
            return lhsRank == rhsRank ? lhs.interval.duration < rhs.interval.duration : lhsRank < rhsRank
        }
        let noon = brightest?.midpoint ?? day.dayStart.addingTimeInterval(day.duration / 2)
        // Merged across midnight, so an evening blue hour that runs into tomorrow reads whole.
        // One cut off at the day's start began the evening before.
        let magicHours = segments.filter { $0.phase.isMagicHour && $0.interval.start > day.dayStart && $0.interval.start < day.dayEnd }
        return (
            End(magicHours: magicHours.filter { $0.interval.start < noon }, event: day.events.first { $0.kind == .sunrise }),
            End(magicHours: magicHours.filter { $0.interval.start >= noon }, event: day.events.first { $0.kind == .sunset })
        )
    }

    /// The day a widget showing a whole day shows at `date`:the one containing it until its
    /// last golden or blue hour is over, then the next, whose golden and blue hours come sooner.
    func featuredDay(at date: Date) -> SolarDay {
        guard let index = days.firstIndex(where: { $0.contains(date) }) else {
            return date < start ? days[0] : days[days.count - 1]
        }
        let day = days[index]
        let isOver = day.segments.last { $0.phase.isMagicHour }.map { $0.interval.end <= date } ?? false
        return isOver && index + 1 < days.count ? days[index + 1] : day
    }

    /// A time of day in the run's zone, as in "6:58 AM".
    func timeText(_ date: Date) -> String {
        days[0].timeText(date)
    }

    /// A time of day in the run's zone without its half of the day, as in "6:58".
    func clockText(_ date: Date) -> String {
        days[0].clockText(date)
    }

    /// The half of the day `clockText(_:)` leaves out, in the run's zone, as in "AM", or nil where
    /// the locale's clock runs through 24 hours.
    func dayHalfText(_ date: Date) -> String? {
        days[0].dayHalfText(date)
    }

    /// When `interval` runs, in the run's zone, as a day words its phases. One that crosses
    /// midnight gives only its times, as in "10:07 PM – 5:23 AM", since the interval style would
    /// add both dates, which a day's own ranges never need.
    func rangeText(_ interval: DateInterval, span: DaySegment.Span, startsLine: Bool = false) -> String {
        guard span == .range, !days[0].calendar.isDate(interval.start, inSameDayAs: interval.end) else {
            return days[0].rangeText(interval, span: span, startsLine: startsLine)
        }
        return timeText(interval.start) + rangeSeparator + timeText(interval.end)
    }

    /// What the interval style sets between two times in the current locale, as in thin spaces
    /// around an en dash in English, or a bare en dash in German. Taken from a range within one
    /// day, and a thin-spaced en dash where the style words times other than `timeText` does, as
    /// Japanese does.
    private var rangeSeparator: String {
        let fallback = "\u{2009}–\u{2009}"
        let day = days[0]
        // Morning to evening, so a 12-hour clock prints both halves in full.
        guard let morning = day.calendar.date(bySettingHour: 10, minute: 7, second: 0, of: day.dayStart),
              let evening = day.calendar.date(bySettingHour: 17, minute: 23, second: 0, of: day.dayStart) else {
            return fallback
        }
        let range = (morning..<evening).formatted(Date.IntervalFormatStyle(date: .omitted, time: .shortened, timeZone: day.calendar.timeZone))
        let first = timeText(morning)
        let last = timeText(evening)
        guard range.hasPrefix(first), range.hasSuffix(last), range.count > first.count + last.count else {
            return fallback
        }
        return String(range.dropFirst(first.count).dropLast(last.count))
    }

    /// How `interval` sits between `start` and `end`, as a phase's span does in a day.
    private static func span(of interval: DateInterval, from start: Date, to end: Date) -> DaySegment.Span {
        switch (interval.start <= start, interval.end >= end) {
        case (true, true): .allDay
        case (true, false): .until
        case (false, true): .from
        case (false, false): .range
        }
    }

    /// Joins each segment to the one before when midnight alone parts them, and numbers them anew.
    private static func merge(_ pieces: [DaySegment], from start: Date, to end: Date) -> [DaySegment] {
        var merged: [(phase: DayPhase, interval: DateInterval)] = []
        for piece in pieces {
            if let last = merged.last, last.phase == piece.phase, last.interval.end == piece.interval.start {
                merged[merged.count - 1].interval = DateInterval(start: last.interval.start, end: piece.interval.end)
            } else {
                merged.append((piece.phase, piece.interval))
            }
        }
        return merged.enumerated().map { index, piece in
            DaySegment(id: index, phase: piece.phase, interval: piece.interval, span: span(of: piece.interval, from: start, to: end))
        }
    }

    /// Joins intervals that meet, as a dark sky does at midnight, keeping them in order.
    private static func join(_ intervals: [DateInterval]) -> [DateInterval] {
        intervals.reduce(into: []) { joined, interval in
            if let last = joined.last, last.end == interval.start {
                joined[joined.count - 1] = DateInterval(start: last.start, end: interval.end)
            } else {
                joined.append(interval)
            }
        }
    }
}

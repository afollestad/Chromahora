//
//  SolarDayRecord.swift
//  Chromahora
//

import Foundation

/// One day as sunrise-sunset.org reports it, with `time_format=unix`. Kept in this shape in
/// the cache, and turned into a `SolarDay` only when shown.
nonisolated struct SolarDayRecord: Codable, Equatable, Sendable {
    struct Span: Codable, Equatable, Sendable {
        let begin: Date?
        let end: Date?
    }

    struct Twilight: Codable, Equatable, Sendable {
        let morning: Span
        let evening: Span
    }

    struct SolarPosition: Codable, Equatable, Sendable {
        let solarNoonAltitude: Double
    }

    /// The day in the requested time zone, as `yyyy-MM-dd`.
    let date: String
    let sunrise: Date?
    let sunset: Date?
    let goldenHour: Twilight
    let blueHour: Twilight
    let solarPosition: SolarPosition

    /// Each crossing the API reports, in its fixed direction. With `tz` windowing, evening
    /// crossings can come before morning ones, so `SolarDay.make` orders them by time.
    var readings: SolarDay.Readings {
        func change(_ date: Date?, from: DayPhase, into: DayPhase) -> PhaseTransition? {
            date.map { PhaseTransition(date: $0, from: from, into: into) }
        }
        // Blue hour's morning end and golden hour's evening end repeat the golden and blue
        // crossings listed here, so they're left out.
        let transitions = [
            change(blueHour.morning.begin, from: .night, into: .blueHour),
            change(goldenHour.morning.begin, from: .blueHour, into: .goldenHour),
            change(goldenHour.morning.end, from: .goldenHour, into: .daylight),
            change(goldenHour.evening.begin, from: .daylight, into: .goldenHour),
            change(blueHour.evening.begin, from: .goldenHour, into: .blueHour),
            change(blueHour.evening.end, from: .blueHour, into: .night)
        ].compactMap(\.self)
        return SolarDay.Readings(transitions: transitions, noonAltitude: solarPosition.solarNoonAltitude, sunrise: sunrise, sunset: sunset)
    }

    func solarDay(calendar: Calendar, dayStart: Date, dayEnd: Date) throws -> SolarDay {
        try SolarDay.make(calendar: calendar, dayStart: dayStart, dayEnd: dayEnd, readings: readings)
    }

    /// Reads and writes the API's snake-case keys and epoch seconds, for responses and the cache alike.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }
}

/// A Gregorian month in one time zone, the unit sun times are fetched and cached in.
///
/// Always Gregorian, since the API's dates are, while the device's calendar may be
/// Buddhist or Japanese.
nonisolated struct CalendarMonth: Hashable, Sendable {
    let year: Int
    let month: Int
    let timeZone: TimeZone

    init(containing date: Date, in timeZone: TimeZone) {
        let components = Self.gregorian(in: timeZone).dateComponents([.year, .month], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1, timeZone: timeZone)
    }

    init(year: Int, month: Int, timeZone: TimeZone) {
        self.year = year
        self.month = month
        self.timeZone = timeZone
    }

    var next: CalendarMonth {
        month == 12
            ? CalendarMonth(year: year + 1, month: 1, timeZone: timeZone)
            : CalendarMonth(year: year, month: month + 1, timeZone: timeZone)
    }

    /// As in `2026-09`.
    var name: String {
        String(format: "%04d-%02d", year, month)
    }

    var firstDay: String {
        "\(name)-01"
    }

    var lastDay: String {
        let calendar = Self.gregorian(in: timeZone)
        let days = calendar.date(from: DateComponents(year: year, month: month))
            .flatMap { calendar.range(of: .day, in: .month, for: $0)?.count } ?? 28
        return String(format: "%@-%02d", name, days)
    }

    /// `date`'s day as the API names it, as in `2026-09-26`.
    func dayName(of date: Date) -> String {
        let components = Self.gregorian(in: timeZone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
    }

    static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

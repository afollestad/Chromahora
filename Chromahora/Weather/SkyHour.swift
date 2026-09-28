//
//  SkyHour.swift
//  Chromahora
//

import Foundation

/// One forecast hour's light and sky readings, starting at `date`. Kept hour by hour, apart
/// from the spells that fold hours together, since the day's details read single moments.
nonisolated struct SkyHour: Codable, Equatable, Sendable {
    static let duration: TimeInterval = 60 * 60

    let date: Date
    /// On the WHO's scale, which runs from 0 at night to 11 and up.
    let uvIndex: Int
    /// The share of the sky covered by cloud below 1,800 m, from 0 to 1.
    let lowCloud: Double
    /// Between 1,800 and 6,300 m.
    let midCloud: Double
    /// Above 6,300 m.
    let highCloud: Double
    /// How far away terrain can be seen, in meters.
    let visibility: Double

    var interval: DateInterval {
        DateInterval(start: date, duration: Self.duration)
    }

    /// The WHO's exposure category, which WeatherKit's `UVIndex.ExposureCategory` also follows.
    var uvCategory: UVCategory {
        switch uvIndex {
        case ..<3: .low
        case 3..<6: .moderate
        case 6..<8: .high
        case 8..<11: .veryHigh
        default: .extreme
        }
    }

    enum UVCategory: Sendable {
        case low
        case moderate
        case high
        case veryHigh
        case extreme

        var title: String {
            switch self {
            case .low: "Low"
            case .moderate: "Moderate"
            case .high: "High"
            case .veryHigh: "Very high"
            case .extreme: "Extreme"
            }
        }
    }

    /// The hour of `hours` whose span holds `date`. WeatherKit's hours start on the hour in UTC,
    /// so in a zone offset by half an hour, a local hour's readings come from two of them.
    static func hour(containing date: Date, in hours: [SkyHour]) -> SkyHour? {
        hours.first { $0.date <= date && date < $0.interval.end }
    }

    /// The earliest of `day`'s hours with its highest UV index, or nil when the forecast
    /// doesn't reach the day or the index stays at 0, as in polar night.
    static func peakUV(on day: SolarDay, in hours: [SkyHour]) -> SkyHour? {
        let peak = hours
            .filter { $0.date < day.dayEnd && $0.interval.end > day.dayStart }
            .sorted { $0.date < $1.date }
            .max { $0.uvIndex < $1.uvIndex }
        return peak.flatMap { $0.uvIndex > 0 ? $0 : nil }
    }
}

nonisolated extension SkyHour {
    /// Every hour of the day containing `date`, shaped like `WeatherSpell.mock`'s day: clear
    /// until 4 AM, cloudy until 9, partly cloudy until 3 PM, rain until 5, then clear, with
    /// the UV index peaking at 6 at noon.
    static func mock(for date: Date = .now, calendar: Calendar = .current) -> [SkyHour] {
        let dayStart = calendar.startOfDay(for: date)
        let uvIndex = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 4, 5, 6, 6, 5, 3, 2, 1, 0, 0, 0, 0, 0, 0]
        return (0..<24).map { hour in
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart)
                ?? dayStart.addingTimeInterval(TimeInterval(hour) * duration)
            func sky(low: Double, mid: Double, high: Double, visibility: Double) -> SkyHour {
                SkyHour(date: date, uvIndex: uvIndex[hour], lowCloud: low, midCloud: mid, highCloud: high, visibility: visibility)
            }
            return switch hour {
            case ..<4: sky(low: 0.05, mid: 0.05, high: 0.1, visibility: 24_000)
            case ..<9: sky(low: 0.85, mid: 0.4, high: 0.2, visibility: 8_000)
            case ..<15: sky(low: 0.2, mid: 0.35, high: 0.2, visibility: 16_000)
            case ..<17: sky(low: 0.9, mid: 0.7, high: 0.5, visibility: 4_000)
            default: sky(low: 0.05, mid: 0.1, high: 0.2, visibility: 24_000)
            }
        }
    }
}

//
//  WeatherSpell.swift
//  Chromahora
//

import Foundation

/// What the sky does over an hour or a spell: its cloud, fog, or the precipitation likely
/// to fall. Named apart from WeatherKit's `WeatherCondition`, which it's read from.
nonisolated enum SkyCondition: String, Codable, Sendable {
    case clear
    case partlyCloudy
    case cloudy
    case fog
    case rain
    case snow
    case sleet
    case hail
    /// Precipitation that changes type within a spell, like rain turning to snow.
    case mixed

    var title: String {
        switch self {
        case .clear: "Clear"
        case .partlyCloudy: "Partly cloudy"
        case .cloudy: "Cloudy"
        case .fog: "Fog"
        case .rain: "Rain"
        case .snow: "Snow"
        case .sleet: "Sleet"
        case .hail: "Hail"
        case .mixed: "Mixed precipitation"
        }
    }

    var isPrecipitation: Bool {
        switch self {
        case .clear, .partlyCloudy, .cloudy, .fog: false
        case .rain, .snow, .sleet, .hail, .mixed: true
        }
    }

    /// Clear and partly cloudy skies show the sun by day and the moon by night.
    func symbolName(inDaylight: Bool) -> String {
        switch self {
        case .clear: inDaylight ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy: inDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy: "cloud.fill"
        case .fog: "cloud.fog.fill"
        case .rain: "cloud.rain.fill"
        case .snow: "cloud.snow.fill"
        case .sleet, .mixed: "cloud.sleet.fill"
        case .hail: "cloud.hail.fill"
        }
    }
}

/// One hour of forecast, starting at `date`.
nonisolated struct WeatherHour: Sendable {
    /// Precipitation marks an hour from 30%, where the US National Weather Service starts
    /// calling it a chance. Light rain often never reaches even odds, and below 30% a cloudy
    /// day would be dotted with slim maybes.
    static let possibleChance = 0.3
    /// Meteorologists count cloud in eighths of the sky. Up to two eighths reads as clear,
    /// and six or more as cloudy.
    static let clearCover = 0.25
    static let cloudyCover = 0.75

    let date: Date
    /// The share of the sky covered, from 0 to 1.
    let cloudCover: Double
    /// The type of precipitation forecast, if any: one of the precipitation conditions.
    let precipitation: SkyCondition?
    /// How likely that precipitation is, from 0 to 1.
    let precipitationChance: Double
    let isFoggy: Bool

    /// Possible precipitation, then fog, then the clouds.
    var condition: SkyCondition {
        if let precipitation, precipitation.isPrecipitation, precipitationChance >= Self.possibleChance {
            return precipitation
        }
        if isFoggy {
            return .fog
        }
        if cloudCover <= Self.clearCover {
            return .clear
        }
        return cloudCover >= Self.cloudyCover ? .cloudy : .partlyCloudy
    }
}

/// Consecutive hours under one condition, which the timeline marks where they start.
nonisolated struct WeatherSpell: Identifiable, Equatable, Codable, Sendable {
    /// Cloud cover near a threshold can cross it for an hour and back. A sky stretch shorter
    /// than this folds into a neighbor, so the ruler isn't dotted with an icon every hour.
    static let minimumSkySpan: TimeInterval = 2 * 60 * 60
    /// Precipitation that never gets more likely than not reads as a chance of it.
    static let likelyChance = 0.5

    let condition: SkyCondition
    let interval: DateInterval
    /// The highest hourly chance of precipitation. The chance of any across the spell is at least this.
    let precipitationChance: Double
    /// The mean share of the sky covered, from 0 to 1.
    let cloudCover: Double

    var id: Date { interval.start }

    /// The condition's name, or for precipitation that never reaches `likelyChance`, a
    /// chance of it, as in "Chance of rain".
    var title: String {
        guard condition.isPrecipitation, precipitationChance < Self.likelyChance else {
            return condition.title
        }
        return "Chance of \(condition.title.lowercased())"
    }

    /// The detail worth reading beside the condition: how likely precipitation is, or how
    /// much of the sky is covered. Fog has neither.
    var summary: String? {
        let percent = FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0))
        if condition.isPrecipitation {
            return "\(precipitationChance.formatted(percent)) chance"
        }
        return condition == .fog ? nil : "\(cloudCover.formatted(percent)) cloud cover"
    }

    /// How the spell sits in `day`, or nil when it only touches the day at midnight or misses it.
    func span(within day: SolarDay) -> DaySegment.Span? {
        guard interval.start < day.dayEnd, interval.end > day.dayStart else {
            return nil
        }
        return switch (interval.start <= day.dayStart, interval.end >= day.dayEnd) {
        case (true, true): .allDay
        case (true, false): .until
        case (false, true): .from
        case (false, false): .range
        }
    }
}

nonisolated extension WeatherSpell {
    private static let hour: TimeInterval = 60 * 60

    /// Consecutive hours under one condition, before short sky runs fold into their neighbors.
    private struct Run {
        var condition: SkyCondition
        var start: Date
        var end: Date
        var hours: [WeatherHour]

        init(_ hour: WeatherHour) {
            condition = hour.condition
            start = hour.date
            end = hour.date.addingTimeInterval(WeatherSpell.hour)
            hours = [hour]
        }

        var isShortSky: Bool {
            !condition.isPrecipitation && end.timeIntervalSince(start) < WeatherSpell.minimumSkySpan
        }

        /// Whether an hour of `condition` continues this run: any precipitation continues
        /// precipitation, and sky conditions only continue themselves.
        func joins(_ condition: SkyCondition) -> Bool {
            self.condition == condition || (self.condition.isPrecipitation && condition.isPrecipitation)
        }

        /// Whether `other` is a sky run that ends where this one starts, or starts where it ends.
        func isSkyNeighbor(of other: Run) -> Bool {
            !other.condition.isPrecipitation && (other.end == start || other.start == end)
        }

        /// Takes in `other`'s hours, keeping this run's condition.
        mutating func absorb(_ other: Run) {
            start = min(start, other.start)
            end = max(end, other.end)
            hours = (hours + other.hours).sorted { $0.date < $1.date }
        }

        var spell: WeatherSpell {
            WeatherSpell(
                condition: condition,
                interval: DateInterval(start: start, end: end),
                precipitationChance: hours.map(\.precipitationChance).max() ?? 0,
                cloudCover: hours.map(\.cloudCover).reduce(0, +) / Double(hours.count)
            )
        }
    }

    /// Groups `hours` into spells. Precipitation hours join whatever their type, becoming
    /// `.mixed` when it changes, so one wet stretch stays one spell. Sky hours join when
    /// their condition matches, and a sky run shorter than `minimumSkySpan` folds into the
    /// sky run before it, or after it when it comes first. Precipitation never folds, since
    /// even an hour of rain matters. A missing hour splits a spell.
    static func spells(from hours: [WeatherHour]) -> [WeatherSpell] {
        var runs: [Run] = []
        for hour in hours.sorted(by: { $0.date < $1.date }) {
            let condition = hour.condition
            if let last = runs.indices.last, runs[last].end == hour.date, runs[last].joins(condition) {
                if runs[last].condition != condition {
                    runs[last].condition = .mixed
                }
                runs[last].absorb(Run(hour))
            } else {
                runs.append(Run(hour))
            }
        }
        return folded(runs).map(\.spell)
    }

    /// Folds short sky runs into their sky neighbors until none can fold, rejoining runs of
    /// the same condition that a fold leaves side by side. Each fold removes a run, so it ends.
    private static func folded(_ runs: [Run]) -> [Run] {
        var runs = runs
        while let fold = nextFold(in: runs) {
            runs[fold.into].absorb(runs[fold.short])
            runs.remove(at: fold.short)
            runs = joined(runs)
        }
        return runs
    }

    /// The first short sky run with a sky neighbor, and that neighbor: the one before it when there is one.
    private static func nextFold(in runs: [Run]) -> (short: Int, into: Int)? {
        for index in runs.indices where runs[index].isShortSky {
            if index > 0, runs[index].isSkyNeighbor(of: runs[index - 1]) {
                return (index, index - 1)
            }
            if index + 1 < runs.count, runs[index].isSkyNeighbor(of: runs[index + 1]) {
                return (index, index + 1)
            }
        }
        return nil
    }

    /// Joins touching sky runs of the same condition.
    private static func joined(_ runs: [Run]) -> [Run] {
        var result: [Run] = []
        for run in runs {
            if let last = result.indices.last, !run.condition.isPrecipitation,
               result[last].condition == run.condition, result[last].end == run.start {
                result[last].absorb(run)
            } else {
                result.append(run)
            }
        }
        return result
    }
}

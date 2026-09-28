//
//  SolarDay+Moon.swift
//  Chromahora
//

import Foundation

/// The moon's phase, as sunrise-sunset.org names it.
nonisolated enum MoonPhase: String, CaseIterable, Sendable {
    case new = "New Moon"
    case waxingCrescent = "Waxing Crescent"
    case firstQuarter = "First Quarter"
    case waxingGibbous = "Waxing Gibbous"
    case full = "Full Moon"
    case waningGibbous = "Waning Gibbous"
    case lastQuarter = "Last Quarter"
    case waningCrescent = "Waning Crescent"

    /// In sentence case, like the day's phases.
    var title: String {
        switch self {
        case .new: "New moon"
        case .waxingCrescent: "Waxing crescent"
        case .firstQuarter: "First quarter"
        case .waxingGibbous: "Waxing gibbous"
        case .full: "Full moon"
        case .waningGibbous: "Waning gibbous"
        case .lastQuarter: "Last quarter"
        case .waningCrescent: "Waning crescent"
        }
    }

    var symbolName: String {
        switch self {
        case .new: "moonphase.new.moon"
        case .waxingCrescent: "moonphase.waxing.crescent"
        case .firstQuarter: "moonphase.first.quarter"
        case .waxingGibbous: "moonphase.waxing.gibbous"
        case .full: "moonphase.full.moon"
        case .waningGibbous: "moonphase.waning.gibbous"
        case .lastQuarter: "moonphase.last.quarter"
        case .waningCrescent: "moonphase.waning.crescent"
        }
    }
}

nonisolated extension SolarDay {
    /// The moon over the day. Each part is optional, since the moon skips a rise or a set
    /// about once a month, and near the poles can do neither for days.
    struct Moon: Equatable, Sendable {
        /// Nil for a phase the app doesn't know, which hides it rather than the day.
        var phase: MoonPhase?
        /// The share of the disk lit, from 0 to 1.
        var illumination: Double?
        var rise: Date?
        var set: Date?
    }

    /// When the moon is above the horizon, in time order. Nil when the day has neither a
    /// moonrise nor a moonset, which leaves no way to tell whether it's up.
    var moonUp: [DateInterval]? {
        guard let moon, moon.rise != nil || moon.set != nil else {
            return nil
        }
        let crossings = [(moon.rise, true), (moon.set, false)].compactMap { date, rises in
            date.map { Crossing(date: $0, enters: rises) }
        }
        return Self.spans(of: crossings, in: dayStart..<dayEnd, otherwise: false)
    }

    /// Astronomical night with the moon down: the darkest sky the day has, in time order. None
    /// when the day never gets that dark, wherever the moon is, and nil when there is night but
    /// no telling where the moon is.
    var darkSky: [DateInterval]? {
        if astronomicalNight.isEmpty {
            return []
        }
        guard let moonUp else {
            return nil
        }
        return astronomicalNight.flatMap { night in
            moonUp.reduce([night]) { pieces, moonlit in
                pieces.flatMap { piece in
                    guard moonlit.start < piece.end, moonlit.end > piece.start else {
                        return [piece]
                    }
                    return [
                        piece.start < moonlit.start ? DateInterval(start: piece.start, end: moonlit.start) : nil,
                        moonlit.end < piece.end ? DateInterval(start: moonlit.end, end: piece.end) : nil
                    ].compactMap(\.self)
                }
            }
        }
    }
}

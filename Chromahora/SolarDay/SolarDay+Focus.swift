//
//  SolarDay+Focus.swift
//  Chromahora
//

import Foundation

nonisolated extension SolarDay {
    /// The time a view of the day centers on: `now` when it falls on this day, otherwise the
    /// middle of the brightest phase the day reaches, since a high-latitude winter day may have
    /// no daylight.
    func focusDate(now: Date) -> Date {
        if contains(now) {
            return now
        }
        for phase in [DayPhase.daylight, .goldenHour, .blueHour] {
            if let segment = segments.first(where: { $0.phase == phase }) {
                return segment.midpoint
            }
        }
        return dayStart.addingTimeInterval(duration / 2)
    }
}

//
//  CloudProfile.swift
//  Chromahora
//

import Foundation

/// The forecast's cloud cover down a day, as runs of points `CloudBand` draws through: each
/// hour's cover at its midpoint, held flat to the ends of its run. A missing hour ends a run,
/// so the band leaves a gap rather than guess across it.
nonisolated struct CloudProfile: Equatable, Sendable {
    struct Point: Equatable, Sendable {
        /// Where down the day, from 0 at its start to 1 at its end.
        let fraction: Double
        /// The share of the sky covered, from 0 to 1.
        let cover: Double
    }

    let runs: [[Point]]

    /// The hours of `hours`, in time order, that reach `day`. One that crosses midnight, as in a
    /// zone half an hour off UTC, is cut there.
    init(day: SolarDay, hours: [SkyHour]) {
        var runs: [[SkyHour]] = []
        for hour in hours where hour.falls(on: day) {
            if let last = runs.last?.last, last.interval.end == hour.date {
                runs[runs.count - 1].append(hour)
            } else {
                runs.append([hour])
            }
        }
        self.runs = runs.map { run in
            func point(at date: Date, _ hour: SkyHour) -> Point {
                Point(fraction: day.fraction(of: date), cover: min(max(hour.cloudCover, 0), 1))
            }
            let middles = run.map { point(at: $0.date.addingTimeInterval(SkyHour.duration / 2), $0) }
            guard let first = run.first, let last = run.last else {
                return middles
            }
            return [point(at: first.date, first)] + middles + [point(at: last.interval.end, last)]
        }
    }
}

//
//  CloudProfile.swift
//  Chromahora
//

import Foundation

/// The forecast's cloud cover down a day and on past its ends, as runs of points `CloudBand`
/// draws through: each hour's cover at its midpoint, held flat to the ends of its run. A missing
/// hour ends a run, so the band leaves a gap rather than guess across it.
nonisolated struct CloudProfile: Equatable, Sendable {
    struct Point: Equatable, Sendable {
        /// Where down the day, from 0 at its start to 1 at its end, and past either end beyond it.
        let fraction: Double
        /// The share of the sky covered, from 0 to 1.
        let cover: Double
    }

    /// How far past each end of the day the profile runs. A day, farther than any screen shows
    /// past one even pulled through the rubber band: a 13-inch iPad's 1,376 pt height spans under
    /// 20 hours at the timeline's 72 pt an hour.
    static let reach: TimeInterval = 24 * 60 * 60

    let runs: [[Point]]

    /// The hours of `hours`, in time order, that reach within `reach` of `day`, so the band
    /// carries on across midnight into the days either side. Where the forecast stops at or past
    /// one of the day's ends, its last hour's cover holds out to `reach`, as the sky holds its
    /// end colors, so the band never stops at the day's edge.
    init(day: SolarDay, hours: [SkyHour]) {
        let start = day.dayStart.addingTimeInterval(-Self.reach)
        let end = day.dayEnd.addingTimeInterval(Self.reach)
        var runs: [[SkyHour]] = []
        for hour in hours where hour.date < end && hour.interval.end > start {
            if let last = runs.last?.last, last.interval.end == hour.date {
                runs[runs.count - 1].append(hour)
            } else {
                runs.append([hour])
            }
        }
        func point(at date: Date, _ hour: SkyHour) -> Point {
            Point(fraction: day.fraction(of: date, clamped: false), cover: min(max(hour.cloudCover, 0), 1))
        }
        var points = runs.map { run in
            let middles = run.map { point(at: $0.date.addingTimeInterval(SkyHour.duration / 2), $0) }
            guard let first = run.first, let last = run.last else {
                return middles
            }
            return [point(at: first.date, first)] + middles + [point(at: last.interval.end, last)]
        }
        if let first = runs.first?.first, first.date <= day.dayStart, first.date > start {
            points[0].insert(point(at: start, first), at: 0)
        }
        if let last = runs.last?.last, last.interval.end >= day.dayEnd, last.interval.end < end {
            points[points.count - 1].append(point(at: end, last))
        }
        self.runs = points
    }
}

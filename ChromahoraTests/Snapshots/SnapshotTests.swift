//
//  SnapshotTests.swift
//  ChromahoraTests
//

import Foundation
import SwiftUI
import Testing
@testable import Chromahora

/// Full-screen snapshots, grouped into `+Topic` files by screen. Serialized, since each
/// snapshot puts its own window over the whole screen.
@MainActor
@Suite(.serialized)
struct SnapshotTests {
    /// A time in 2026, on September 16 unless given another day. Callers pick days
    /// with no daylight saving change in any time zone, like June 21 and December 21.
    /// Built from local components, so the mock day's times and the labels formatted
    /// from them read the same wherever the tests run.
    func time(month: Int = 9, day: Int = 16, _ hour: Int, _ minute: Int = 0) throws -> Date {
        let components = DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
        return try #require(Calendar.current.date(from: components))
    }

    /// The timeline for September 16 at `now`, which may fall on another day. `ContentView`
    /// can't stand in, since its `TimelineView` reads the real clock.
    func timeline(now: Date) throws -> some View {
        timeline(of: SolarDay.mock(for: try time(12)), now: now)
    }

    /// The timeline for `scenario` on the day containing `now`.
    func timeline(_ scenario: MockScenario, now: Date) -> some View {
        timeline(of: SolarDay.mock(scenario, for: now), now: now)
    }

    private func timeline(of day: SolarDay, now: Date) -> some View {
        NavigationStack {
            DayTimeline(day: day, now: now, selectedDate: .constant(day.dayStart))
        }
    }
}

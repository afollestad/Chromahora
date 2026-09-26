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
    /// A time on September 16, 2026, which has no daylight saving change in any time
    /// zone. Built from local components, so the mock day's times and the labels
    /// formatted from them read the same wherever the tests run.
    func time(day: Int = 16, _ hour: Int, _ minute: Int = 0) throws -> Date {
        let components = DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute)
        return try #require(Calendar.current.date(from: components))
    }

    /// The timeline for September 16 at `now`. `ContentView` can't stand in, since its
    /// `TimelineView` reads the real clock.
    func timeline(now: Date) throws -> some View {
        let day = SolarDay.mock(for: try time(12))
        return NavigationStack {
            DayTimeline(day: day, now: now, selectedDate: .constant(day.dayStart))
        }
    }
}

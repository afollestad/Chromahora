//
//  WideSnapshotTests.swift
//  ChromahoraTests
//

import Foundation
import SwiftUI
import Testing
@testable import Chromahora

/// Full-screen snapshots on the iPad mini, where the day panel floats beside the timeline,
/// grouped into `+Topic` files by screen like `SnapshotTests`.
///
/// Every test falls in June 2026. The panel's calendar marks the real today, so a baseline
/// must never show the month it runs in, and `time` fixes the year, so no later month stays safe.
@MainActor
@Suite(.serialized)
struct WideSnapshotTests: ScreenSnapshotting {
    /// A time on June 21, 2026, or another day that June.
    func june(day: Int = 21, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try time(month: 6, day: day, hour, minute)
    }

    /// The timeline for June 21 at `now`, which may fall on another day, marked with
    /// `weather`, at a place found by location.
    func timeline(now: Date, weather: [WeatherSpell] = []) throws -> some View {
        timeline(of: SolarDay.mock(for: try june(12)), now: now, weather: weather, place: MockPlaceProvider.sanFrancisco)
    }
}

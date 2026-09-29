//
//  SnapshotTests+Widgets.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
import WidgetKit
@testable import Chromahora

/// Widgets as the iPhone 18 Pro's Home Screen shows them, one family to a snapshot. Only
/// WidgetKit draws a widget's container, so each draws its own sky, margins and corners here.
extension SnapshotTests {
    private enum WidgetSize {
        case small
        case medium

        /// Measured from a simulator screenshot of the iPhone 18 Pro's Home Screen, since Apple
        /// publishes sizes only for other screens.
        var points: CGSize {
            switch self {
            case .small: CGSize(width: 164, height: 164)
            case .medium: CGSize(width: 348, height: 164)
            }
        }
    }

    /// WidgetKit's default content margins on the iPhone.
    private static let widgetMargin: CGFloat = 16
    /// Measured with the sizes.
    private static let widgetCornerRadius: CGFloat = 23

    // MARK: Moments

    @Test func smallWidgetsThisAfternoon() async throws {
        try await assertScreenSnapshot(of: widgets(.small, at: time(16, 30)))
    }

    @Test func mediumWidgetsThisAfternoon() async throws {
        try await assertScreenSnapshot(of: widgets(.medium, at: time(16, 30)))
    }

    /// Golden hour is under way, so the widgets say until when, on its orange sky.
    @Test func smallWidgetsDuringGoldenHour() async throws {
        try await assertScreenSnapshot(of: widgets(.small, at: time(18, 30)))
    }

    @Test func mediumWidgetsDuringGoldenHour() async throws {
        try await assertScreenSnapshot(of: widgets(.medium, at: time(18, 30)))
    }

    /// The day's golden and blue hours are over, so the next are tomorrow's, under the
    /// clouds its morning brings, and the whole-day widgets show tomorrow.
    @Test func smallWidgetsAfterDark() async throws {
        try await assertScreenSnapshot(of: widgets(.small, at: time(22)))
    }

    @Test func mediumWidgetsAfterDark() async throws {
        try await assertScreenSnapshot(of: widgets(.medium, at: time(22)))
    }

    /// Night holds through both days, with no golden or blue hour, no sunrise or sunset, and a
    /// moon that can't be placed, so no dark sky.
    @Test func smallWidgetsInPolarNight() async throws {
        try await assertScreenSnapshot(of: widgets(.small, at: time(month: 12, day: 21, 12), scenario: .polarNight))
    }

    @Test func mediumWidgetsInPolarNight() async throws {
        try await assertScreenSnapshot(of: widgets(.medium, at: time(month: 12, day: 21, 12), scenario: .polarNight))
    }

    /// St. Petersburg's evening blue hour runs past midnight and reads whole across it, the
    /// sky never gets fully dark, and the time zone's city stands in for the device's place.
    @Test func smallWidgetsPastMidnight() async throws {
        let now = try time(month: 6, day: 21, 23, 30)
        await assertScreenSnapshot(of: widgets(.small, at: now, scenario: .blueHourPastMidnight, place: approximatePlace))
    }

    @Test func mediumWidgetsPastMidnight() async throws {
        let now = try time(month: 6, day: 21, 23, 30)
        await assertScreenSnapshot(of: widgets(.medium, at: now, scenario: .blueHourPastMidnight, place: approximatePlace))
    }

    @Test func smallWidgetsAtLargestTextSize() async throws {
        try await assertScreenSnapshot(of: widgets(.small, at: time(16, 30)).environment(\.dynamicTypeSize, .accessibility5))
    }

    @Test func mediumWidgetsAtLargestTextSize() async throws {
        try await assertScreenSnapshot(of: widgets(.medium, at: time(16, 30)).environment(\.dynamicTypeSize, .accessibility5))
    }

    /// A tinted or clear Home Screen takes the sky away and draws the text in one color, so the
    /// strip's sky turns to an opacity ramp and the text keeps the system's scheme.
    @Test func smallWidgetsAccented() async throws {
        try await assertScreenSnapshot(of: widgets(.small, at: time(16, 30), accented: true))
    }

    @Test func mediumWidgetsAccented() async throws {
        try await assertScreenSnapshot(of: widgets(.medium, at: time(16, 30), accented: true))
    }

    /// Every widget shows the same note until its sun times load.
    @Test func widgetsUnavailable() async throws {
        let entry = SkyEntry(date: try time(16, 30), state: .unavailable)
        await assertScreenSnapshot(of: backdrop {
            card(.small, entry: entry) { NextMagicHourView(entry: entry) }
            card(.medium, entry: entry) { DayStripView(entry: entry) }
        })
    }

    // MARK: Building

    /// Los Angeles, standing in for a device that hasn't been placed.
    private var approximatePlace: Place {
        Place(latitude: 34.1, longitude: -118.2, source: .timeZone("America/Los_Angeles"))
    }

    /// `place`'s `scenario` day containing `now` and the next, with `WeatherSpell.mock`'s sky over
    /// both, as `SkyLoader` would load them. San Francisco is the device's, with its town named.
    private func content(_ scenario: MockScenario, at now: Date, place: Place) -> SkyContent {
        let today = SolarDay.mock(scenario, for: now)
        let tomorrow = SolarDay.mock(scenario, for: today.dayEnd)
        return SkyContent(
            place: place,
            deviceName: place == MockPlaceProvider.sanFrancisco ? "San Francisco" : nil,
            run: DayRun(today, then: [tomorrow]),
            spells: WeatherSpell.mock(for: today.dayStart) + WeatherSpell.mock(for: tomorrow.dayStart)
        )
    }

    /// `size`'s three widgets at `now`.
    private func widgets(
        _ size: WidgetSize,
        at now: Date,
        scenario: MockScenario = .typical,
        place: Place = MockPlaceProvider.sanFrancisco,
        accented: Bool = false
    ) -> some View {
        let entry = SkyEntry(date: now, state: .loaded(content(scenario, at: now, place: place)))
        return backdrop {
            switch size {
            case .small:
                card(.small, entry: entry, accented: accented) { NextMagicHourView(entry: entry) }
                card(.small, entry: entry, accented: accented) { SunTimesView(entry: entry) }
                card(.small, entry: entry, accented: accented) { MoonView(entry: entry) }
            case .medium:
                card(.medium, entry: entry, accented: accented) { DayStripView(entry: entry) }
                card(.medium, entry: entry, accented: accented) { MorningEveningView(entry: entry) }
                card(.medium, entry: entry, accented: accented) { NextPhasesView(entry: entry) }
            }
        }
    }

    /// Stacks widgets on a plain wallpaper, with countdowns read from each entry's moment
    /// rather than the real clock.
    private func backdrop(@ViewBuilder _ widgets: () -> some View) -> some View {
        VStack(spacing: 24) {
            widgets()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.2))
        .environment(\.ticksCountdowns, false)
    }

    /// One widget at `size`. `accented` stands in for a tinted Home Screen's glass:
    /// a gray plate with the system's dark scheme, since the widget's sky is gone.
    private func card(
        _ size: WidgetSize,
        entry: SkyEntry,
        accented: Bool = false,
        @ViewBuilder _ widget: () -> some View
    ) -> some View {
        widget()
            .skyWidgetBackground(for: entry)
            .padding(Self.widgetMargin)
            .frame(width: size.points.width, height: size.points.height)
            .background {
                if accented {
                    Color(white: 0.35)
                } else {
                    SkyBackground(entry: entry)
                }
            }
            .clipShape(.rect(cornerRadius: Self.widgetCornerRadius, style: .continuous))
            .environment(\.widgetRenderingMode, accented ? .accented : .fullColor)
            .environment(\.colorScheme, accented ? .dark : .light)
    }
}

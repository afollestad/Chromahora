//
//  SnapshotTests+Complications.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
import WidgetKit
@testable import Chromahora

/// The watch's complications, every layout of one at a moment, on a watch face's black. Only
/// WidgetKit draws a complication's label along the bezel, so the corner shows its time alone,
/// and the inline one lies flat, in the phone's larger text, which can cut short a line the
/// watch's bezel holds.
extension SnapshotTests {
    /// Each layout's slot on the 46 mm watch, measured in the simulator's face editor: Modular's
    /// circular and middle slots, and Utility's corner and bottom ones. The inline one, which
    /// Utility curves along the bottom, is its slot's width at a line's height.
    private static func complicationSize(_ layout: PhaseComplicationView.Layout) -> CGSize {
        switch layout {
        case .circular: CGSize(width: 53.5, height: 53.5)
        case .corner: CGSize(width: 85, height: 76)
        case .inline: CGSize(width: 187, height: 24)
        case .rectangular: CGSize(width: 176.5, height: 75.5)
        }
    }

    // MARK: Moments

    /// The evening's golden hour is next, a countdown away.
    @Test func complicationsThisAfternoon() async throws {
        try await assertScreenSnapshot(of: complications(at: time(16, 30)))
    }

    /// Golden hour is under way, so they say until when, and the ring counts it down.
    @Test func complicationsDuringGoldenHour() async throws {
        try await assertScreenSnapshot(of: complications(at: time(18, 30)))
    }

    /// The day's golden and blue hours are over, so the next is tomorrow morning's blue hour.
    @Test func complicationsAfterDark() async throws {
        try await assertScreenSnapshot(of: complications(at: time(22)))
    }

    /// Night holds through both days, so they name it, and say no golden or blue hour comes.
    @Test func complicationsInPolarNight() async throws {
        try await assertScreenSnapshot(of: complications(at: time(month: 12, day: 21, 12), scenario: .polarNight))
    }

    @Test func complicationsAtLargestTextSize() async throws {
        try await assertScreenSnapshot(of: complications(at: time(16, 30)).environment(\.dynamicTypeSize, .accessibility5))
    }

    /// A tinted face draws a complication in one color, so the phase is named as well as dotted.
    @Test func complicationsAccented() async throws {
        try await assertScreenSnapshot(of: complications(at: time(16, 30)).environment(\.widgetRenderingMode, .accented))
    }

    /// Each layout says, in as much room as it has, that sun times haven't loaded.
    @Test func complicationsUnavailable() async throws {
        try await assertScreenSnapshot(of: complications(SkyEntry(date: time(16, 30), state: .unavailable)))
    }

    // MARK: Building

    /// Every layout for `scenario`'s day containing `now` and the next, as `SkyLoader` loads them.
    private func complications(at now: Date, scenario: MockScenario = .typical) -> some View {
        complications(SkyEntry(date: now, state: .loaded(content(scenario, at: now))))
    }

    /// Every layout of `entry`, each in its slot, with countdowns read from the entry's moment
    /// rather than the real clock.
    private func complications(_ entry: SkyEntry) -> some View {
        VStack(spacing: 24) {
            ForEach(PhaseComplicationView.Layout.allCases, id: \.self) { layout in
                let size = Self.complicationSize(layout)
                PhaseComplicationView(entry: entry, layout: layout)
                    .frame(width: size.width, height: size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .environment(\.colorScheme, .dark)
        .environment(\.ticksCountdowns, false)
    }
}

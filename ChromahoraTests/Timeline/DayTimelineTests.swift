//
//  DayTimelineTests.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
@testable import Chromahora

/// `DayTimeline` is a main-actor view.
@MainActor
struct DayTimelineTests {
    @Test func barTurnsDarkOverNightAndBlueHourAndLightOverGoldenHourAndDaylight() {
        for wasDark in [true, false] {
            #expect(DayTimeline.prefersDarkBar(over: DayPhase.night.color, wasDark: wasDark))
            #expect(DayTimeline.prefersDarkBar(over: DayPhase.blueHour.color, wasDark: wasDark))
            #expect(!DayTimeline.prefersDarkBar(over: DayPhase.goldenHour.color, wasDark: wasDark))
            #expect(!DayTimeline.prefersDarkBar(over: DayPhase.daylight.color, wasDark: wasDark))
        }
    }

    @Test func barKeepsItsSchemeNearTheCrossover() throws {
        // Finds a sky color between the dusk bridge and golden hour whose luminance is inside the band.
        let crossover = try #require(stride(from: 0.0, through: 1, by: 0.01).lazy.map {
            Color(red: 0.55, green: 0.33, blue: 0.48).mix(with: DayPhase.goldenHour.color, by: $0, in: .perceptual)
        }.first { abs(DayTimeline.luminance(of: $0) - 0.18) < 0.005 })

        #expect(DayTimeline.prefersDarkBar(over: crossover, wasDark: true))
        #expect(!DayTimeline.prefersDarkBar(over: crossover, wasDark: false))
    }

    @Test func labelsTurnDarkOverNightBlueHourAndDuskAndLightOverGoldenHourAndDaylight() {
        #expect(DayTimeline.labelScheme(over: DayPhase.night.color) == .dark)
        #expect(DayTimeline.labelScheme(over: DayPhase.blueHour.color) == .dark)
        #expect(DayTimeline.labelScheme(over: SkyGradient.duskBridge) == .dark)
        #expect(DayTimeline.labelScheme(over: DayPhase.goldenHour.color) == .light)
        #expect(DayTimeline.labelScheme(over: DayPhase.daylight.color) == .light)
    }
}

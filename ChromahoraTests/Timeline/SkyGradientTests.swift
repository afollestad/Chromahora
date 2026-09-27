//
//  SkyGradientTests.swift
//  ChromahoraTests
//

import Foundation
import SwiftUI
import Testing
@testable import Chromahora

/// `SkyGradient` is a main-actor view.
@MainActor
struct SkyGradientTests {
    private let day = SolarDay.mock(
        for: Date(timeIntervalSince1970: 1_790_000_000),
        calendar: Calendar(identifier: .gregorian)
    )

    @Test func heldPhasesKeepTheirColor() {
        expect(SkyGradient.color(at: 0, in: day), matches: DayPhase.night.color)
        expect(SkyGradient.color(at: 1, in: day), matches: DayPhase.night.color)

        let noon = day.fraction(of: day.dayStart.addingTimeInterval(day.duration / 2))
        expect(SkyGradient.color(at: noon, in: day), matches: DayPhase.daylight.color)
    }

    /// The title's tint observes this color on every frame of a scroll, and only redraws when it changes.
    @Test func heldPhasesReturnEqualColorsAcrossTheirSpan() {
        let morning = day.fraction(of: day.morningGoldenHourEnd.addingTimeInterval(60 * 60))
        let afternoon = day.fraction(of: day.eveningGoldenHourStart.addingTimeInterval(-60 * 60))
        #expect(SkyGradient.color(at: morning, in: day) == SkyGradient.color(at: afternoon, in: day))
    }

    @Test func blueAndGoldenHoursMeetAtTheDuskBridge() {
        let boundary = day.fraction(of: day.morningGoldenHourStart)
        expect(SkyGradient.color(at: boundary, in: day), matches: Color(red: 0.55, green: 0.33, blue: 0.48))
    }

    @Test func blendsBetweenStopsInPerceptualSpace() throws {
        let blueHour = try #require(day.segments.first { $0.phase == .blueHour })
        let blueHourPeak = day.fraction(of: blueHour.midpoint)
        let boundary = day.fraction(of: day.morningGoldenHourStart)
        let duskBridge = Color(red: 0.55, green: 0.33, blue: 0.48)

        expect(
            SkyGradient.color(at: (blueHourPeak + boundary) / 2, in: day),
            matches: DayPhase.blueHour.color.mix(with: duskBridge, by: 0.5, in: .perceptual)
        )
    }

    private func expect(_ color: Color, matches expected: Color, sourceLocation: SourceLocation = #_sourceLocation) {
        let actual = color.resolve(in: EnvironmentValues())
        let expected = expected.resolve(in: EnvironmentValues())
        #expect(abs(actual.red - expected.red) < 0.01, sourceLocation: sourceLocation)
        #expect(abs(actual.green - expected.green) < 0.01, sourceLocation: sourceLocation)
        #expect(abs(actual.blue - expected.blue) < 0.01, sourceLocation: sourceLocation)
    }
}

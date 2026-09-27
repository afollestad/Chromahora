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
    @Test func heldPhasesReturnEqualColorsAcrossTheirSpan() throws {
        let daylight = try #require(day.segments.first { $0.phase == .daylight })
        let morning = day.fraction(of: daylight.interval.start.addingTimeInterval(60 * 60))
        let afternoon = day.fraction(of: daylight.interval.end.addingTimeInterval(-60 * 60))
        #expect(SkyGradient.color(at: morning, in: day) == SkyGradient.color(at: afternoon, in: day))
    }

    @Test func blueAndGoldenHoursMeetAtTheDuskBridge() throws {
        let boundary = day.fraction(of: try #require(day.segments.first { $0.phase == .goldenHour }).interval.start)
        expect(SkyGradient.color(at: boundary, in: day), matches: Color(red: 0.55, green: 0.33, blue: 0.48))
    }

    @Test func blendsBetweenStopsInPerceptualSpace() throws {
        let blueHour = try #require(day.segments.first { $0.phase == .blueHour })
        let blueHourPeak = day.fraction(of: blueHour.midpoint)
        let boundary = day.fraction(of: blueHour.interval.end)
        let duskBridge = Color(red: 0.55, green: 0.33, blue: 0.48)

        expect(
            SkyGradient.color(at: (blueHourPeak + boundary) / 2, in: day),
            matches: DayPhase.blueHour.color.mix(with: duskBridge, by: 0.5, in: .perceptual)
        )
    }

    /// Reykjavík's six-hour December golden hour stays golden, rather than peaking only at its midpoint.
    @Test func aLongGoldenHourHoldsItsColor() throws {
        let day = SolarDay.mock(.allDayGolden, for: Date(timeIntervalSince1970: 1_790_000_000), calendar: Calendar(identifier: .gregorian))
        let goldenHour = try #require(day.segments.first { $0.phase == .goldenHour })

        expect(SkyGradient.color(at: day.fraction(of: goldenHour.midpoint), in: day), matches: DayPhase.goldenHour.color)
        let blendEnd = goldenHour.interval.start.addingTimeInterval(DaySegment.colorBlend)
        expect(SkyGradient.color(at: day.fraction(of: blendEnd), in: day), matches: DayPhase.goldenHour.color)
    }

    /// St. Petersburg's June blue hour runs past midnight, so the day opens in it.
    @Test func aBlueHourCutOffByMidnightReachesTheEdge() {
        let day = SolarDay.mock(.blueHourPastMidnight, for: Date(timeIntervalSince1970: 1_790_000_000), calendar: Calendar(identifier: .gregorian))

        expect(SkyGradient.color(at: 0, in: day), matches: DayPhase.blueHour.color)
        expect(SkyGradient.color(at: 1, in: day), matches: DayPhase.blueHour.color)
    }

    /// The glide between days animates stop locations, which needs matching counts.
    @Test func stopCountDependsOnlyOnThePhaseSequence() {
        func typicalDay(goldenMinutes: Double) -> SolarDay {
            func hours(_ hours: Double) -> Date {
                day.dayStart.addingTimeInterval(hours * 60 * 60)
            }
            return SolarDay(
                calendar: day.calendar,
                dayStart: day.dayStart,
                dayEnd: day.dayEnd,
                initialPhase: .night,
                transitions: [
                    PhaseTransition(date: hours(6), from: .night, into: .blueHour),
                    PhaseTransition(date: hours(6.5), from: .blueHour, into: .goldenHour),
                    PhaseTransition(date: hours(6.5 + goldenMinutes / 60), from: .goldenHour, into: .daylight)
                ],
                sunrise: nil,
                sunset: nil
            )
        }

        #expect(SkyGradient.stops(for: typicalDay(goldenMinutes: 60)).count == SkyGradient.stops(for: typicalDay(goldenMinutes: 180)).count)
    }

    private func expect(_ color: Color, matches expected: Color, sourceLocation: SourceLocation = #_sourceLocation) {
        let actual = color.resolve(in: EnvironmentValues())
        let expected = expected.resolve(in: EnvironmentValues())
        #expect(abs(actual.red - expected.red) < 0.01, sourceLocation: sourceLocation)
        #expect(abs(actual.green - expected.green) < 0.01, sourceLocation: sourceLocation)
        #expect(abs(actual.blue - expected.blue) < 0.01, sourceLocation: sourceLocation)
    }
}

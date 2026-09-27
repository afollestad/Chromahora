//
//  SkyGradient.swift
//  Chromahora
//

import SwiftUI

/// Paints the day top to bottom, with each phase's color placed by its time.
struct SkyGradient: View {
    let day: SolarDay

    /// Blue and golden hours are near-complementary, so they blend through a
    /// dusky mauve rather than a muddy olive.
    private static let duskBridge = Color(red: 0.55, green: 0.33, blue: 0.48)

    var body: some View {
        Rectangle()
            .fill(.linearGradient(Gradient(stops: Self.stops(for: day)).colorSpace(.perceptual), startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
    }

    /// The painted color `fraction` of the way down the day, blended the same way as the gradient.
    static func color(at fraction: Double, in day: SolarDay) -> Color {
        let stops = stops(for: day)
        guard let upper = stops.firstIndex(where: { $0.location >= fraction }) else {
            return stops.last?.color ?? DayPhase.night.color
        }
        guard upper > 0 else {
            return stops[upper].color
        }

        // `upper` is the first stop at or past `fraction`, so `lower` sits strictly before it.
        let lower = stops[upper - 1]
        // A held phase returns its own color, which stays equal as the fraction moves,
        // so observers of a scroll don't update on every frame across night or daylight.
        guard lower.color != stops[upper].color else {
            return stops[upper].color
        }
        let progress = (fraction - lower.location) / (stops[upper].location - lower.location)
        return lower.color.mix(with: stops[upper].color, by: progress, in: .perceptual)
    }

    /// Two stops per segment, plus a bridge between blue and golden hours, so the count
    /// depends only on the day's phase sequence and never on how long each phase lasts.
    static func stops(for day: SolarDay) -> [Gradient.Stop] {
        let segments = day.segments
        var stops: [Gradient.Stop] = []

        for (index, segment) in segments.enumerated() {
            let color = segment.phase.color
            let held = segment.phase.holdsColor
                ? segment.interval.start...segment.interval.end
                : segment.heldColorRange
            stops.append(.init(color: color, location: day.fraction(of: held.lowerBound)))
            stops.append(.init(color: color, location: day.fraction(of: held.upperBound)))

            if index + 1 < segments.count, needsBridge(segment.phase, segments[index + 1].phase) {
                stops.append(.init(color: duskBridge, location: day.fraction(of: segment.interval.end)))
            }
        }

        return stops
    }

    private static func needsBridge(_ lhs: DayPhase, _ rhs: DayPhase) -> Bool {
        Set([lhs, rhs]) == [.blueHour, .goldenHour]
    }
}

#Preview {
    SkyGradient(day: .mock())
        .ignoresSafeArea()
}

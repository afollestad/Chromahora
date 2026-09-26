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
    private let duskBridge = Color(red: 0.55, green: 0.33, blue: 0.48)

    var body: some View {
        Rectangle()
            .fill(.linearGradient(gradient, startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
    }

    private var gradient: AnyGradient {
        let segments = day.segments
        var stops: [Gradient.Stop] = []

        for (index, segment) in segments.enumerated() {
            let start = day.fraction(of: segment.interval.start)
            let end = day.fraction(of: segment.interval.end)
            let color = segment.phase.color

            if segment.phase.holdsColor {
                stops.append(.init(color: color, location: start))
                stops.append(.init(color: color, location: end))
            } else {
                stops.append(.init(color: color, location: (start + end) / 2))
            }

            if index + 1 < segments.count, needsBridge(segment.phase, segments[index + 1].phase) {
                stops.append(.init(color: duskBridge, location: end))
            }
        }

        return Gradient(stops: stops).colorSpace(.perceptual)
    }

    private func needsBridge(_ lhs: DayPhase, _ rhs: DayPhase) -> Bool {
        Set([lhs, rhs]) == [.blueHour, .goldenHour]
    }
}

#Preview {
    SkyGradient(day: .mock())
        .ignoresSafeArea()
}

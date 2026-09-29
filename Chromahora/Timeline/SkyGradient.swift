//
//  SkyGradient.swift
//  Chromahora
//

import SwiftUI

/// Paints the day top to bottom, with each phase's color placed by its time.
///
/// Animating to another day with the same phase sequence glides each stop to its new
/// place. Callers give each sequence its own identity, since other days' stops don't pair up.
@Animatable
struct SkyGradient: View {
    @AnimatableIgnored let day: SolarDay
    private var locations: StopLocations

    /// Blue and golden hours are near-complementary, so they blend through a
    /// dusky mauve rather than a muddy olive.
    static let duskBridge = Color(red: 0.55, green: 0.33, blue: 0.48)

    init(day: SolarDay) {
        self.day = day
        locations = StopLocations(Self.stops(for: day).map { Double($0.location) })
    }

    var body: some View {
        let stops = Self.stops(for: day)
        let placed: [Gradient.Stop] = stops.count == locations.values.count
            ? zip(stops, locations.values).map { stop, location in Gradient.Stop(color: stop.color, location: CGFloat(location)) }
            : stops
        Rectangle()
            .fill(.linearGradient(Gradient(stops: placed).colorSpace(.perceptual), startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
    }

    /// The painted color `fraction` of the way down the day, blended the same way as the gradient.
    static func color(at fraction: Double, in day: SolarDay) -> Color {
        color(at: fraction, in: stops(for: day))
    }

    /// The painted color `fraction` of the way down a day with gradient `stops`.
    static func color(at fraction: Double, in stops: [Gradient.Stop]) -> Color {
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

    /// The sky's relative luminance where white and black text contrast with it equally.
    static let crossoverLuminance = 0.18

    /// The scheme text takes over `color`, so it contrasts with the sky rather than follow the
    /// system's appearance, as a timeline label or a widget does. Labels scroll with the sky
    /// beneath them, so unlike the bar's `DayTimeline.prefersDarkBar(over:wasDark:)` they need
    /// no margin against flicker.
    static func labelScheme(over color: Color) -> ColorScheme {
        luminance(of: color) < crossoverLuminance ? .dark : .light
    }

    /// Relative luminance as WCAG defines it, which weights green most because the eye is most sensitive to it.
    static func luminance(of color: Color) -> Double {
        let resolved = color.resolve(in: EnvironmentValues())
        return 0.2126 * Double(resolved.linearRed) + 0.7152 * Double(resolved.linearGreen) + 0.0722 * Double(resolved.linearBlue)
    }

    private static func needsBridge(_ lhs: DayPhase, _ rhs: DayPhase) -> Bool {
        Set([lhs, rhs]) == [.blueHour, .goldenHour]
    }
}

/// Gradient stop locations as one animatable value. Only same-length lists are animated
/// between, so entries missing from either side, as in `zero`, count as 0.
nonisolated struct StopLocations: VectorArithmetic {
    var values: [Double]

    init(_ values: [Double]) {
        self.values = values
    }

    static var zero: StopLocations {
        StopLocations([])
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    static func + (lhs: StopLocations, rhs: StopLocations) -> StopLocations {
        combine(lhs, rhs, +)
    }

    static func - (lhs: StopLocations, rhs: StopLocations) -> StopLocations {
        combine(lhs, rhs, -)
    }

    private static func combine(_ lhs: StopLocations, _ rhs: StopLocations, _ operation: (Double, Double) -> Double) -> StopLocations {
        let count = max(lhs.values.count, rhs.values.count)
        return StopLocations((0..<count).map { index in
            operation(
                index < lhs.values.count ? lhs.values[index] : 0,
                index < rhs.values.count ? rhs.values[index] : 0
            )
        })
    }
}

#Preview {
    SkyGradient(day: .mock())
        .ignoresSafeArea()
}

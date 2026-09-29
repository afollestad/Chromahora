//
//  SkyStrip.swift
//  Chromahora
//

import SwiftUI
import WidgetKit

/// A day's sky from midnight to midnight, left to right, as the app's timeline paints it top to
/// bottom, with now marked and 6 AM, noon and 6 PM beneath. Decorative: the rows below it say
/// the times.
struct SkyStrip: View {
    let day: SolarDay
    /// Marked when it falls on the day.
    let now: Date?

    @Environment(\.widgetRenderingMode) private var renderingMode

    /// The hours labeled beneath, a quarter of the day apart.
    private static let labeledHours: Set<Int> = [6, 12, 18]

    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 5)
                .fill(.linearGradient(gradient, startPoint: .leading, endPoint: .trailing))
                // Keeps the band's edge where the widget's own sky matches it.
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.25), lineWidth: 0.5))
                .overlay(alignment: .leading) {
                    if let now, day.contains(now) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(.primary)
                                .frame(width: 2, height: proxy.size.height + 6)
                                .position(x: proxy.size.width * day.fraction(of: now), y: proxy.size.height / 2)
                                .widgetAccentable()
                        }
                    }
                }
                .frame(height: 16)
            GeometryReader { proxy in
                ForEach(day.hourMarks.filter { Self.labeledHours.contains($0.hour) }) { mark in
                    Text(day.hourText(mark.date))
                        .fixedSize()
                        .position(x: proxy.size.width * day.fraction(of: mark.date), y: proxy.size.height / 2)
                }
            }
            .font(.caption2.monospacedDigit())
            .frame(height: 12)
        }
        .accessibilityHidden(true)
    }

    /// The timeline's stops. On a tinted or clear Home Screen, where the system draws everything
    /// in one color at the opacity given, each stop turns white at an opacity that follows its
    /// brightness, so night still reads darker than day, and stops short of opaque, so the now
    /// tick shows over daylight.
    private var gradient: AnyGradient {
        let stops = SkyGradient.stops(for: day)
        guard renderingMode == .accented else {
            return Gradient(stops: stops).colorSpace(.perceptual)
        }
        let daylight = SkyGradient.luminance(of: DayPhase.daylight.color)
        return Gradient(stops: stops.map { stop in
            Gradient.Stop(color: .white.opacity(0.15 + 0.45 * min(SkyGradient.luminance(of: stop.color) / daylight, 1)), location: stop.location)
        })
        .colorSpace(.perceptual)
    }
}

#Preview {
    let now = Date.now
    let day = SolarDay.mock(for: now)
    VStack(spacing: 24) {
        SkyStrip(day: day, now: now)
        SkyStrip(day: day, now: now)
            .environment(\.widgetRenderingMode, .accented)
    }
    .padding()
    .background(DayPhase.daylight.color)
}

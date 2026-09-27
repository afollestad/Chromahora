//
//  LoadingSky.swift
//  Chromahora
//

import SwiftUI

/// The first load's placeholder: a night sky with a glow on the horizon that breathes
/// through the app's own blue, mauve and gold, under a note that sun times are coming.
struct LoadingSky: View {
    /// Set once the glow is visible, so leaving it earns the reveal, and a load that
    /// answers before anyone sees the glow just shows the day.
    @Binding var isShown: Bool

    /// Long enough for a cached day to land first, so a warm launch never flashes the glow.
    private static let showDelay: Duration = .milliseconds(300)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            HorizonGlow(progress: reduceMotion ? 0.5 : progress)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            Text("Finding the sun…")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(in: Capsule())
        }
        .opacity(opacity)
        .task {
            isShown = false
            // Delayed through the animation rather than a sleep, and started with `withAnimation`
            // rather than `animation(_:value:)`, so the snapshot harness's transaction can skip
            // straight to the end state. Reduce Motion keeps the delay but drops the fade and the breathing.
            let fade: Animation = reduceMotion ? .linear(duration: 0) : .easeIn(duration: 0.4)
            withAnimation(fade.delay(Self.showDelay / .seconds(1))) {
                opacity = 1
            }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                    progress = 1
                }
            }
            do {
                try await Task.sleep(for: Self.showDelay)
                isShown = true
            } catch {
                // Removed before the glow showed.
            }
        }
        .onDisappear {
            isShown = false
        }
    }
}

/// A glow rising from the bottom edge, from blue at `progress` 0 through the dusk
/// bridge to gold at 1, swelling slightly as it warms.
@Animatable
private struct HorizonGlow: View {
    var progress: Double

    var body: some View {
        let color = Self.color(at: progress)
        EllipticalGradient(
            colors: [color.opacity(0.85), color.opacity(0.3), .clear],
            center: .bottom,
            startRadiusFraction: 0,
            endRadiusFraction: 0.5 + 0.08 * progress
        )
        // Wider than the screen and low, so the glow reads as a horizon rather than a beam.
        .containerRelativeFrame([.horizontal, .vertical]) { length, axis in
            axis == .horizontal ? length * 1.8 : length * 0.6
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    /// Mixed the same way as `SkyGradient`, so the glow crosses mauve rather than mud.
    private static func color(at progress: Double) -> Color {
        if progress < 0.5 {
            DayPhase.blueHour.color.mix(with: SkyGradient.duskBridge, by: progress * 2, in: .perceptual)
        } else {
            SkyGradient.duskBridge.mix(with: DayPhase.goldenHour.color, by: (progress - 0.5) * 2, in: .perceptual)
        }
    }
}

/// Lifts a placeholder off the sky beneath it from the bottom up, like the sky rising from
/// the horizon. Its soft edge starts below the bottom and leaves past the top.
struct SunriseReveal: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content.mask {
            GeometryReader { proxy in
                let height = proxy.size.height * 1.25
                LinearGradient(
                    stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height)
                .offset(y: phase.isIdentity ? 0 : -height)
            }
            // Otherwise the mask stops at the safe area and uncovers the system
            // background under the bar and home indicator.
            .ignoresSafeArea()
        }
    }
}

#Preview {
    @Previewable @State var isShown = false
    LoadingSky(isShown: $isShown)
        .background(DayPhase.night.color)
        .environment(\.colorScheme, .dark)
}

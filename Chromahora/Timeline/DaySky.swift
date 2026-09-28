//
//  DaySky.swift
//  Chromahora
//

import SwiftUI

/// A copy of the day's sky at the same place on screen as the one the timeline scrolls, carried
/// on in its end colors above and below. Behind the timeline, overscrolling uncovers it. Behind
/// `DayPager`'s pages, the bars' soft edge effect fades toward it, and it holds the sky in place
/// while the details slide over it, since the sky only changes top to bottom.
///
/// Only `ScrolledSky` reads `top`, so scrolling redraws that copy rather than its container.
struct DaySky: View {
    let day: SolarDay
    let height: CGFloat
    @Binding var top: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            SkyGradient.color(at: 0, in: day)
            SkyGradient.color(at: 1, in: day)
        }
        .overlay(alignment: .top) {
            ScrolledSky(day: day, height: height, top: $top)
        }
    }
}

/// The day's sky `top` points down the screen.
private struct ScrolledSky: View {
    let day: SolarDay
    let height: CGFloat
    @Binding var top: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Changes between days the same way as the sky it copies.
            SkyGradient(day: day)
                .id(day.phaseSequence)
                .transition(.opacity)
        }
        .animation(reduceMotion ? nil : .smooth, value: day)
        .frame(height: height)
        .offset(y: top)
    }
}

#Preview {
    @Previewable @State var top: CGFloat = -300
    DaySky(day: .mock(), height: DayTimeline.contentHeight(of: .mock()), top: $top)
        .ignoresSafeArea()
}

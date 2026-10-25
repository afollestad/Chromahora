//
//  CloudBand.swift
//  Chromahora
//

import SwiftUI

/// The forecast's cloud cover down the day: a soft white band out from the leading edge, behind
/// the hour ruler, as wide as the hour's sky is covered. It draws on past the day's ends, which
/// `DayPager`'s copy shows past midnight. Hidden from VoiceOver, since each weather marker
/// already says its spell's cloud cover.
struct CloudBand: View {
    let day: SolarDay
    /// The forecast's hours, of any day. Those reaching this one shape the band.
    let hours: [SkyHour]
    /// The leading safe area, past which the band starts, like the ruler's ticks, so partial
    /// cover never hides under the Dynamic Island's side in landscape.
    let leadingInset: CGFloat

    /// A covered sky reaches past the ruler's ticks into its labels, but stays a gutter beside
    /// the sky rather than a veil over it.
    static let maxWidth: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CloudBandShape(profile: CloudProfile(day: day, hours: hours))
                // Brightest at the screen's edge and fading out, so the band's outer edge stays soft
                // and the white hour labels it reaches keep their contrast.
                .fill(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
                // Crossfades between days, like the sky's gradient where it can't glide.
                .id(day.dayStart)
                .transition(.opacity)
        }
        .animation(reduceMotion ? nil : .smooth, value: day.dayStart)
        .frame(width: Self.maxWidth)
        .flipsForRightToLeftLayoutDirection(true)
        .padding(.leading, leadingInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Each run of the profile as a shape out from the leading edge. Curves leave and reach every
/// point level, so the band never bulges past an hour's cover, and stays flat to a run's ends.
private struct CloudBandShape: Shape {
    let profile: CloudProfile

    func path(in rect: CGRect) -> Path {
        Path { path in
            for run in profile.runs {
                guard let first = run.first, let last = run.last else {
                    continue
                }
                func position(_ point: CloudProfile.Point) -> CGPoint {
                    CGPoint(x: rect.minX + rect.width * point.cover, y: rect.minY + rect.height * point.fraction)
                }
                path.move(to: CGPoint(x: rect.minX, y: position(first).y))
                path.addLine(to: position(first))
                for (start, end) in zip(run, run.dropFirst()) {
                    let origin = position(start)
                    let target = position(end)
                    let third = (target.y - origin.y) / 3
                    path.addCurve(
                        to: target,
                        control1: CGPoint(x: origin.x, y: origin.y + third),
                        control2: CGPoint(x: target.x, y: target.y - third)
                    )
                }
                path.addLine(to: CGPoint(x: rect.minX, y: position(last).y))
                path.closeSubpath()
            }
        }
    }
}

#Preview {
    let day = SolarDay.mock()
    ScrollView {
        ZStack {
            SkyGradient(day: day)
            CloudBand(day: day, hours: SkyHour.mock(), leadingInset: 0)
            RulerScrim(leadingInset: 0)
        }
        .frame(height: DayTimeline.contentHeight(of: day))
    }
    .ignoresSafeArea()
}

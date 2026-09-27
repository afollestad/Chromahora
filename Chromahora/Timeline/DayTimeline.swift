//
//  DayTimeline.swift
//  Chromahora
//

import SwiftUI

/// A scrolling, top-to-bottom view of one day. `pointsPerHour` sets the zoom
/// level. The view opens centered on the current time when showing today, and
/// on the middle of its brightest phase otherwise.
struct DayTimeline: View {
    let day: SolarDay
    let now: Date
    /// The forecast's spells, which the overlay marks where they fall on this day.
    var weather: [WeatherSpell] = []
    /// The sky behind the title, which `DayScreen` tints the title and picks the bar's scheme with.
    @Binding var skyBehindTitle: Color
    /// The title's center in global coordinates, which places that sky sample.
    var titleMidY: CGFloat = 0
    /// Scrolls back to the focus time whenever it changes, as Today does.
    var focusRequests = 0
    var pointsPerHour: CGFloat = 72

    private let focusAnchorID = "focus"

    /// Room past the bars at each end of the day, so a label centered on a line near
    /// midnight scrolls clear of them: half the tallest label, at the accessibility1
    /// cap, plus the gap held labels keep from the bars.
    private static let edgeClearance: CGFloat = 24

    /// The sky's relative luminance where white and black text contrast with it
    /// equally is about 0.18. The bar turns dark below this range and light above
    /// it, so scrolling slowly across the crossover doesn't flicker the title.
    private static let darkBarLuminance = 0.17...0.19

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var safeAreaInsets = EdgeInsets()
    /// The timeline's top edge in global coordinates, which places the sky sample behind the title.
    @State private var timelineMinY: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack {
                    // Days with the same phase sequence glide between each other's stops.
                    // Others can't pair up their stops, so they crossfade.
                    SkyGradient(day: day)
                        .id(day.phaseSequence)
                        .transition(.opacity)
                    DayTimelineOverlay(day: day, now: now, safeAreaInsets: safeAreaInsets, weather: weather)
                        // Past accessibility1, even a shortened phase label wraps beside a marker
                        // on a 390pt-wide phone. Applied out here so the overlay's scaled
                        // spacing stops growing at the same size.
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
                .animation(reduceMotion ? nil : .smooth, value: day)
                .frame(height: contentHeight)
                .overlay(alignment: .top) {
                    // Invisible scroll target. The padding keeps its one-point
                    // frame at the focus time.
                    Color.clear
                        .frame(height: 1)
                        .id(focusAnchorID)
                        .padding(.top, contentHeight * day.fraction(of: focusDate))
                }
                // Without this the day ends flush with the screen, under the bars, where a scroll
                // view can't reach past it. Padding rather than content margins, so centering on
                // the focus still uses the whole screen, and the sky continued in the
                // background fills it, so time stays proportional.
                .padding(.top, topClearance)
                .padding(.bottom, safeAreaInsets.bottom + Self.edgeClearance)
            }
            // Overscrolling past either end uncovers this, so each half continues the sky at
            // its end and the scrim runs on without a seam. The opaque sky covers it otherwise.
            .background {
                ZStack {
                    VStack(spacing: 0) {
                        SkyGradient.color(at: 0, in: day)
                        SkyGradient.color(at: 1, in: day)
                    }
                    RulerScrim(leadingInset: safeAreaInsets.leading)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
            .ignoresSafeArea()
            // Measured outside `ignoresSafeArea`, since the scroll content sees no insets at all.
            .onGeometryChange(for: EdgeInsets.self) { proxy in
                proxy.safeAreaInsets
            } action: { insets in
                safeAreaInsets = insets
            }
            // The timeline extends past this frame by the top inset.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY - proxy.safeAreaInsets.top
            } action: { minY in
                timelineMinY = minY
            }
            .scrollEdgeEffectHidden()
            .onAppear {
                proxy.scrollTo(focusAnchorID, anchor: .center)
            }
            // Only a new day moves the focus. The same day with new times, as after a
            // relocation, keeps the scroll where the reader left it.
            .onChange(of: day.dayStart) {
                withAnimation {
                    proxy.scrollTo(focusAnchorID, anchor: .center)
                }
            }
            // Today on another day scrolls once that day loads, through the change above.
            .onChange(of: focusRequests) {
                guard day.contains(now) else {
                    return
                }
                withAnimation {
                    proxy.scrollTo(focusAnchorID, anchor: .center)
                }
            }
            .onScrollGeometryChange(for: Color.self) { geometry in
                let y = geometry.visibleRect.minY + titleMidY - timelineMinY - topClearance
                return SkyGradient.color(at: y / contentHeight, in: day)
            } action: { _, color in
                skyBehindTitle = color
            }
        }
    }

    private var contentHeight: CGFloat {
        pointsPerHour * day.duration / (60 * 60)
    }

    /// Where the day starts in the scroll content, below the padding that lets midnight clear the bar.
    private var topClearance: CGFloat {
        safeAreaInsets.top + Self.edgeClearance
    }

    /// Whether the bar should be dark over `color`. Inside `darkBarLuminance` it keeps `wasDark`.
    static func prefersDarkBar(over color: Color, wasDark: Bool) -> Bool {
        let luminance = luminance(of: color)
        if luminance < darkBarLuminance.lowerBound {
            return true
        }
        if luminance > darkBarLuminance.upperBound {
            return false
        }
        return wasDark
    }

    /// Relative luminance as WCAG defines it, which weights green most because the eye is most sensitive to it.
    static func luminance(of color: Color) -> Double {
        let resolved = color.resolve(in: EnvironmentValues())
        return 0.2126 * Double(resolved.linearRed) + 0.7152 * Double(resolved.linearGreen) + 0.0722 * Double(resolved.linearBlue)
    }

    /// The time the view centers on: now when it falls on this day, otherwise the middle
    /// of the brightest phase the day reaches, since a high-latitude winter day may have no daylight.
    private var focusDate: Date {
        if day.contains(now) {
            return now
        }
        let segments = day.segments
        for phase in [DayPhase.daylight, .goldenHour, .blueHour] {
            if let segment = segments.first(where: { $0.phase == phase }) {
                return segment.midpoint
            }
        }
        return day.dayStart.addingTimeInterval(day.duration / 2)
    }
}

#Preview {
    @Previewable @State var sky = DayPhase.night.color
    DayTimeline(day: .mock(), now: .now, weather: WeatherSpell.mock(), skyBehindTitle: $sky)
}

//
//  DayTimeline.swift
//  Chromahora
//

import SwiftUI

/// A scrolling, top-to-bottom view of one day. `pointsPerHour` sets the zoom
/// level. The view opens centered on the current time when showing today, and
/// on the middle of its brightest phase otherwise, unless `DayPager` opens it at an end.
struct DayTimeline: View {
    let day: SolarDay
    let now: Date
    /// The forecast's spells, which the overlay marks where they fall on this day.
    var weather: [WeatherSpell] = []
    /// The sky behind the title, which `DayScreen` tints the title and picks the bar's scheme with.
    @Binding var skyBehindTitle: Color
    /// The title's center in global coordinates, which places that sky sample.
    var titleMidY: CGFloat = 0
    /// Whether the sources button `DayPager` floats over the timeline takes the dark scheme.
    /// Like the bar, it stays put while the sky scrolls under it, so it takes the bar's
    /// hysteresis rather than a label's scheme.
    @Binding var isSourcesDark: Bool
    /// The sources button's center in global coordinates, which places the sky sample behind it.
    var sourcesMidY: CGFloat = 0
    /// Scrolls whenever it changes: to the focus time for Today, or to a phase or spell the
    /// day panel asks for.
    var focus = Focus()
    /// The day panel's footprint on the trailing edge, zero without one. Labels clear it, and
    /// lines and the sources button stop short of it, since its glass would show a line through
    /// its text. It isn't safe area, which would reach the lines only mixed with the device's.
    var panelInset: CGFloat = 0
    /// The screen's safe area, sources bar included. The timeline draws edge to edge, so its
    /// content sees no insets, and `DayPager` measures them where a push doesn't move them.
    var safeAreaInsets = EdgeInsets()
    /// The timeline's top edge in global coordinates, which places the sky samples behind the
    /// title and the sources button.
    var timelineMinY: CGFloat = 0
    /// Where the view opens.
    var opening = Opening.focus
    /// Whether this is the page on screen rather than one `DayPager` is pushing off it. Only
    /// the page on screen reports the skies under the chrome, follows `focus` and pages.
    var isCurrent = true
    /// Called when a drag that began at one of the ends lets go past it, beyond `EdgePull.threshold`.
    var onPullThrough: ((VerticalEdge) -> Void)?
    /// Where the scroll puts the day's top edge on screen, for the copy of the sky `DayPager`
    /// keeps behind the details page. Only the page on screen writes it.
    @Binding var pagerSkyTop: CGFloat
    var pointsPerHour = Self.defaultPointsPerHour

    /// The zoom a timeline opens at, which `DayPager`'s copy of the sky is drawn at too.
    static let defaultPointsPerHour: CGFloat = 72

    private let focusAnchorID = "focus"
    private let requestAnchorID = "request"

    /// Room past the bars at each end of the day, so a label centered on a line near
    /// midnight scrolls clear of them: half the tallest label, at the accessibility1
    /// cap, plus the gap held labels keep from the bars.
    private static let edgeClearance: CGFloat = 24

    /// The sky's relative luminance where white and black text contrast with it equally.
    private static let crossoverLuminance = 0.18

    /// The bar turns dark below this range and light above it, so scrolling slowly
    /// across the crossover doesn't flicker the title.
    private static let darkBarLuminance = (crossoverLuminance - 0.01)...(crossoverLuminance + 0.01)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where the scroll puts the day's top edge on screen. Only `ScrolledSky` reads it, so
    /// scrolling redraws that copy of the sky rather than the whole timeline.
    @State private var dayTop: CGFloat = 0
    /// How far the timeline is pulled past the end it can page through, if it is. Only
    /// `EdgePullHint` reads it, for the same reason.
    @State private var edgePull: EdgePull?
    /// The end the current drag began at, the only one it can page through, until it lets go
    /// short of it. A drag that scrolls into an end, like a fling, meets the rubber band without
    /// a hint or a page.
    @State private var pageableEdge: VerticalEdge?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack {
                    // Days with the same phase sequence glide between each other's stops.
                    // Others can't pair up their stops, so they crossfade.
                    SkyGradient(day: day)
                        .id(day.phaseSequence)
                        .transition(.opacity)
                    DayTimelineOverlay(
                        day: day,
                        now: now,
                        safeAreaInsets: labelInsets,
                        weather: weather,
                        lineTrailingInset: panelInset > 0 ? labelInsets.trailing : 0
                    )
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
                .overlay(alignment: .top) {
                    // The same for the time the day panel last asked for.
                    Color.clear
                        .frame(height: 1)
                        .id(requestAnchorID)
                        .padding(.top, contentHeight * day.fraction(of: requestedDate))
                }
                // Without this the day ends flush with the screen, under the bars, where a scroll
                // view can't reach past it. Padding rather than content margins, so centering on
                // the focus still uses the whole screen, and the sky continued in the
                // background fills it, so time stays proportional.
                .padding(.top, topClearance)
                .padding(.bottom, safeAreaInsets.bottom + Self.edgeClearance)
            }
            // The day before opens at its end from its first layout. Scrolling there once it appears
            // would move its sky copy mid-push, outside the push's animation, and leave the copy
            // standing where the push ends.
            .defaultScrollAnchor(opening == .end ? .bottom : nil, for: .initialOffset)
            // Overscrolling past either end uncovers this, so each half continues the sky at
            // its end and the scrim runs on without a seam. Standing alone, as in previews, the
            // timeline's own soft edge effect fades the content toward it too, so it also carries
            // the sky wherever the scroll puts it. Inside `DayPager`, the bars take their effect
            // from the pager's scroll view, which fades toward the same copy behind the pages.
            .background {
                ZStack {
                    DaySky(day: day, height: contentHeight, top: $dayTop)
                    RulerScrim(leadingInset: safeAreaInsets.leading)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
            .overlay {
                EdgePullHint(pull: $edgePull, day: day, insets: labelInsets, clearance: Self.edgeClearance)
            }
            .ignoresSafeArea()
            // Blurs labels and lines under the bars when the timeline stands alone. `DayPager` sets
            // the same on the scroll view the bars take their effect from.
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            // A page pulled in from another day lays out at the end it opens at.
            .onAppear {
                if opening == .focus {
                    proxy.scrollTo(focusAnchorID, anchor: .center)
                }
            }
            // Only a new day moves the focus. The same day with new times, as after a
            // relocation, keeps the scroll where the reader left it.
            .onChange(of: day.dayStart) {
                withAnimation {
                    proxy.scrollTo(focusAnchorID, anchor: .center)
                }
            }
            // Today on another day scrolls once that day loads, through the change above.
            .onChange(of: focus) {
                guard isCurrent, day.contains(focus.date ?? now) else {
                    return
                }
                withAnimation {
                    proxy.scrollTo(focus.date == nil ? focusAnchorID : requestAnchorID, anchor: .center)
                }
            }
            .onScrollGeometryChange(for: Color.self) { geometry in
                sky(atGlobalY: titleMidY, in: geometry)
            } action: { _, color in
                if isCurrent {
                    skyBehindTitle = color
                }
            }
            .onScrollGeometryChange(for: Color.self) { geometry in
                sky(atGlobalY: sourcesMidY, in: geometry)
            } action: { _, color in
                if isCurrent {
                    updateSourcesScheme(over: color)
                }
            }
            .onScrollGeometryChange(for: EdgePull?.self) { geometry in
                EdgePull(geometry)
            } action: { _, pull in
                edgePull = pull?.edge == pageableEdge ? pull : nil
            }
            // Only a drag that began at an end and lets go past the threshold pages through it.
            .onScrollPhaseChange { oldPhase, newPhase, context in
                if newPhase == .interacting, oldPhase != .interacting {
                    pageableEdge = [VerticalEdge.top, .bottom].first { EdgePull.isAt($0, in: context.geometry) }
                    return
                }
                guard oldPhase == .interacting else {
                    return
                }
                // Let go short of the end it began at, so momentum carrying back into it only bounces.
                guard let pull = EdgePull(context.geometry), pull.edge == pageableEdge else {
                    pageableEdge = nil
                    return
                }
                if isCurrent, pull.isArmed {
                    onPullThrough?(pull.edge)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                topClearance - geometry.visibleRect.minY
            } action: { _, top in
                // Unanimated, so the copies can't trail the content through an animated scroll.
                withTransaction(\.disablesAnimations, true) {
                    dayTop = top
                    if isCurrent {
                        pagerSkyTop = top
                    }
                }
            }
        }
    }

    /// The insets labels keep from each edge: the device's, and the day panel's on the trailing one.
    private var labelInsets: EdgeInsets {
        var insets = safeAreaInsets
        insets.trailing += panelInset
        return insets
    }

    private var contentHeight: CGFloat {
        Self.contentHeight(of: day, pointsPerHour: pointsPerHour)
    }

    /// How tall `day` draws, which time is proportional to.
    static func contentHeight(of day: SolarDay, pointsPerHour: CGFloat = defaultPointsPerHour) -> CGFloat {
        pointsPerHour * day.duration / (60 * 60)
    }

    /// Where the day starts in the scroll content, below the padding that lets midnight clear the bar.
    private var topClearance: CGFloat {
        safeAreaInsets.top + Self.edgeClearance
    }

    /// The sky scrolled to a point on screen, such as behind the title or the sources button.
    private func sky(atGlobalY globalY: CGFloat, in geometry: ScrollGeometry) -> Color {
        let y = geometry.visibleRect.minY + globalY - timelineMinY - topClearance
        return SkyGradient.color(at: y / contentHeight, in: day)
    }

    /// Assigned only when it flips, so scrolling doesn't redraw the pager every frame.
    private func updateSourcesScheme(over color: Color) {
        let isDark = Self.prefersDarkBar(over: color, wasDark: isSourcesDark)
        if isDark != isSourcesDark {
            isSourcesDark = isDark
        }
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

    /// The scheme a timeline label takes over `color`, so its text and glass contrast with the sky
    /// rather than follow the system's appearance. Labels scroll with the sky beneath them, so
    /// unlike the bar they need no margin against flicker.
    static func labelScheme(over color: Color) -> ColorScheme {
        luminance(of: color) < crossoverLuminance ? .dark : .light
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

    /// The time the day panel last asked for, or the focus time once the day no longer holds it.
    private var requestedDate: Date {
        focus.date.flatMap { day.contains($0) ? $0 : nil } ?? focusDate
    }
}

extension DayTimeline {
    /// Where the view opens: on its focus, or for a page pulled in from the day before or
    /// after, at the end that meets the day it left.
    enum Opening {
        case focus
        case start
        case end
    }

    /// A request to scroll, as Today and the day panel's rows make. Each gets a new `id`, so
    /// asking for the same time again scrolls back to it.
    struct Focus: Equatable {
        private(set) var id = 0
        /// The time to center on, or nil for the view's own focus time.
        private(set) var date: Date?

        mutating func request(_ date: Date? = nil) {
            id += 1
            self.date = date
        }
    }
}

#Preview {
    @Previewable @State var sky = DayPhase.night.color
    @Previewable @State var isSourcesDark = true
    @Previewable @State var skyTop: CGFloat = 0
    // An iPhone's status bar and home indicator, which `DayPager` would measure.
    DayTimeline(
        day: .mock(),
        now: .now,
        weather: WeatherSpell.mock(),
        skyBehindTitle: $sky,
        isSourcesDark: $isSourcesDark,
        safeAreaInsets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0),
        pagerSkyTop: $skyTop
    )
}

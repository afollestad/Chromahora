//
//  DayPager.swift
//  Chromahora
//

import SwiftUI

/// The timeline, paging to the day before or after when a drag pulls it through either end.
/// The day on screen pushes off the far edge as the next springs in from the near one, opening
/// at the end that meets the day it left, so time reads on across midnight.
///
/// Each page is a live `DayTimeline` in one `ForEach`, not a removal transition, so the
/// leaving page keeps its scroll through the push and stops reporting the skies under the
/// chrome, which would otherwise end on the old day's. The sources button floats over every
/// page, so it stays put like the title.
///
/// Without the day panel, a swipe sideways pages from the timeline to the day's details,
/// which dots under the sources button follow. A copy of the sky behind both pages stays where
/// the timeline's scroll puts it, so only the labels slide away and the details over the sky.
struct DayPager: View {
    /// The page a sideways swipe moves between.
    enum Pane: String, CaseIterable, Sendable {
        case timeline
        case details

        var title: String {
            switch self {
            case .timeline: "Timeline"
            case .details: "Details"
            }
        }
    }

    let day: SolarDay
    let now: Date
    /// The forecast's spells, which each page marks where they fall on its day.
    var weather: [WeatherSpell] = []
    /// The forecast's hours, which the details read the day's light and sky from.
    var hours: [SkyHour] = []
    /// The sky behind the title, which the page on screen reports.
    @Binding var skyBehindTitle: Color
    /// The title's center in global coordinates, which places that sky sample.
    var titleMidY: CGFloat = 0
    var focus = TimelineFocus()
    /// The day panel's footprint on the trailing edge, zero without one.
    var panelInset: CGFloat = 0
    /// Selects the day a number of days from the one given, and answers whether it's on hand to
    /// show at once. When it isn't, the selection still moves, and the day loads and glides in
    /// as from the calendar.
    var onPage: (Int, SolarDay) -> Bool = { _, _ in false }
    /// Whether a sideways swipe leads to the day's details, which the day panel shows instead when there is one.
    var showsDetails = false
    /// The page to open on, which snapshots and the `-DebugPane` launch argument set.
    var initialPane = Pane.timeline
    /// Scrolls the timeline to a time a row of the details names, once this has paged back to it.
    var onFocus: (Date) -> Void = { _ in }

    private struct Page: Identifiable {
        let id: Int
        /// The day a leaving page keeps showing. Nil for the page on screen, which follows `day`.
        var frozenDay: SolarDay?
        /// Where a leaving page's scroll left the day's top edge, which its copy of the sky keeps.
        /// Nil for the page on screen, whose copy follows `skyTop`.
        var frozenSkyTop: CGFloat?
        let opening: DayTimeline.Opening
        /// The edge the page sits past while it's off screen: the one a new page enters from
        /// until the push starts, and the one a leaving page pushes off.
        var offscreenEdge: VerticalEdge?
    }

    /// A slight overshoot, so the day lands like the rubber band it was pulled through.
    private static let pageAnimation = Animation.spring(duration: 0.5, bounce: 0.2)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pages = [Page(id: 0, opening: .focus)]
    /// The screen's full height, which a page moves by to clear it, since each draws under the bars.
    @State private var height: CGFloat = 0
    /// The safe area and the timeline's top edge, measured here rather than by each page, since
    /// a page's own measurements move with the push and would lay it out again mid-slide.
    @State private var safeAreaInsets = EdgeInsets()
    @State private var timelineMinY: CGFloat = 0
    /// The sources button's center in global coordinates, which places the sky sample behind it.
    @State private var sourcesMidY: CGFloat = 0
    /// Only `SourcesBar` draws with it, so a scroll that flips it redraws the bar rather than every page.
    @State private var isSourcesDark = true
    /// Where the page on screen puts the day's top edge. Passed down as a binding and read only
    /// by the copy of the sky, so scrolling doesn't redraw the pager.
    @State private var skyTop: CGFloat = 0
    /// The page the sideways scroll rests on, which `scrollPosition` keeps. Nil only before the
    /// pager appears, when it opens on `initialPane` if the details are there to open on.
    @State private var pane: Pane?
    /// How far the sideways scroll has moved from the timeline. Read only by the scrim that
    /// slides with it, like `skyTop`.
    @State private var paneOffset: CGFloat = 0

    var body: some View {
        // The safe area, which the pages ride over rather than size. Inside the sources bar, so
        // the bottom inset includes the button.
        Color.clear
            .onGeometryChange(for: EdgeInsets.self) { proxy in
                proxy.safeAreaInsets
            } action: { insets in
                safeAreaInsets = insets
            }
            // The timeline extends past this frame by the insets.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY - proxy.safeAreaInsets.top
            } action: { minY in
                timelineMinY = minY
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            } action: { height in
                self.height = height
            }
            // Uncovered as the timeline overscrolls past either end or slides away, or a sideways
            // swipe overscrolls. The bars' soft edge effect fades toward it too, so each page's copy
            // moves with the page through a push between days, and it carries the ruler's scrim
            // where the timeline has it.
            .background {
                ZStack {
                    ForEach(pages) { page in
                        let pageDay = page.frozenDay ?? day
                        DaySky(
                            day: pageDay,
                            height: DayTimeline.contentHeight(of: pageDay),
                            top: page.frozenSkyTop.map { .constant($0) } ?? $skyTop
                        )
                        .offset(y: reduceMotion ? 0 : offset(past: page.offscreenEdge))
                        .opacity(reduceMotion && page.offscreenEdge != nil ? 0 : 1)
                        .zIndex(Double(page.id))
                    }
                    SlidingScrim(leadingInset: safeAreaInsets.leading, paneOffset: $paneOffset)
                        .zIndex(Double(pages.last?.id ?? 0) + 1)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
            .overlay {
                panes
            }
            // Outside the pages, so the inset measured above clears the button and it stays put.
            .safeAreaBar(edge: .bottom, spacing: 0) {
                SourcesBar(showsWeather: showsWeather, pane: showsDetails ? currentPane : nil, isDark: $isSourcesDark) { show($0) }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .global).midY
                    } action: { midY in
                        sourcesMidY = midY
                    }
                    // Centered under the timeline rather than the window, clear of the day panel.
                    .padding(.trailing, panelInset)
            }
            // Resolved as the pager appears rather than left to `initialPane`, since a window
            // without the details, like a Pro Max in landscape, opens on the timeline and would
            // otherwise hide it from VoiceOver, and mark the details once turned upright.
            .onAppear {
                pane = openingPane
            }
            .onChange(of: showsDetails) {
                if !showsDetails {
                    pane = .timeline
                }
            }
    }

    /// The timeline and, without the day panel, the details beside it, full screen with no insets
    /// of their own, like the pages.
    private var panes: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                pageStack
                    .containerRelativeFrame(.horizontal)
                    .id(Pane.timeline)
                    .accessibilityHidden(currentPane != .timeline)
                if showsDetails {
                    DayDetailsPage(day: day, now: now, weather: weather, hours: hours, safeAreaInsets: safeAreaInsets) { date in
                        // Once back, since the timeline's own scroll animates too.
                        show(.timeline) {
                            onFocus(date)
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(Pane.details)
                    .accessibilityHidden(currentPane != .details)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        // With the day panel there's only the timeline, which mustn't rubber-band sideways under it.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollPosition(id: $pane)
        .scrollIndicators(.hidden, axes: .horizontal)
        .defaultScrollAnchor(openingPane == .details ? .trailing : nil, for: .initialOffset)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x
        } action: { _, offset in
            withTransaction(\.disablesAnimations, true) {
                paneOffset = offset
            }
        }
        // The bars take their edge effect from this outer scroll view rather than the timeline's,
        // and the default style lays a flat band under each. Soft, it blurs labels and lines under
        // the bars, as Photos does, so they don't run through the clock or the sources button,
        // fading toward the copy of the sky behind. The button's glass would show a line through
        // its text, and it stays put, so the overlay's cutout mask can't clear it.
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .ignoresSafeArea()
    }

    private var currentPane: Pane {
        pane ?? openingPane
    }

    /// `initialPane`, when the details are there to open on.
    private var openingPane: Pane {
        showsDetails ? initialPane : .timeline
    }

    /// Pages to `pane` as a swipe would, or at once with Reduce Motion, then calls `completion`.
    private func show(_ pane: Pane, completion: @escaping () -> Void = {}) {
        withAnimation(reduceMotion ? nil : .smooth) {
            self.pane = pane
        } completion: {
            completion()
        }
    }

    /// Every page, full screen with no insets of their own. A view reaches into the safe area only
    /// as far as it overlaps it where it's drawn, so a page ignoring the safe area itself would
    /// stop drawing under the bars as the push moves it, and lay out again partway across.
    private var pageStack: some View {
        ZStack {
            ForEach(pages) { page in
                let isCurrent = page.id == pages.last?.id
                DayTimeline(
                    day: page.frozenDay ?? day,
                    now: now,
                    weather: weather,
                    skyBehindTitle: $skyBehindTitle,
                    titleMidY: titleMidY,
                    isSourcesDark: $isSourcesDark,
                    sourcesMidY: sourcesMidY,
                    focus: focus,
                    panelInset: panelInset,
                    safeAreaInsets: safeAreaInsets,
                    timelineMinY: timelineMinY,
                    opening: page.opening,
                    isCurrent: isCurrent,
                    onPullThrough: pull(through:),
                    pagerSkyTop: $skyTop
                )
                .offset(y: reduceMotion ? 0 : offset(past: page.offscreenEdge))
                .opacity(reduceMotion && page.offscreenEdge != nil ? 0 : 1)
                .allowsHitTesting(isCurrent)
                .accessibilityHidden(!isCurrent)
                .zIndex(Double(page.id))
                // Moved in by its offset rather than a transition, which would slide the page's
                // content in over its sky already in place.
                .onAppear {
                    if page.offscreenEdge != nil {
                        push(in: page)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    /// Whether any spell or hour reaches the day on screen, which is when its overlay or details
    /// show weather and the sources button credits it.
    private var showsWeather: Bool {
        weather.contains { $0.span(within: day) != nil } || hours.contains { $0.falls(on: day) }
    }

    /// Pages to the day beyond `edge` if the store has it on hand. The page on screen keeps its
    /// day and pushes off the far edge, while the new one comes in from `edge`'s side.
    /// Otherwise the selection still moves, and the day loads and glides in as from the calendar.
    private func pull(through edge: VerticalEdge) {
        guard let live = pages.last else {
            return
        }
        let index = pages.count - 1
        // Frozen before the store moves on, so the leaving page never takes the new day, which
        // would glide its sky there and scroll it to that day's focus. Its copy of the sky keeps
        // the scroll it had, since the page coming in writes `skyTop` from here on.
        pages[index].frozenDay = day
        pages[index].frozenSkyTop = skyTop
        // Unanimated, so the title and day panel change days at once, as from the calendar.
        guard onPage(EdgePull.dayOffset(beyond: edge), day) else {
            pages[index].frozenDay = nil
            pages[index].frozenSkyTop = nil
            return
        }
        pages.append(Page(id: live.id + 1, opening: edge == .top ? .end : .start, offscreenEdge: edge))
    }

    /// Pushes the page on screen off the far edge as `entering` comes in from its own.
    private func push(in entering: Page) {
        guard let edge = entering.offscreenEdge else {
            return
        }
        let leavingIDs = Set(pages.filter { $0.id < entering.id && $0.offscreenEdge == nil }.map(\.id))
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : Self.pageAnimation) {
            for index in pages.indices {
                if pages[index].id == entering.id {
                    pages[index].offscreenEdge = nil
                } else if leavingIDs.contains(pages[index].id) {
                    pages[index].offscreenEdge = edge == .top ? .bottom : .top
                }
            }
        } completion: {
            pages.removeAll { leavingIDs.contains($0.id) }
        }
    }

    private func offset(past edge: VerticalEdge?) -> CGFloat {
        switch edge {
        case .top: -height
        case .bottom: height
        case nil: 0
        }
    }
}

/// The sources button, with the page dots under it while the details sit beside the timeline,
/// in the scheme of the sky behind them.
private struct SourcesBar: View {
    let showsWeather: Bool
    /// The page on screen, or nil without the details, which leaves out the dots.
    let pane: DayPager.Pane?
    @Binding var isDark: Bool
    let onSelect: (DayPager.Pane) -> Void

    var body: some View {
        let scheme: ColorScheme = isDark ? .dark : .light
        SourcesButton(showsWeather: showsWeather, scheme: scheme)
            // An overlay, so the dots add nothing to the bar's height, which sets the band
            // the edge effect blurs.
            .overlay(alignment: .bottom) {
                if let pane {
                    PageDots(pane: pane, scheme: scheme, onSelect: onSelect)
                        .offset(y: PageDots.offset)
                }
            }
    }
}

/// The ruler's scrim behind the pages, sliding sideways with the timeline.
private struct SlidingScrim: View {
    let leadingInset: CGFloat
    @Binding var paneOffset: CGFloat

    var body: some View {
        RulerScrim(leadingInset: leadingInset)
            .offset(x: -paneOffset)
    }
}

#Preview {
    @Previewable @State var day = SolarDay.mock()
    @Previewable @State var sky = DayPhase.night.color
    DayPager(day: day, now: .now, weather: WeatherSpell.mock(), skyBehindTitle: $sky) { offset, shown in
        guard let date = shown.calendar.date(byAdding: .day, value: offset, to: shown.dayStart) else {
            return false
        }
        day = .mock(for: date)
        return true
    }
}

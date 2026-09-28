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
struct DayPager: View {
    let day: SolarDay
    let now: Date
    /// The forecast's spells, which each page marks where they fall on its day.
    var weather: [WeatherSpell] = []
    /// The sky behind the title, which the page on screen reports.
    @Binding var skyBehindTitle: Color
    /// The title's center in global coordinates, which places that sky sample.
    var titleMidY: CGFloat = 0
    var focus = DayTimeline.Focus()
    /// The day panel's footprint on the trailing edge, zero without one.
    var panelInset: CGFloat = 0
    /// Selects the day containing a date, and answers whether it's on hand to show at once.
    /// When it isn't, the selection still moves, and the day loads and glides in as from the calendar.
    var onPage: (Date) -> Bool = { _ in false }

    private struct Page: Identifiable {
        let id: Int
        /// The day a leaving page keeps showing. Nil for the page on screen, which follows `day`.
        var frozenDay: SolarDay?
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
    @State private var isSourcesDark = true

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
            .overlay {
                pageStack
            }
            // Outside the pages, so the inset measured above clears the button and it stays put.
            .safeAreaBar(edge: .bottom, spacing: 0) {
                SourcesButton(showsWeather: showsWeather, scheme: isSourcesDark ? .dark : .light)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .global).midY
                    } action: { midY in
                        sourcesMidY = midY
                    }
                    // Centered under the timeline rather than the window, clear of the day panel.
                    .padding(.trailing, panelInset)
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
                    onPullThrough: pull(through:)
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

    /// Whether any spell reaches the day on screen, which is when its overlay marks weather and the sources button credits it.
    private var showsWeather: Bool {
        weather.contains { $0.span(within: day) != nil }
    }

    /// Pages to the day beyond `edge` if the store has it on hand. The page on screen keeps its
    /// day and pushes off the far edge, while the new one comes in from `edge`'s side.
    /// Otherwise the selection still moves, and the day loads and glides in as from the calendar.
    private func pull(through edge: VerticalEdge) {
        guard let target = EdgePull.dayStart(beyond: edge, of: day), let live = pages.last else {
            return
        }
        let index = pages.count - 1
        // Frozen before the store moves on, so the leaving page never takes the new day, which
        // would glide its sky there and scroll it to that day's focus.
        pages[index].frozenDay = day
        // Unanimated, so the title and day panel change days at once, as from the calendar.
        guard onPage(target) else {
            pages[index].frozenDay = nil
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

#Preview {
    @Previewable @State var day = SolarDay.mock()
    @Previewable @State var sky = DayPhase.night.color
    DayPager(day: day, now: .now, weather: WeatherSpell.mock(), skyBehindTitle: $sky) { date in
        day = .mock(for: date)
        return true
    }
}

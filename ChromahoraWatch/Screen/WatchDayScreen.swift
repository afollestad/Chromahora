//
//  WatchDayScreen.swift
//  ChromahoraWatch
//

import SwiftUI

/// The watch's one screen: the day's timeline under the place's name, with its details a swipe
/// away as on the phone, or what stands in for them, with buttons along the bottom that move a
/// day at a time and return to today. The Crown scrolls the page on screen, so it's left to that
/// alone.
struct WatchDayScreen: View {
    /// The page a sideways swipe moves between.
    enum Pane: Hashable {
        case timeline
        case details
    }

    let state: SolarDayStore.LoadState
    let now: Date
    /// The day to show, which the day on screen trails while it loads.
    let selectedDate: Date
    /// The store's calendar, whose zone reads `selectedDate`.
    let calendar: Calendar
    let place: Place?
    let deviceName: String?
    /// The forecast's spells, of any day.
    let weather: [WeatherSpell]
    /// The forecast's hours, of any day, which the details read the day's light and sky from.
    let hours: [SkyHour]
    let onRetry: () -> Void
    /// Selects the day `offset` days from `day`, as `SolarDayStore.selectDay(offsetBy:from:)` does.
    let onPage: (Int, SolarDay) -> Bool
    let onToday: () -> Void

    /// Where the timeline scrolls: to now for the day button on today, or to a row's time.
    @State private var focus = TimelineFocus()
    @State private var pane = Pane.timeline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(place?.title(deviceName: deviceName) ?? "")
                .toolbar {
                    if !hidesBar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button("Previous Day", systemImage: "chevron.backward") {
                                page(by: -1)
                            }
                            .disabled(pageableDay == nil)
                            Button(action: showToday) {
                                Text(isShowingToday ? "Today" : selectedDate.shortDayTitle(in: calendar.timeZone))
                            }
                            .accessibilityLabel(isShowingToday ? "Today" : selectedDate.dayTitle(in: calendar.timeZone))
                            .accessibilityHint(isShowingToday ? "Scrolls to now" : "Shows today")
                            Button("Next Day", systemImage: "chevron.forward") {
                                page(by: 1)
                            }
                            .disabled(pageableDay == nil)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let day = state.day {
            TabView(selection: $pane) {
                WatchTimeline(day: day, now: now, weather: weather, focus: focus)
                    // A new scroll view for each day, so every day opens on its own focus.
                    .id(day.dayStart)
                    .tag(Pane.timeline)
                WatchDetailsPage(day: day, now: now, weather: weather, hours: hours) { date in
                    // Once back, so the timeline's scroll shows rather than ending off screen.
                    show(.timeline) {
                        focus.request(date)
                    }
                }
                .tag(Pane.details)
            }
            .tabViewStyle(.page)
        } else {
            WatchPlaceholder(state: state, date: selectedDate, timeZone: calendar.timeZone, onRetry: onRetry)
        }
    }

    private var isShowingToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: now)
    }

    /// The day paging moves from: the one on screen, once it's the one selected. Nil while another
    /// loads, since a page from the day still shown would land back on the one loading, or behind
    /// it, and nil when a day couldn't load.
    private var pageableDay: SolarDay? {
        if case .loaded(let day) = state, day.contains(selectedDate) { day } else { nil }
    }

    /// While today loads with nothing on screen, there's no day to page from or return to, so the
    /// glow has the screen. Any other day keeps the way back to today, even one that couldn't
    /// load, or loads again from nothing after that.
    private var hidesBar: Bool {
        if case .loading(.none) = state { isShowingToday } else { false }
    }

    /// On today, centers the timeline on now, paging back to it from the details.
    private func showToday() {
        if isShowingToday {
            show(.timeline) {
                focus.request()
            }
        } else {
            withAnimation {
                onToday()
            }
        }
    }

    /// Shows `pane`, then calls `completion` once it's on screen. The watchOS 27 simulator cuts
    /// to a paged `TabView`'s page even inside an animation, so a row's scroll plays after the
    /// cut. The animation, off with Reduce Motion, is in case a real watch slides instead.
    private func show(_ pane: Pane, completion: @escaping () -> Void) {
        guard self.pane != pane else {
            completion()
            return
        }
        withAnimation(reduceMotion ? nil : .default) {
            self.pane = pane
        } completion: {
            completion()
        }
    }

    private func page(by offset: Int) {
        guard let day = pageableDay else {
            return
        }
        withAnimation {
            _ = onPage(offset, day)
        }
    }
}

#Preview {
    let now = Date.now
    WatchDayScreen(
        state: .loaded(.mock(for: now)),
        now: now,
        selectedDate: now,
        calendar: .current,
        place: MockPlaceProvider.sanFrancisco,
        deviceName: "San Francisco",
        weather: WeatherSpell.mock(),
        hours: SkyHour.mock(),
        onRetry: {},
        onPage: { _, _ in false },
        onToday: {}
    )
}

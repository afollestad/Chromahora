//
//  WatchDayScreen.swift
//  ChromahoraWatch
//

import SwiftUI

/// The watch's one screen: the day's timeline under the place's name, or what stands in for
/// it, with buttons along the bottom that move a day at a time and return to today. The Crown
/// scrolls the timeline, so it's left to that alone.
struct WatchDayScreen: View {
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
    let onRetry: () -> Void
    /// Selects the day `offset` days from `day`, as `SolarDayStore.selectDay(offsetBy:from:)` does.
    let onPage: (Int, SolarDay) -> Bool
    let onToday: () -> Void

    /// Bumped by the day button on today, which centers the timeline on now again.
    @State private var focusRequest = 0

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
            WatchTimeline(day: day, now: now, weather: weather, focusRequest: focusRequest)
                // A new scroll view for each day, so every day opens on its own focus.
                .id(day.dayStart)
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

    private func showToday() {
        if isShowingToday {
            focusRequest += 1
        } else {
            withAnimation {
                onToday()
            }
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
        onRetry: {},
        onPage: { _, _ in false },
        onToday: {}
    )
}

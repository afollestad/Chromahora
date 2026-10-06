//
//  WatchDayScreen.swift
//  ChromahoraWatch
//

import SwiftUI

/// The watch's one screen: a day's cards under its name, which the Crown moves through, with
/// the days either side a sideways swipe away, or what stands in for them while none is on
/// screen. Away from today, a button in the corner returns to it, and while VoiceOver runs,
/// buttons along the bottom page a day at a time.
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
    /// The forecast's hours, of any day, which the details read the day's light and sky from.
    let hours: [SkyHour]
    let onRetry: () -> Void
    /// The day `offset` days from the one given, if the store holds it, as `SolarDayStore.loadedDay(offsetBy:from:)` gives it.
    let neighbor: (Int, SolarDay) -> SolarDay?
    /// Selects the day `offset` days from `day`, as `SolarDayStore.selectDay(offsetBy:from:)` does.
    let onPage: (Int, SolarDay) -> Bool
    let onToday: () -> Void

    @State private var card = WatchCard.summary
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverRunning

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title(for: selectedDate))
                .toolbar {
                    if !isShowingToday {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Today", systemImage: "arrow.uturn.backward", action: showToday)
                                .accessibilityHint("Shows today")
                        }
                    }
                    // VoiceOver can't count on the swipe between days, so it gets buttons, which
                    // everyone else goes without, since they'd cover the bottom of every card.
                    if isVoiceOverRunning {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button("Previous Day", systemImage: "chevron.backward") {
                                page(by: -1)
                            }
                            .disabled(pageableDay == nil)
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
        if let day = shownDay {
            WatchDayPager(
                day: day,
                now: now,
                placeName: place?.title(deviceName: deviceName),
                weather: weather,
                hours: hours,
                isPageable: pageableDay != nil,
                neighbor: neighbor,
                onPage: onPage,
                card: $card
            )
        } else {
            WatchPlaceholder(state: state, date: selectedDate, timeZone: calendar.timeZone, onRetry: onRetry)
        }
    }

    /// The day `date` falls on, as near as names go: today, the days either side, or its date.
    private func title(for date: Date) -> String {
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day
        return switch offset {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        default: date.shortDayTitle(in: calendar.timeZone)
        }
    }

    private var isShowingToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: now)
    }

    /// The day on screen while it's the one selected, loaded or still shown as it reloads. Nil
    /// while another day loads, which the placeholder stands in for rather than show the day
    /// it left under the new one's name.
    private var shownDay: SolarDay? {
        state.day.flatMap { $0.contains(selectedDate) ? $0 : nil }
    }

    /// The day paging moves from: the one on screen, once it's the one selected. Nil while another
    /// loads, since a page from the day still shown would land back on the one loading, or behind
    /// it, and nil when a day couldn't load.
    private var pageableDay: SolarDay? {
        if case .loaded(let day) = state, day.contains(selectedDate) { day } else { nil }
    }

    /// Pages a day as a swipe does, then names the day it lands on, since VoiceOver stays on the
    /// button rather than read the new title.
    private func page(by offset: Int) {
        guard let day = pageableDay, let date = day.calendar.date(byAdding: .day, value: offset, to: day.dayStart) else {
            return
        }
        withAnimation {
            _ = onPage(offset, day)
        }
        AccessibilityNotification.Announcement(title(for: date)).post()
    }

    /// Returns to today's summary, where the countdown is. Pages there as a swipe does when
    /// today is held, so it shows at once rather than after the placeholder.
    private func showToday() {
        withAnimation {
            card = .summary
            if let day = shownDay, let offset = day.calendar.dateComponents([.day], from: day.dayStart, to: day.calendar.startOfDay(for: now)).day {
                _ = onPage(offset, day)
            } else {
                onToday()
            }
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
        neighbor: { _, _ in nil },
        onPage: { _, _ in false },
        onToday: {}
    )
}

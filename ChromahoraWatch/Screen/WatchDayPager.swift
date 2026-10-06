//
//  WatchDayPager.swift
//  ChromahoraWatch
//

import SwiftUI

/// Which of a day's cards is on screen. Paging to another day keeps it, so evenings can be
/// compared a swipe apart.
enum WatchCard: Hashable {
    case summary
    case morning
    case evening
    case details
}

/// The day on screen between the days either side, which a sideways swipe pages to, each a
/// column of cards the Crown moves through. Once a swipe lands, the store selects the day it
/// landed on and the pager slips back to the middle page without animation, which now shows
/// that day, so it can always page on either way.
struct WatchDayPager: View {
    let day: SolarDay
    let now: Date
    let placeName: String?
    /// The forecast's spells, of any day.
    let weather: [WeatherSpell]
    /// The forecast's hours, of any day.
    let hours: [SkyHour]
    /// Whether `day` is the one selected and loaded. While another loads, or this one reloads,
    /// there's no day to page from, since a page from the day still shown would land on the one
    /// loading, or behind it.
    let isPageable: Bool
    /// The day `offset` days from the one given, if the store holds it.
    let neighbor: (Int, SolarDay) -> SolarDay?
    /// Selects the day `offset` days from the one given, as `SolarDayStore.selectDay(offsetBy:from:)` does.
    let onPage: (Int, SolarDay) -> Bool
    @Binding var card: WatchCard

    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            if isPageable {
                neighborPage(-1)
                    .tag(-1)
            }
            WatchDayCards(day: day, nextDay: neighbor(1, day), now: now, placeName: placeName, weather: weather, hours: hours, card: $card)
                .tag(0)
            if isPageable {
                neighborPage(1)
                    .tag(1)
            }
        }
        // Dots for three pages that always recenter would say nothing.
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: page) { _, offset in
            guard offset != 0 else {
                return
            }
            // Unanimated, so the middle page takes the day it lands on in place of the one beside it.
            withTransaction(\.disablesAnimations, true) {
                _ = onPage(offset, day)
                page = 0
            }
        }
    }

    /// The day beside the one on screen, or the night sky while it's yet to load.
    @ViewBuilder
    private func neighborPage(_ offset: Int) -> some View {
        if let other = neighbor(offset, day) {
            // Yesterday's next day is the one on screen, which today's summary reads into.
            WatchDayCards(day: other, nextDay: offset < 0 ? day : nil, now: now, placeName: placeName, weather: weather, hours: hours, card: $card)
        } else {
            DayPhase.night.color
                .ignoresSafeArea()
                .overlay {
                    ProgressView()
                }
        }
    }
}

/// One day's cards, which the Crown moves through: the summary, the morning and the evening,
/// and the details, which scroll on past the screen.
private struct WatchDayCards: View {
    let day: SolarDay
    let nextDay: SolarDay?
    let now: Date
    let placeName: String?
    let weather: [WeatherSpell]
    let hours: [SkyHour]
    @Binding var card: WatchCard

    var body: some View {
        let ends = DayRun(day, then: nextDay.map { [$0] } ?? []).ends(of: day)
        TabView(selection: $card) {
            WatchSummaryCard(day: day, nextDay: nextDay, now: now, placeName: placeName)
                .tag(WatchCard.summary)
            WatchEndCard(kind: .morning, day: day, end: ends.morning, now: now, weather: weather)
                .tag(WatchCard.morning)
            WatchEndCard(kind: .evening, day: day, end: ends.evening, now: now, weather: weather)
                .tag(WatchCard.evening)
            WatchDetailsPage(day: day, now: now, weather: weather, hours: hours)
                .tag(WatchCard.details)
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    @Previewable @State var day = SolarDay.mock()
    @Previewable @State var card = WatchCard.summary
    NavigationStack {
        WatchDayPager(
            day: day,
            now: .now,
            placeName: "San Francisco",
            weather: WeatherSpell.mock(),
            hours: SkyHour.mock(),
            isPageable: true,
            neighbor: { offset, shown in
                shown.calendar.date(byAdding: .day, value: offset, to: shown.dayStart).map { SolarDay.mock(for: $0) }
            },
            onPage: { offset, shown in
                guard let date = shown.calendar.date(byAdding: .day, value: offset, to: shown.dayStart) else {
                    return false
                }
                day = .mock(for: date)
                return true
            },
            card: $card
        )
    }
}

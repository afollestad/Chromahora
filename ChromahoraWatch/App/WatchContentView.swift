//
//  WatchContentView.swift
//  ChromahoraWatch
//

import SwiftUI

struct WatchContentView: View {
    @State private var store: SolarDayStore
    @State private var weather: WeatherStore
    private let placeNames: PlaceNames
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    init(
        provider: any SolarDayProvider,
        placeProvider: any PlaceProvider,
        weatherProvider: any WeatherProvider,
        placeNames: PlaceNames,
        selectedDate: Date = .now
    ) {
        _store = State(initialValue: SolarDayStore(provider: provider, placeProvider: placeProvider, selectedDate: selectedDate))
        _weather = State(initialValue: WeatherStore(provider: weatherProvider))
        self.placeNames = placeNames
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = now(from: context.date)
            WatchDayScreen(
                state: store.state,
                now: now,
                selectedDate: store.selectedDate,
                calendar: store.calendar,
                place: store.place,
                deviceName: placeNames.name(for: store.place),
                // For the day on screen, which keeps the last place's until the new one's loads.
                weather: weather.spells(at: store.shownPlace),
                onRetry: store.reload,
                onPage: store.selectDay(offsetBy:from:),
                onToday: { [store] in store.selectedDate = now }
            )
            // The watch keeps the app in memory overnight, and a wrist raised the next morning
            // should find today rather than yesterday.
            .onChange(of: now) { previous, current in
                store.advanceToToday(from: previous, to: current)
            }
        }
        .dayLoading(store: store, weather: weather, placeNames: placeNames, nowOverride: nowOverride)
    }

    /// The time the app shows as now, which the debug settings can override.
    private func now(from date: Date) -> Date {
        nowOverride ?? date
    }

    /// The debug settings' clock, if it overrides the real one.
    private var nowOverride: Date? {
        #if DEBUG
        debug?.nowOverride
        #else
        nil
        #endif
    }
}

#Preview {
    WatchContentView(
        provider: MockSolarDayProvider(),
        placeProvider: MockPlaceProvider(),
        weatherProvider: MockWeatherProvider(),
        placeNames: PlaceNames(search: MockPlaceSearch(), defaults: nil)
    )
}

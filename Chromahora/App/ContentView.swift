//
//  ContentView.swift
//  Chromahora
//
//  Created by Aidan Follestad on 9/26/26.
//

import SwiftUI

struct ContentView: View {
    /// Locating waits for the app to be on screen, and runs again each time it returns
    /// from the background.
    private struct LocateTrigger: Hashable {
        let isOnScreen: Bool
        let count: Int
    }

    /// One store per window, so each window can show its own day.
    @State private var store: SolarDayStore
    @State private var weather: WeatherStore
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    init(
        provider: any SolarDayProvider,
        placeProvider: any PlaceProvider,
        weatherProvider: any WeatherProvider,
        selectedDate: Date = .now
    ) {
        _store = State(initialValue: SolarDayStore(provider: provider, placeProvider: placeProvider, selectedDate: selectedDate))
        _weather = State(initialValue: WeatherStore(provider: weatherProvider))
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                DayScreen(
                    state: store.state,
                    now: now(from: context.date),
                    selectedDate: $store.selectedDate,
                    place: store.place,
                    weather: weather.spells(at: store.place),
                    onRetry: store.reload,
                    onPage: store.selectDay(offsetBy:from:)
                )
            }
        }
        // Returning to the app after travel relocates. Only the background counts as leaving:
        // the permission prompt and Control Center make the app inactive, and restarting
        // for them would drop the fix in progress.
        .task(id: LocateTrigger(isOnScreen: scenePhase != .background, count: store.locateCount)) {
            if scenePhase != .background {
                await store.locate()
            }
        }
        .task(id: store.loadKey) {
            await store.loadSelectedDay()
            await store.loadAdjacentDays()
        }
        // Travel can change the device's zone while the app is suspended, and days are windowed to it.
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSSystemTimeZoneDidChange) {
                store.changeTimeZone(to: Calendar.current.timeZone)
            }
        }
        // Waits for each location lookup, so no request goes to a stored place the device has
        // left, and only asks WeatherKit when its throttle allows.
        .task(id: WeatherStore.Trigger(locatedCount: store.locatedCount, reloadCount: store.reloadCount)) {
            if store.locatedCount > 0, scenePhase != .background {
                await weather.load(at: store.place, now: now(from: .now), calendar: store.calendar)
            }
        }
        #if DEBUG
        .debugDrawer(store: store, settings: debug)
        #endif
    }

    /// The time the app shows as now, which the debug drawer can override.
    private func now(from date: Date) -> Date {
        #if DEBUG
        debug?.nowOverride ?? date
        #else
        date
        #endif
    }
}

#Preview {
    ContentView(provider: MockSolarDayProvider(), placeProvider: MockPlaceProvider(), weatherProvider: MockWeatherProvider())
}

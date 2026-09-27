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
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    init(provider: any SolarDayProvider, placeProvider: any PlaceProvider, selectedDate: Date = .now) {
        _store = State(initialValue: SolarDayStore(provider: provider, placeProvider: placeProvider, selectedDate: selectedDate))
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                DayScreen(
                    state: store.state,
                    now: now(from: context.date),
                    selectedDate: $store.selectedDate,
                    place: store.place,
                    onRetry: store.reload
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
    ContentView(provider: MockSolarDayProvider(), placeProvider: MockPlaceProvider())
}

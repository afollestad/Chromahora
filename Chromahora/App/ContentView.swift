//
//  ContentView.swift
//  Chromahora
//
//  Created by Aidan Follestad on 9/26/26.
//

import SwiftUI

struct ContentView: View {
    /// One store per window, so each window can show its own day.
    @State private var store: SolarDayStore
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    init(provider: any SolarDayProvider, selectedDate: Date = .now) {
        _store = State(initialValue: SolarDayStore(provider: provider, selectedDate: selectedDate))
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                DayScreen(state: store.state, now: now(from: context.date), selectedDate: $store.selectedDate, onRetry: store.reload)
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
    ContentView(provider: MockSolarDayProvider())
}

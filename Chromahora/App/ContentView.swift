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
            switch store.state {
            case .loaded(let day), .loading(let day?):
                TimelineView(.everyMinute) { context in
                    DayTimeline(day: day, now: now(from: context.date), selectedDate: $store.selectedDate)
                }
            case .loading(nil):
                placeholder {
                    ProgressView()
                        .accessibilityLabel("Loading sun times")
                }
            case .failed:
                placeholder {
                    ContentUnavailableView {
                        Label("Couldn't Load This Day", systemImage: "sun.horizon")
                    } description: {
                        Text("Sun times for \(store.selectedDate, format: .dateTime.weekday(.wide).month(.wide).day()) aren't available.")
                    } actions: {
                        Button("Try Again") {
                            store.reload()
                        }
                        .buttonStyle(.glass)
                    }
                }
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

    /// Sets placeholders on the night sky that surrounds the timeline, so moving
    /// between them and a loaded day doesn't flash the system background.
    private func placeholder<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DayPhase.night.color)
            .environment(\.colorScheme, .dark)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    ContentView(provider: MockSolarDayProvider())
}

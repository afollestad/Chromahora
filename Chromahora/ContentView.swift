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

    init(provider: any SolarDayProvider) {
        _store = State(initialValue: SolarDayStore(provider: provider))
    }

    var body: some View {
        NavigationStack {
            switch store.state {
            case .loaded(let day), .loading(let day?):
                TimelineView(.everyMinute) { context in
                    DayTimeline(day: day, now: context.date, selectedDate: $store.selectedDate)
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
                            Task { await store.loadSelectedDay() }
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        }
        .task(id: store.selectedDayStart) {
            await store.loadSelectedDay()
        }
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

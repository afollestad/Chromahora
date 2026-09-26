//
//  ContentView.swift
//  Chromahora
//
//  Created by Aidan Follestad on 9/26/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedDate = Date.now

    /// Placeholder data for the selected day. Replace with real solar data once available.
    private var day: SolarDay {
        SolarDay.mock(for: selectedDate)
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                DayTimeline(day: day, now: context.date, selectedDate: $selectedDate)
            }
        }
    }
}

#Preview {
    ContentView()
}

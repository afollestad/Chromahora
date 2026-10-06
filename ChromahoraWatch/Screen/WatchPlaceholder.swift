//
//  WatchPlaceholder.swift
//  ChromahoraWatch
//

import SwiftUI

/// Stands in for the day's cards while no day is on screen: the dawn glow while loading, or the
/// reason a day couldn't load, on the night sky.
struct WatchPlaceholder: View {
    let state: SolarDayStore.LoadState
    let date: Date
    /// The store's zone, which reads `date`.
    let timeZone: TimeZone
    let onRetry: () -> Void

    /// The phone reveals its day from under the glow once it's been seen; the watch just shows it.
    @State private var isGlowShown = false

    var body: some View {
        ZStack {
            DayPhase.night.color
                .ignoresSafeArea()

            if case .failed(let error) = state {
                ScrollView {
                    failure(error)
                }
            } else {
                LoadingSky(isShown: $isGlowShown)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func failure(_ error: any Error) -> some View {
        if case PlaceError.unavailable(let zoneIdentifier) = error {
            // Retrying can't help, since the zone has no city to fall back to, and the watch has
            // no link into Settings.
            ContentUnavailableView {
                Label("Location Needed", systemImage: "location.slash")
            } description: {
                Text("""
                    Chromahora can't tell where you are from the \(zoneIdentifier) time zone. Turn \
                    on Location Services for it in Settings, under Privacy & Security.
                    """)
            }
        } else {
            ContentUnavailableView {
                Label("Couldn't Load This Day", systemImage: "sun.horizon")
            } description: {
                if case SunriseSunsetError.rateLimited = error {
                    Text("Sun times are busy right now. Try again in a moment.")
                } else {
                    Text("Sun times for \(date.dayTitle(in: timeZone)) aren't available.")
                }
            } actions: {
                Button("Try Again", action: onRetry)
            }
        }
    }
}

#Preview("Loading") {
    WatchPlaceholder(state: .loading(nil), date: .now, timeZone: .current) {}
}

#Preview("Failed") {
    WatchPlaceholder(state: .failed(CancellationError()), date: .now, timeZone: .current) {}
}

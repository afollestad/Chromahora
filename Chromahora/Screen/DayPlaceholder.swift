//
//  DayPlaceholder.swift
//  Chromahora
//

import SwiftUI

/// Stands in for the timeline while no day is on screen: the dawn glow while loading,
/// or the reason a day couldn't load. Both sit on the night sky that surrounds the
/// timeline, so moving between them and a day doesn't flash the system background.
struct DayPlaceholder: View {
    let state: SolarDayStore.LoadState
    let date: Date
    @Binding var isGlowShown: Bool
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            DayPhase.night.color
                .ignoresSafeArea()

            if case .failed = state {
                ContentUnavailableView {
                    Label("Couldn't Load This Day", systemImage: "sun.horizon")
                } description: {
                    Text("Sun times for \(date, format: .dateTime.weekday(.wide).month(.wide).day()) aren't available.")
                } actions: {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.glass)
                }
            } else {
                LoadingSky(isShown: $isGlowShown)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

#Preview("Loading") {
    @Previewable @State var isGlowShown = false
    DayPlaceholder(state: .loading(nil), date: .now, isGlowShown: $isGlowShown) {}
}

#Preview("Failed") {
    @Previewable @State var isGlowShown = false
    DayPlaceholder(state: .failed(CancellationError()), date: .now, isGlowShown: $isGlowShown) {}
}

//
//  DayScreen.swift
//  Chromahora
//

import SwiftUI

/// The whole screen for one load state at a given time: the timeline once a day is on
/// hand, a placeholder over it until then, and the one toolbar both share.
///
/// It holds no data of its own, so snapshots can render any state at a fixed `now`.
struct DayScreen: View {
    let state: SolarDayStore.LoadState
    let now: Date
    @Binding var selectedDate: Date
    let onRetry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var skyBehindTitle = DayPhase.night.color
    @State private var isBarDark = true
    @State private var titleMidY: CGFloat = 0
    @State private var focusRequests = 0
    @State private var isGlowShown = false

    var body: some View {
        ZStack {
            // Inserted under the placeholder, which reveals it by leaving, so nothing
            // masks the timeline or disturbs its first scroll.
            if let day = state.day {
                DayTimeline(day: day, now: now, skyBehindTitle: $skyBehindTitle, titleMidY: titleMidY, focusRequests: focusRequests)
                    .transition(.identity)
            }
            if state.day == nil {
                DayPlaceholder(state: state, date: selectedDate, isGlowShown: $isGlowShown, onRetry: onRetry)
                    // Full screen, so the reveal's mask covers the areas under the bar and home indicator too.
                    .ignoresSafeArea()
                    .zIndex(1)
                    .transition(placeholderTransition)
                    .onAppear {
                        skyBehindTitle = DayPhase.night.color
                    }
            }
        }
        .animation(placeholderAnimation, value: state.day == nil)
        .onChange(of: skyBehindTitle) {
            isBarDark = DayTimeline.prefersDarkBar(over: skyBehindTitle, wasDark: isBarDark)
        }
        .toolbarColorScheme(isBarDark ? .dark : .light, for: .navigationBar)
        .navigationTitle("Chromahora")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            DayToolbar(
                isLoading: isLoadingAnotherDay,
                skyColor: $skyBehindTitle,
                selectedDate: $selectedDate,
                now: now,
                onTitleMidY: { titleMidY = $0 },
                onToday: { focusRequests += 1 }
            )
        }
    }

    /// Whether a day is on screen while another loads, which the title marks.
    private var isLoadingAnotherDay: Bool {
        if case .loading(.some) = state { true } else { false }
    }

    /// A placeholder arrives at once and leaves by revealing the sky. SwiftUI keeps the
    /// transition a view was inserted with, so whether the reveal plays is up to the animation.
    private var placeholderTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .identity, removal: AnyTransition(SunriseReveal()))
    }

    /// The reveal plays only when the glow was seen, so a quick load from the cache just shows the day.
    private var placeholderAnimation: Animation? {
        if reduceMotion {
            return .easeInOut(duration: 0.3)
        }
        return isGlowShown ? .smooth(duration: 1) : nil
    }
}

#Preview("Loaded") {
    @Previewable @State var selectedDate = Date.now
    NavigationStack {
        DayScreen(state: .loaded(.mock(for: selectedDate)), now: .now, selectedDate: $selectedDate) {}
    }
}

#Preview("Loading another day") {
    @Previewable @State var selectedDate = Date.now
    NavigationStack {
        DayScreen(state: .loading(.mock(for: selectedDate)), now: .now, selectedDate: $selectedDate) {}
    }
}

#Preview("Loading") {
    @Previewable @State var selectedDate = Date.now
    NavigationStack {
        DayScreen(state: .loading(nil), now: .now, selectedDate: $selectedDate) {}
    }
}

#Preview("Failed") {
    @Previewable @State var selectedDate = Date.now
    NavigationStack {
        DayScreen(state: .failed(CancellationError()), now: .now, selectedDate: $selectedDate) {}
    }
}

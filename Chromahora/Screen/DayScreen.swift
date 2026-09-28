//
//  DayScreen.swift
//  Chromahora
//

import SwiftUI

/// The whole screen for one load state at a given time: the timeline once a day is on
/// hand, a placeholder over it until then, and the one toolbar both share. A wide window
/// floats the day panel over the sky's trailing side, in place of the calendar button.
///
/// It holds no data of its own, so snapshots can render any state at a fixed `now`.
struct DayScreen: View {
    let state: SolarDayStore.LoadState
    let now: Date
    @Binding var selectedDate: Date
    /// Where the day is for, which the day picker names.
    var place: Place?
    /// The forecast's spells, which the timeline marks on the day they fall on.
    var weather: [WeatherSpell] = []
    let onRetry: () -> Void
    /// Selects the day a pull through the timeline's end leads to, and answers whether it's
    /// on hand to page to at once.
    var onPage: (Date) -> Bool = { _ in false }

    /// The iPhone 17e's width, the narrowest the timeline's labels fit at their size cap.
    private static let minimumTimelineWidth: CGFloat = 390

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var skyBehindTitle = DayPhase.night.color
    @State private var isBarDark = true
    @State private var titleMidY: CGFloat = 0
    @State private var focus = DayTimeline.Focus()
    @State private var isGlowShown = false
    /// Starts unbounded, so a regular window shows the panel from its first frame.
    @State private var width = CGFloat.infinity

    var body: some View {
        // The screen, which the layers ride over rather than size. The loading glow is wider
        // than the screen, and the panel aligns to the screen's edge, not the glow's.
        Color.clear
            .overlay {
                layers
            }
            .overlay(alignment: .trailing) {
                if showsPanel {
                    DayPanel(
                        day: state.day,
                        now: now,
                        selectedDate: $selectedDate,
                        place: place,
                        weather: weather,
                        onToday: { focus.request() },
                        onFocus: { focus.request($0) }
                    )
                    .padding([.top, .bottom, .trailing], DayPanel.margin)
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                self.width = width
            }
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
                    place: place,
                    showsDayPicker: !showsPanel,
                    onTitleMidY: { titleMidY = $0 },
                    onToday: { focus.request() }
                )
            }
    }

    /// The timeline once a day is on hand, and a placeholder over it until then.
    private var layers: some View {
        ZStack {
            // Inserted under the placeholder, which reveals it by leaving, so nothing
            // masks the timeline or disturbs its first scroll.
            if let day = state.day {
                DayPager(
                    day: day,
                    now: now,
                    weather: weather,
                    skyBehindTitle: $skyBehindTitle,
                    titleMidY: titleMidY,
                    focus: focus,
                    panelInset: panelInset,
                    onPage: onPage
                )
                    .transition(.identity)
            }
            if state.day == nil {
                DayPlaceholder(state: state, date: selectedDate, isGlowShown: $isGlowShown, onRetry: onRetry)
                    // Inside the full screen below, so the message centers beside the panel while
                    // the night and glow still run under it.
                    .safeAreaPadding(.trailing, panelInset)
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
    }

    /// Whether the window is wide enough for the day panel beside a timeline as wide as the
    /// narrowest iPhone's, the width its labels are laid out for.
    private var showsPanel: Bool {
        horizontalSizeClass == .regular && width >= Self.minimumTimelineWidth + DayPanel.footprint
    }

    /// The panel's footprint, which the timeline and placeholder leave clear. Always applied,
    /// as zero without it, since a branch around them would rebuild them and lose the scroll and glow.
    private var panelInset: CGFloat {
        showsPanel ? DayPanel.footprint : 0
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
        DayScreen(
            state: .loaded(.mock(for: selectedDate)),
            now: .now,
            selectedDate: $selectedDate,
            weather: WeatherSpell.mock(for: selectedDate)
        ) {}
    }
}

#Preview("Wide", traits: .fixedLayout(width: 744, height: 1133)) {
    @Previewable @State var selectedDate = Date.now
    NavigationStack {
        DayScreen(
            state: .loaded(.mock(for: selectedDate)),
            now: .now,
            selectedDate: $selectedDate,
            place: MockPlaceProvider.sanFrancisco,
            weather: WeatherSpell.mock(for: selectedDate)
        ) {}
    }
    .environment(\.horizontalSizeClass, .regular)
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

//
//  DayPanel.swift
//  Chromahora
//

import SwiftUI

/// The day at a glance beside the timeline when the window has room, as on iPad or an opened
/// foldable: the calendar, then the day's details. It floats on glass over the sky, and tapping
/// a row scrolls the timeline to it.
struct DayPanel: View {
    /// `DayPicker`'s width, so the calendar sits in the panel as it does in its popover.
    static let width: CGFloat = 320
    /// The debug drawer's gap from the screen's edge, kept on every side the panel floats clear of.
    static let margin: CGFloat = 8
    /// How much of the trailing edge the panel takes from the timeline.
    static let footprint = width + margin

    let day: SolarDay?
    let now: Date
    @Binding var selectedDate: Date
    var place: Place?
    /// The forecast's spells, of any day. Those reaching this one are listed.
    var weather: [WeatherSpell] = []
    /// The forecast's hours, of any day, which the day's light and sky readings come from.
    var hours: [SkyHour] = []
    let onToday: () -> Void
    /// Scrolls the timeline to a time on the day.
    let onFocus: (Date) -> Void

    private let shape = RoundedRectangle(cornerRadius: 28)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DayPicker(selection: $selectedDate, place: place) {
                    // `now`, not `.now`, so Today follows the debug drawer's clock.
                    selectedDate = now
                    onToday()
                }
                if let day {
                    DayDetails(day: day, now: now, weather: weather, hours: hours, onFocus: onFocus)
                }
            }
            .padding(.bottom)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .clipShape(shape)
        // Clear glass, with primary text, like the popovers: the sky shows through, and
        // gray or tinted text would wash out over daylight.
        .glassEffect(.regular, in: shape)
        // `DayPicker`'s cap, which the rest of the panel's text follows at the same width.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Day details")
    }
}

#Preview("Loaded") {
    @Previewable @State var selectedDate = Date.now
    let day = SolarDay.mock(for: selectedDate)
    ZStack(alignment: .trailing) {
        SkyGradient(day: day)
            .ignoresSafeArea()
        DayPanel(
            day: day,
            now: .now,
            selectedDate: $selectedDate,
            place: MockPlaceProvider.sanFrancisco,
            weather: WeatherSpell.mock(for: selectedDate),
            hours: SkyHour.mock(for: selectedDate),
            onToday: {},
            onFocus: { _ in }
        )
        .padding(DayPanel.margin)
    }
}

#Preview("Failed") {
    @Previewable @State var selectedDate = Date.now
    ZStack(alignment: .trailing) {
        DayPhase.night.color
            .ignoresSafeArea()
        DayPanel(
            day: nil,
            now: .now,
            selectedDate: $selectedDate,
            place: TimeZonePlaceProvider().lastKnownPlace(in: .current),
            onToday: {},
            onFocus: { _ in }
        )
        .padding(DayPanel.margin)
    }
}

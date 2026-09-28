//
//  DayDetailsPage.swift
//  Chromahora
//

import SwiftUI

/// The day's details beside the timeline when there's no room for the day panel, as on iPhone:
/// the panel's glass card without the calendar, which the toolbar's button holds. The page
/// itself is clear, over the copy of the sky `DayPager` keeps behind it.
struct DayDetailsPage: View {
    let day: SolarDay
    let now: Date
    var weather: [WeatherSpell] = []
    var hours: [SkyHour] = []
    /// The screen's safe area, sources bar included, which `DayPager` measures, since the pages
    /// draw edge to edge.
    var safeAreaInsets = EdgeInsets()
    /// Pages back to the timeline and scrolls it to a time on the day.
    let onFocus: (Date) -> Void

    private let shape = RoundedRectangle(cornerRadius: 28)

    var body: some View {
        ScrollView {
            DayDetails(day: day, now: now, weather: weather, hours: hours, showsWeatherCredit: false, onFocus: onFocus)
                .padding(.vertical)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
        // Clear glass with primary text, like the day panel.
        .glassEffect(.regular, in: shape)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(DayPanel.margin)
        .padding(safeAreaInsets)
        // Keeps the glass's shadow off the timeline beside it.
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Day details")
    }
}

#Preview {
    let day = SolarDay.mock()
    ZStack {
        SkyGradient(day: day)
            .ignoresSafeArea()
        DayDetailsPage(
            day: day,
            now: .now,
            weather: WeatherSpell.mock(),
            hours: SkyHour.mock(),
            safeAreaInsets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)
        ) { _ in }
            .ignoresSafeArea()
    }
}

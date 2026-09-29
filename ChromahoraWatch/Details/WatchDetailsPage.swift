//
//  WatchDetailsPage.swift
//  ChromahoraWatch
//

import SwiftUI

/// The day's details, a swipe from the timeline as on the phone: its phases, the sun, the moon,
/// and the weather, then the sources at the foot like the timeline's. Tapping a row with a time
/// pages back to the timeline and scrolls it there.
struct WatchDetailsPage: View {
    let day: SolarDay
    let now: Date
    /// The forecast's spells, of any day. Those reaching this one are listed.
    let weather: [WeatherSpell]
    /// The forecast's hours, of any day, which the UV and sky rows read.
    let hours: [SkyHour]
    /// Pages back to the timeline and scrolls it to a time on the day.
    let onFocus: (Date) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // The sources button below carries Apple Weather's mark, as on the phone's page.
                DayDetails(day: day, now: now, weather: weather, hours: hours, showsWeatherCredit: false, onFocus: onFocus)
                WatchSourcesButton(showsWeather: showsWeather)
                    .padding(.horizontal, 8)
            }
        }
        // As on the phone's page. Past it, time ranges truncate on the narrowest watch.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Day details")
    }

    /// Whether any spell or hour reaches the day, which is when its details show weather.
    private var showsWeather: Bool {
        weather.contains { $0.span(within: day) != nil } || hours.contains { $0.falls(on: day) }
    }
}

#Preview {
    let now = Date.now
    WatchDetailsPage(day: .mock(for: now), now: now, weather: WeatherSpell.mock(), hours: SkyHour.mock()) { _ in }
}

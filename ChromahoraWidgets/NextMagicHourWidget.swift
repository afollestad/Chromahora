//
//  NextMagicHourWidget.swift
//  ChromahoraWidgets
//

import SwiftUI
import WidgetKit

/// The next golden or blue hour, in a small widget.
struct NextMagicHourWidget: Widget {
    /// Names the widget on every Home Screen that shows it, so it never changes.
    static let kind = "NextMagicHour"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SkyTimelineProvider(showsWeather: true)) { entry in
            NextMagicHourView(entry: entry)
                .skyWidgetBackground(for: entry)
        }
        .configurationDisplayName("Next Magic Hour")
        .description("When the next golden or blue hour starts, and the sky it starts under.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    NextMagicHourWidget()
} timeline: {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    for hour in [16, 18, 22] {
        let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
        SkyEntry(date: now, state: .loaded(.preview(at: now)))
    }
    SkyEntry(date: .now, state: .unavailable)
}

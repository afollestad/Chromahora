//
//  SunTimesWidget.swift
//  ChromahoraWidgets
//

import SwiftUI
import WidgetKit

/// The next sunrise or sunset, in a small widget.
struct SunTimesWidget: Widget {
    /// Names the widget on every Home Screen that shows it, so it never changes.
    static let kind = "SunTimes"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SkyTimelineProvider(showsWeather: false)) { entry in
            SunTimesView(entry: entry)
                .skyWidgetBackground(for: entry)
        }
        .configurationDisplayName("Sun Times")
        .description("The next sunrise or sunset, and the golden and blue hours around it.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    SunTimesWidget()
} timeline: {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    for hour in [5, 16, 22] {
        let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
        SkyEntry(date: now, state: .loaded(.preview(at: now)))
    }
    SkyEntry(date: .now, state: .unavailable)
}

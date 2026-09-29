//
//  DayStripWidget.swift
//  ChromahoraWidgets
//

import SwiftUI
import WidgetKit

/// The whole day's sky, in a medium widget.
struct DayStripWidget: Widget {
    /// Names the widget on every Home Screen that shows it, so it never changes.
    static let kind = "DayStrip"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SkyTimelineProvider(showsWeather: true)) { entry in
            DayStripView(entry: entry)
                .skyWidgetBackground(for: entry)
        }
        .configurationDisplayName("Day Strip")
        .description("The day's sky from midnight to midnight, and the next golden and blue hours.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    DayStripWidget()
} timeline: {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    for hour in [5, 16, 22] {
        let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
        SkyEntry(date: now, state: .loaded(.preview(at: now)))
    }
    SkyEntry(date: .now, state: .unavailable)
}

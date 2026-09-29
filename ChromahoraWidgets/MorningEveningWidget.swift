//
//  MorningEveningWidget.swift
//  ChromahoraWidgets
//

import SwiftUI
import WidgetKit

/// Both ends of the day, in a medium widget.
struct MorningEveningWidget: Widget {
    /// Names the widget on every Home Screen that shows it, so it never changes.
    static let kind = "MorningEvening"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SkyTimelineProvider(showsWeather: false)) { entry in
            MorningEveningView(entry: entry)
                .skyWidgetBackground(for: entry)
        }
        .configurationDisplayName("Morning & Evening")
        .description("The golden and blue hours, sunrise and sunset at both ends of the day.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    MorningEveningWidget()
} timeline: {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    for hour in [5, 16, 22] {
        let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
        SkyEntry(date: now, state: .loaded(.preview(at: now)))
    }
    SkyEntry(date: .now, state: .unavailable)
}

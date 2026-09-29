//
//  MoonDarkSkyWidget.swift
//  ChromahoraWidgets
//

import SwiftUI
import WidgetKit

/// The moon and tonight's dark sky, in a small widget.
struct MoonDarkSkyWidget: Widget {
    /// Names the widget on every Home Screen that shows it, so it never changes.
    static let kind = "MoonDarkSky"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SkyTimelineProvider(showsWeather: false)) { entry in
            MoonView(entry: entry)
                .skyWidgetBackground(for: entry)
        }
        .configurationDisplayName("Moon & Dark Sky")
        .description("The moon's phase, and when tonight's sky is darkest.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    MoonDarkSkyWidget()
} timeline: {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    for hour in [5, 16, 22] {
        let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
        SkyEntry(date: now, state: .loaded(.preview(at: now)))
    }
    SkyEntry(date: .now, state: .unavailable)
}

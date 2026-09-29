//
//  NextPhasesWidget.swift
//  ChromahoraWidgets
//

import SwiftUI
import WidgetKit

/// The next golden or blue hour and the changes after it, in a medium widget.
struct NextPhasesWidget: Widget {
    /// Names the widget on every Home Screen that shows it, so it never changes.
    static let kind = "NextPhases"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SkyTimelineProvider(showsWeather: true)) { entry in
            NextPhasesView(entry: entry)
                .skyWidgetBackground(for: entry)
        }
        .configurationDisplayName("Next Phases")
        .description("The next golden or blue hour, and each change of light after it.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    NextPhasesWidget()
} timeline: {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    for hour in [5, 16, 22] {
        let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
        SkyEntry(date: now, state: .loaded(.preview(at: now)))
    }
    SkyEntry(date: .now, state: .unavailable)
}

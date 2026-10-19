//
//  OutlookComplication.swift
//  ChromahoraWatchWidgets
//

import SwiftUI
import WidgetKit

/// The outlook for the golden and blue hours under way or next, on the watch face.
struct OutlookComplication: Widget {
    /// Names the complication on every face that shows it, so it never changes.
    static let kind = "OutlookComplication"

    var body: some WidgetConfiguration {
        // Weather from the forecast the watch app last stored, which `SkyLoader.live` reads
        // without a request of its own.
        StaticConfiguration(kind: Self.kind, provider: SkyTimelineProvider(showsWeather: true)) { entry in
            OutlookComplicationView(entry: entry)
                .skyWidgetBackground(for: entry)
        }
        .configurationDisplayName("Outlook")
        .description("How promising the next golden and blue hours look, from the watch app's forecast.")
        // A rectangle alone, as `OutlookComplicationView` says why.
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    OutlookComplication()
} timeline: {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    for hour in [16, 18, 22] {
        let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
        SkyEntry(date: now, state: .loaded(.preview(at: now)))
    }
    SkyEntry(date: .now, state: .unavailable)
}

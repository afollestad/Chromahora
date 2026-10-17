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
            OutlookComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Outlook")
        .description("How promising the next golden and blue hours look, from the watch app's forecast.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

/// Reads the family the face placed the complication in, which only a view inside WidgetKit can,
/// for the view that lays it out.
private struct OutlookComplicationEntryView: View {
    let entry: SkyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        OutlookComplicationView(entry: entry, layout: family == .accessoryCircular ? .circular : .rectangular)
            .skyWidgetBackground(for: entry)
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

//
//  PhaseComplication.swift
//  ChromahoraWatchWidgets
//

import SwiftUI
import WidgetKit

/// The golden or blue hour under way or next, on the watch face.
struct PhaseComplication: Widget {
    /// Names the complication on every face that shows it, so it never changes.
    static let kind = "PhaseComplication"

    var body: some WidgetConfiguration {
        // No weather, which would need Apple Weather's credit beside it.
        StaticConfiguration(kind: Self.kind, provider: SkyTimelineProvider(showsWeather: false)) { entry in
            PhaseComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Next Magic Hour")
        .description("When the next golden or blue hour starts, or while one's under way, when it ends.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

/// Reads the family the face placed the complication in, which only a view inside WidgetKit can,
/// for the view that lays it out.
private struct PhaseComplicationEntryView: View {
    let entry: SkyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        PhaseComplicationView(entry: entry, layout: layout)
            .skyWidgetBackground(for: entry)
    }

    private var layout: PhaseComplicationView.Layout {
        switch family {
        case .accessoryCircular: .circular
        case .accessoryCorner: .corner
        case .accessoryInline: .inline
        default: .rectangular
        }
    }
}

#Preview(as: .accessoryRectangular) {
    PhaseComplication()
} timeline: {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    for hour in [16, 18, 22] {
        let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
        SkyEntry(date: now, state: .loaded(.preview(at: now)))
    }
    SkyEntry(date: .now, state: .unavailable)
}

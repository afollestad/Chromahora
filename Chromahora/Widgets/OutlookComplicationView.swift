//
//  OutlookComplicationView.swift
//  Chromahora
//

import SwiftUI
import WidgetKit

/// The outlook for the golden and blue hours under way or next, as a rectangular complication
/// on the watch face, from the forecast the watch app last stored: the end and when it starts,
/// over its rating and cloud cover, over Apple Weather's mark.
///
/// It offers no circle, which has room for little more than the rating, and "Fair" alone reads
/// as the weather's word for a clear sky rather than the light's promise for a photo.
struct OutlookComplicationView: View {
    let entry: SkyEntry

    var body: some View {
        Group {
            switch entry.state {
            case .loaded(let content):
                loaded(content)
            case .unavailable:
                unavailable
            }
        }
        // The largest a complication's fixed size holds, as for the widgets.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    // MARK: Layouts

    @ViewBuilder
    private func loaded(_ content: SkyContent) -> some View {
        let magicHour = content.run.magicHour(at: entry.date)
        if let session = magicHour.flatMap(content.session(for:)) {
            rated(session, in: content.run)
        } else {
            unrated(magicHour, in: content.run)
        }
    }

    /// The end and when it starts, over its rating and cloud cover, over Apple Weather's mark.
    private func rated(_ session: OutlookSession, in run: DayRun) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: session.kind.symbolName)
                    .foregroundStyle(DayPhase.goldenHour.faceColor)
                    .accessibilityHidden(true)
                Text("\(session.kind.title) · \(startText(session.start, in: run))")
                    .font(.headline)
                    .widgetAccentable()
            }
            OutlookLabel(rating: session.rating, cloudCover: session.cloudCover)
            AppleWeatherCredit.mark
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The golden or blue hour next, and that it has no outlook yet, or through a polar night or a
    /// midnight sun, that none comes. No mark, since no weather shows.
    private func unrated(_ magicHour: DaySegment?, in run: DayRun) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "sun.horizon")
                    .foregroundStyle(DayPhase.goldenHour.faceColor)
                    .accessibilityHidden(true)
                Text(magicHour.map { "\($0.phase.title) · \(startText($0.interval.start, in: run))" } ?? "Outlook")
                    .font(.headline)
                    .widgetAccentable()
            }
            if magicHour != nil {
                Text("No outlook yet")
            } else if run.reachesTomorrow {
                Text("No golden or blue hour")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// When something starts, or "Now" once it's under way.
    private func startText(_ start: Date, in run: DayRun) -> String {
        start <= entry.date ? "Now" : run.timeText(start)
    }

    /// The widgets' note in one row, as their larger glyph would crowd out its words.
    private var unavailable: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "sun.horizon")
                .accessibilityHidden(true)
            Text("Sun times will show once they load.")
                .font(.footnote)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let now = Date.now
    OutlookComplicationView(entry: SkyEntry(date: now, state: .loaded(.preview(at: now))))
        .frame(width: 180, height: 60)
        .padding()
        .background(.black)
        .environment(\.colorScheme, .dark)
}

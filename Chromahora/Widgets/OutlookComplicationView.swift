//
//  OutlookComplicationView.swift
//  Chromahora
//

import SwiftUI
import WidgetKit

/// The outlook for the golden and blue hours under way or next, as a complication on the watch
/// face, from the forecast the watch app last stored. The circle names the end over its rating,
/// large, and its cloud cover; the rectangle adds when it starts.
///
/// Only the rectangle has room for Apple Weather's mark. The circle carries none, leaving the
/// credit to the watch app a tap away, as `PhaseComplicationView` does for sunrise-sunset.org.
struct OutlookComplicationView: View {
    /// The shapes a watch face gives this complication.
    enum Layout: CaseIterable {
        case circular
        case rectangular
    }

    let entry: SkyEntry
    let layout: Layout

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
        let session = magicHour.flatMap(content.session(for:))
        switch layout {
        case .circular:
            circular(session)
        case .rectangular:
            if let session {
                rectangular(session, in: content.run)
            } else {
                rectangular(without: magicHour, in: content.run)
            }
        }
    }

    /// The end's name over its rating, large, as the phase complication shows a time, and its
    /// cloud cover, all in words, which a tinted face's one color can't blur together. Without an
    /// outlook, as before the watch app has a forecast or past the one it has, a dash.
    private func circular(_ session: OutlookSession?) -> some View {
        ComplicationDisc { scale in
            // Overlaps the rows' leading, which would push the name and cloud cover into the curve.
            VStack(spacing: scale.width * -0.03) {
                Text(session?.kind.title ?? "Outlook")
                    .font(.system(size: scale.label, weight: .semibold))
                    .foregroundStyle(DayPhase.goldenHour.faceColor)
                    .widgetAccentable()
                Text(session?.rating.title ?? "—")
                    .font(.system(size: scale.reading, weight: .semibold).width(.condensed))
                    // Reaches into the curve's inset where the disc is widest, since "Excellent"
                    // needs the room even condensed.
                    .padding(.horizontal, scale.width * -0.08)
                if let session {
                    OutlookLabel.text(rating: nil, cloudCover: session.cloudCover)
                        .font(.system(size: scale.label, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText(session))
    }

    /// What VoiceOver reads for the circle, as in "Evening, Great outlook, 20% cloud cover".
    private func spokenText(_ session: OutlookSession?) -> String {
        guard let session else {
            return "No outlook yet"
        }
        return "\(session.kind.title), \(OutlookLabel.spoken(rating: session.rating, cloudCover: session.cloudCover))"
    }

    /// The end and when it starts, over its rating and cloud cover, over Apple Weather's mark.
    private func rectangular(_ session: OutlookSession, in run: DayRun) -> some View {
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
    private func rectangular(without magicHour: DaySegment?, in run: DayRun) -> some View {
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

    @ViewBuilder
    private var unavailable: some View {
        switch layout {
        case .circular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "sun.horizon")
                    .accessibilityLabel("Sun times will show once they load")
            }
        case .rectangular:
            // The widgets' note in one row, as their larger glyph would crowd out its words.
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
}

#Preview {
    let now = Date.now
    let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
    VStack(spacing: 16) {
        ForEach(OutlookComplicationView.Layout.allCases, id: \.self) { layout in
            OutlookComplicationView(entry: entry, layout: layout)
                .frame(width: layout == .rectangular ? 180 : 50, height: layout == .rectangular ? 60 : 50)
        }
    }
    .padding()
    .background(.black)
    .environment(\.colorScheme, .dark)
}

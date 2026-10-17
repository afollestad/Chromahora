//
//  OutlookComplicationView.swift
//  Chromahora
//

import SwiftUI
import WidgetKit

/// The outlook for the golden and blue hours under way or next, as a complication on the watch
/// face, from the forecast the watch app last stored. The circle fills a ring of five arcs to
/// the rating around its end's sun; the rectangle names the end, when it starts, the rating and
/// its cloud cover.
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

    /// The gap between the ring's arcs, as a share of the whole ring, wide enough to count them
    /// apart at a glance on the smallest disc.
    private static let arcGap = 0.035
    /// The ring's stroke, as a share of the disc's width.
    private static let ringShare = 0.09
    /// The end's sun in the ring's middle, as a share of the disc's width.
    private static let symbolShare = 0.36
    /// Unfilled arcs, faint enough to tell from filled ones on a tinted face, which draws both in one color.
    private static let unfilledOpacity = 0.3

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

    /// A ring of five arcs, filled to the rating, around the end's sun. Without an outlook, as
    /// before the watch app has a forecast or past the one it has, an empty ring around the horizon.
    private func circular(_ session: OutlookSession?) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            GeometryReader { proxy in
                let width = min(proxy.size.width, proxy.size.height)
                let filled = session.map { $0.rating.rawValue + 1 } ?? 0
                ZStack {
                    ForEach(0..<OutlookRating.allCases.count, id: \.self) { index in
                        arc(index, isFilled: index < filled, lineWidth: width * Self.ringShare)
                    }
                    Image(systemName: session?.kind.symbolName ?? "sun.horizon")
                        .font(.system(size: width * Self.symbolShare))
                        .foregroundStyle(DayPhase.goldenHour.faceColor)
                        .widgetAccentable()
                }
                .padding(width * Self.ringShare)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.map { "\($0.kind.title) outlook, \($0.rating.title)" } ?? "No outlook yet")
    }

    /// One of the ring's five arcs, the first at the top and the rest clockwise, with a gap either side.
    @ViewBuilder
    private func arc(_ index: Int, isFilled: Bool, lineWidth: CGFloat) -> some View {
        let count = Double(OutlookRating.allCases.count)
        let shape = Circle()
            .trim(from: Double(index) / count + Self.arcGap / 2, to: Double(index + 1) / count - Self.arcGap / 2)
            .rotation(.degrees(-90))
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        if isFilled {
            shape
                .foregroundStyle(DayPhase.goldenHour.faceColor)
                .widgetAccentable()
        } else {
            shape
                .foregroundStyle(.primary.opacity(Self.unfilledOpacity))
        }
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

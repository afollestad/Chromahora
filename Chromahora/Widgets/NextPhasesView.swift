//
//  NextPhasesView.swift
//  Chromahora
//

import SwiftUI

/// The medium widget pairing the next golden or blue hour, as the small widget shows it, with
/// what comes after it: each change of phase, with the golden and blue hours' outlooks, and the
/// sunrise or sunset between them.
struct NextPhasesView: View {
    let entry: SkyEntry

    /// A change the list shows, in time order.
    private enum Change: Identifiable {
        case phase(DaySegment)
        case sun(SolarEvent)

        var date: Date {
            switch self {
            case .phase(let segment): segment.interval.start
            case .sun(let event): event.date
            }
        }

        /// Apart for a phase and a sunrise that fall on one minute.
        var id: String {
            switch self {
            case .phase: "phase \(date)"
            case .sun: "sun \(date)"
            }
        }
    }

    /// How many changes the list holds, which fills the widget's height at the default text size.
    private static let changes = 5

    /// The summary's share of the width beside the list: about the small widget's 132 of the
    /// medium's 316 points, so it lays out as the small widget does, and the list keeps room for
    /// its golden and blue hours' ratings.
    private static let summaryShare = 0.45
    private static let columnSpacing: CGFloat = 12

    var body: some View {
        WidgetContent(entry: entry) { content in
            let changes = changes(in: content.run)
            let ratings = changes.map { rating(of: $0, in: content) }
            GeometryReader { proxy in
                HStack(alignment: .top, spacing: Self.columnSpacing) {
                    VStack(alignment: .leading, spacing: 0) {
                        MagicHourSummary(content: content, now: entry.date)
                        Spacer(minLength: 4)
                        WidgetCredit(
                            showsWeather: MagicHourSummary.showsWeather(in: content, at: entry.date) || ratings.contains { $0 != nil },
                            linksSources: true
                        )
                    }
                    .frame(width: (proxy.size.width - Self.columnSpacing) * Self.summaryShare, alignment: .leading)
                    list(changes, ratings: ratings, in: content.run)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// The changes after the golden or blue hour the summary beside the list leads with, which it would repeat.
    private func changes(in run: DayRun) -> [Change] {
        let after = max(entry.date, run.magicHour(at: entry.date)?.interval.start ?? entry.date)
        let phases = run.segments.filter { $0.interval.start > after }.map(Change.phase)
        let sun = run.days.flatMap(\.events).filter { $0.date > after }.map(Change.sun)
        return Array((phases + sun).sorted { $0.date < $1.date }.prefix(Self.changes))
    }

    /// The rating of a golden or blue hour's session, while the forecast covers it.
    private func rating(of change: Change, in content: SkyContent) -> OutlookRating? {
        guard case .phase(let segment) = change, segment.phase.isMagicHour else {
            return nil
        }
        return content.session(for: segment)?.rating
    }

    @ViewBuilder
    private func list(_ changes: [Change], ratings: [OutlookRating?], in run: DayRun) -> some View {
        if changes.isEmpty {
            // Through a polar night or a midnight sun, which only a run that reaches tomorrow can tell.
            if run.reachesTomorrow {
                Text("No change of light through tomorrow")
                    .font(.footnote)
            }
        } else {
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                ForEach(Array(zip(changes, ratings)), id: \.0.id) { change, rating in
                    GridRow {
                        switch change {
                        case .phase(let segment):
                            PhaseDot(phase: segment.phase)
                                .gridColumnAlignment(.center)
                            Text(segment.phase.shortTitle)
                        case .sun(let event):
                            Image(systemName: event.symbolName)
                                .symbolRenderingMode(.hierarchical)
                                .imageScale(.small)
                            Text(event.title)
                        }
                        Text(run.timeText(change.date))
                            .monospacedDigit()
                        if let rating {
                            OutlookLabel(rating: rating)
                        }
                    }
                }
            }
            .font(.footnote)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(zip(changes, ratings).map { change, rating in
                let outlook = rating.map { ", \(OutlookLabel.spoken(rating: $0, cloudCover: nil))" } ?? ""
                return switch change {
                case .phase(let segment): "\(segment.phase.title) at \(run.timeText(change.date))\(outlook)"
                case .sun(let event): "\(event.title) at \(run.timeText(change.date))"
                }
            }
            .joined(separator: ", "))
        }
    }
}

#Preview {
    let now = Date.now
    let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
    NextPhasesView(entry: entry)
        .skyWidgetBackground(for: entry)
        .padding(16)
        .frame(width: 348, height: 164)
        .background(SkyBackground(entry: entry))
        .clipShape(.rect(cornerRadius: 24))
}

//
//  NextPhasesView.swift
//  Chromahora
//

import SwiftUI

/// The medium widget pairing the next golden or blue hour, as the small widget shows it, with
/// what comes after it: each change of phase, and the sunrise or sunset between them.
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

    var body: some View {
        WidgetContent(entry: entry) { content in
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    MagicHourSummary(content: content, now: entry.date)
                    Spacer(minLength: 4)
                    WidgetCredit(showsWeather: MagicHourSummary.spell(in: content, at: entry.date) != nil, linksSources: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                changes(in: content.run)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func changes(in run: DayRun) -> some View {
        // After the golden or blue hour the summary beside the list leads with, which it would repeat.
        let after = max(entry.date, run.magicHour(at: entry.date)?.interval.start ?? entry.date)
        let phases = run.segments.filter { $0.interval.start > after }.map(Change.phase)
        let sun = run.days.flatMap(\.events).filter { $0.date > after }.map(Change.sun)
        let changes = (phases + sun).sorted { $0.date < $1.date }.prefix(Self.changes)
        if changes.isEmpty {
            // Through a polar night or a midnight sun, which only a run that reaches tomorrow can tell.
            if run.reachesTomorrow {
                Text("No change of light through tomorrow")
                    .font(.footnote)
            }
        } else {
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                ForEach(changes) { change in
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
                    }
                }
            }
            .font(.footnote)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(changes.map { change in
                switch change {
                case .phase(let segment): "\(segment.phase.title) at \(run.timeText(change.date))"
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

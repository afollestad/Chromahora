//
//  MorningEveningView.swift
//  Chromahora
//

import SwiftUI

/// The medium widget for a day's two ends: the blue and golden hours and sunrise of its morning
/// beside those of its evening. Once the day's last golden or blue hour is over it shows
/// tomorrow, whose come sooner.
struct MorningEveningView: View {
    let entry: SkyEntry

    /// What one end of the day lists: its golden and blue hours, and its sunrise or sunset.
    struct End {
        let title: String
        let magicHours: [DaySegment]
        let event: SolarEvent?
    }

    var body: some View {
        WidgetContent(entry: entry, loaded: loaded)
    }

    private func loaded(_ content: SkyContent) -> some View {
        let day = content.run.featuredDay(at: entry.date)
        let ends = Self.ends(of: day, in: content.run)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                WidgetPlaceHeader(place: content.place, deviceName: content.deviceName)
                Spacer(minLength: 8)
                Text(day.dayText(day.dayStart))
                    .font(.subheadline)
                    .lineLimit(1)
            }
            HStack(alignment: .top, spacing: 12) {
                column(ends.morning, in: content.run)
                column(ends.evening, in: content.run)
            }
            Spacer(minLength: 0)
            WidgetCredit(showsWeather: false, linksSources: true)
        }
    }

    private func column(_ end: End, in run: DayRun) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(end.title)
                .font(.caption.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 3) {
                ForEach(end.magicHours) { segment in
                    GridRow {
                        PhaseDot(phase: segment.phase)
                        Text(segment.phase.shortTitle)
                        Text(run.rangeText(segment.interval, span: segment.span, startsLine: true))
                            .monospacedDigit()
                    }
                }
                if let event = end.event {
                    GridRow {
                        Image(systemName: event.symbolName)
                            .symbolRenderingMode(.hierarchical)
                            .imageScale(.small)
                        Text(event.title)
                        Text(run.timeText(event.date))
                            .monospacedDigit()
                    }
                }
            }
            .font(.caption)
            .lineLimit(1)
            // Enough for a blue hour that runs past midnight, as in "11:17 PM – 12:10 AM".
            .minimumScaleFactor(0.6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.spoken(end, in: run))
            if end.magicHours.isEmpty, end.event == nil {
                Text("None")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The day's golden and blue hours that begin on it, parted where its sun is highest: the
    /// middle of its longest daylight, or where it has none, of its longest brightest phase, since
    /// near the poles a brief dip around midnight can part daylight in two. Near the poles an end
    /// can have several golden and blue hours, or none.
    static func ends(of day: SolarDay, in run: DayRun) -> (morning: End, evening: End) {
        let brightness: [DayPhase] = [.night, .blueHour, .goldenHour, .daylight]
        let brightest = day.segments.max { lhs, rhs in
            let lhsRank = brightness.firstIndex(of: lhs.phase) ?? 0
            let rhsRank = brightness.firstIndex(of: rhs.phase) ?? 0
            return lhsRank == rhsRank ? lhs.interval.duration < rhs.interval.duration : lhsRank < rhsRank
        }
        let noon = brightest?.midpoint ?? day.dayStart.addingTimeInterval(day.duration / 2)
        // Merged across midnight, so an evening blue hour that runs into tomorrow reads whole.
        // One cut off at the day's start began the evening before.
        let magicHours = run.segments.filter { $0.phase.isMagicHour && $0.interval.start > day.dayStart && $0.interval.start < day.dayEnd }
        return (
            End(title: "Morning", magicHours: magicHours.filter { $0.interval.start < noon }, event: day.events.first { $0.kind == .sunrise }),
            End(title: "Evening", magicHours: magicHours.filter { $0.interval.start >= noon }, event: day.events.first { $0.kind == .sunset })
        )
    }

    private static func spoken(_ end: End, in run: DayRun) -> String {
        let magicHours = end.magicHours.map { "\($0.phase.title), \(run.rangeText($0.interval, span: $0.span))" }
        let event = end.event.map { "\($0.title) at \(run.timeText($0.date))" }
        return (magicHours + [event].compactMap(\.self)).joined(separator: "; ")
    }
}

#Preview {
    let now = Date.now
    let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
    MorningEveningView(entry: entry)
        .skyWidgetBackground(for: entry)
        .padding(16)
        .frame(width: 348, height: 164)
        .background(SkyBackground(entry: entry))
        .clipShape(.rect(cornerRadius: 24))
}

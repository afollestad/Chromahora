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

    var body: some View {
        WidgetContent(entry: entry, loaded: loaded)
    }

    private func loaded(_ content: SkyContent) -> some View {
        let day = content.run.featuredDay(at: entry.date)
        let ends = content.run.ends(of: day)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                WidgetPlaceHeader(place: content.place, deviceName: content.deviceName)
                Spacer(minLength: 8)
                Text(day.dayText(day.dayStart))
                    .font(.subheadline)
                    .lineLimit(1)
            }
            HStack(alignment: .top, spacing: 12) {
                column("Morning", ends.morning, in: content.run)
                column("Evening", ends.evening, in: content.run)
            }
            Spacer(minLength: 0)
            WidgetCredit(showsWeather: false, linksSources: true)
        }
    }

    private func column(_ title: String, _ end: DayRun.End, in run: DayRun) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
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

    private static func spoken(_ end: DayRun.End, in run: DayRun) -> String {
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

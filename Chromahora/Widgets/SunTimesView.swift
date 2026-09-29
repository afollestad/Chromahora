//
//  SunTimesView.swift
//  Chromahora
//

import SwiftUI

/// The small widget for the next sunrise or sunset, in large type, with the golden hour the sun
/// crosses the horizon in and the blue hour on its dark side.
struct SunTimesView: View {
    let entry: SkyEntry

    var body: some View {
        WidgetContent(entry: entry) { content in
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetPlaceHeader(place: content.place, deviceName: content.deviceName)
                    if let event = content.run.nextSunEvent(after: entry.date) {
                        sunEvent(event, in: content.run)
                    } else {
                        noSunEvent(in: content.run)
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 4)
                WidgetCredit(showsWeather: false)
            }
        }
    }

    @ViewBuilder
    private func sunEvent(_ event: SolarEvent, in run: DayRun) -> some View {
        WidgetHero(run.timeText(event.date))
        Label(event.title, systemImage: event.symbolName)
            .symbolRenderingMode(.hierarchical)
            .font(.subheadline.weight(.semibold))
        Spacer(minLength: 4)
        let magicHours = Self.magicHours(around: event, in: run)
        // Named as well as colored, since a tinted Home Screen draws both dots in one color.
        Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 2) {
            ForEach(magicHours) { segment in
                GridRow {
                    PhaseDot(phase: segment.phase)
                    Text(segment.phase.shortTitle)
                    Text(run.rangeText(segment.interval, span: segment.span, startsLine: true))
                        .monospacedDigit()
                }
            }
        }
        .font(.footnote)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(magicHours.map { "\($0.phase.title), \(run.rangeText($0.interval, span: $0.span))" }.joined(separator: "; "))
    }

    /// Through a polar night or a midnight sun: the phase that holds, and when it changes.
    @ViewBuilder
    private func noSunEvent(in run: DayRun) -> some View {
        if let segment = run.segments(from: entry.date).first {
            WidgetHero(segment.phase.title)
            Spacer(minLength: 4)
            Text(run.rangeText(segment.interval, span: segment.span, startsLine: true))
                .font(.subheadline.weight(.semibold))
            if run.reachesTomorrow {
                Text("No sunrise or sunset")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    /// The golden hour the sun rises or sets in, and the blue hour on its dark side: before a
    /// sunrise, after a sunset. In time order, and either can be missing near the poles.
    static func magicHours(around event: SolarEvent, in run: DayRun) -> [DaySegment] {
        guard let index = run.segments.firstIndex(where: { $0.interval.start <= event.date && event.date < $0.interval.end }) else {
            return []
        }
        let beside = event.kind == .sunrise ? index - 1 : index + 1
        let neighbor = run.segments.indices.contains(beside) ? run.segments[beside] : nil
        let pair = event.kind == .sunrise ? [neighbor, run.segments[index]] : [run.segments[index], neighbor]
        return pair.compactMap(\.self).filter(\.phase.isMagicHour)
    }
}

#Preview {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    VStack(spacing: 16) {
        ForEach([4, 16], id: \.self) { hour in
            let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
            let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
            SunTimesView(entry: entry)
                .skyWidgetBackground(for: entry)
                .padding(16)
                .frame(width: 164, height: 164)
                .background(SkyBackground(entry: entry))
                .clipShape(.rect(cornerRadius: 24))
        }
    }
}

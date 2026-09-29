//
//  NextMagicHourView.swift
//  Chromahora
//

import SwiftUI

/// The small widget for the next golden or blue hour, laid out like Apple Weather's: the place,
/// the time it starts in large type, and below, the phase under the sky's glyph and how long until
/// it starts. While one is under way it says so, and when it ends.
struct NextMagicHourView: View {
    let entry: SkyEntry

    var body: some View {
        Group {
            switch entry.state {
            case .loaded(let content):
                loaded(content)
            case .unavailable:
                WidgetUnavailableView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func loaded(_ content: SkyContent) -> some View {
        let now = entry.date
        let magicHour = content.run.magicHour(at: now)
        // The sky it starts under, or the sky now while it's under way.
        let spell = magicHour.flatMap { content.spell(at: max($0.interval.start, now)) }
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetPlaceHeader(place: content.place, deviceName: content.deviceName)
                if let magicHour {
                    upcoming(magicHour, spell: spell, in: content.run)
                } else {
                    noMagicHour(in: content.run)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            WidgetCredit(showsWeather: spell != nil)
        }
    }

    @ViewBuilder
    private func upcoming(_ magicHour: DaySegment, spell: WeatherSpell?, in run: DayRun) -> some View {
        let isUnderWay = magicHour.interval.start <= entry.date
        largeText(isUnderWay ? "Now" : run.timeText(magicHour.interval.start))
        Spacer(minLength: 4)
        HStack(spacing: 6) {
            if let spell {
                Image(systemName: spell.condition.symbolName(inDaylight: magicHour.phase == .goldenHour))
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityLabel(spell.title)
            } else {
                PhaseDot(phase: magicHour.phase)
            }
            Text(magicHour.phase.title)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.semibold))
        Group {
            if isUnderWay {
                // "until 7:10 PM", or for one the loaded days can't see the end of, "from 11:17 PM"
                // or "all day".
                Text(run.rangeText(magicHour.interval, span: magicHour.span == .range ? .until : magicHour.span))
            } else {
                WidgetCountdown(date: magicHour.interval.start, now: entry.date)
            }
        }
        .font(.subheadline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// Through a polar night or a midnight sun: the phase that holds, and when it changes.
    @ViewBuilder
    private func noMagicHour(in run: DayRun) -> some View {
        if let segment = run.segments(from: entry.date).first {
            largeText(segment.phase.title)
            Spacer(minLength: 4)
            Text(run.rangeText(segment.interval, span: segment.span, startsLine: true))
                .font(.subheadline.weight(.semibold))
            Text("No golden or blue hour")
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func largeText(_ text: String) -> some View {
        Text(text)
            .font(.largeTitle.weight(.light))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

#Preview {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    VStack(spacing: 16) {
        ForEach([16, 18, 22], id: \.self) { hour in
            let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
            let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
            NextMagicHourView(entry: entry)
                .skyWidgetBackground(for: entry)
                .padding(16)
                .frame(width: 170, height: 170)
                .background(SkyBackground(entry: entry))
                .clipShape(.rect(cornerRadius: 24))
        }
    }
}

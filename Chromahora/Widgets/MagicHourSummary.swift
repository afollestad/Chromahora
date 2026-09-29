//
//  MagicHourSummary.swift
//  Chromahora
//

import SwiftUI

/// The next golden or blue hour at `now`: the place, when it starts in large type, the phase
/// under the sky's glyph, and how long until it starts. While one is under way it says so,
/// and when it ends, and through a polar night or a midnight sun, the phase that holds instead.
struct MagicHourSummary: View {
    let content: SkyContent
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetPlaceHeader(place: content.place, deviceName: content.deviceName)
            if let magicHour = content.run.magicHour(at: now) {
                upcoming(magicHour)
            } else {
                noMagicHour
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The sky the next golden or blue hour starts under, or the sky now while one is under
    /// way. Nil without a forecast that reaches it, when a widget leaves Apple Weather's mark out.
    static func spell(in content: SkyContent, at now: Date) -> WeatherSpell? {
        content.run.magicHour(at: now).flatMap { content.spell(at: max($0.interval.start, now)) }
    }

    @ViewBuilder
    private func upcoming(_ magicHour: DaySegment) -> some View {
        let isUnderWay = magicHour.interval.start <= now
        WidgetHero(isUnderWay ? "Now" : content.run.timeText(magicHour.interval.start))
        Spacer(minLength: 4)
        HStack(spacing: 6) {
            SkyGlyph(phase: magicHour.phase, spell: Self.spell(in: content, at: now))
            Text(magicHour.phase.title)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.semibold))
        Group {
            if isUnderWay {
                // "until 7:10 PM", or for one the loaded days can't see the end of, "from 11:17 PM"
                // or "all day".
                Text(content.run.rangeText(magicHour.interval, span: magicHour.span == .range ? .until : magicHour.span))
            } else {
                WidgetCountdown(date: magicHour.interval.start, now: now)
            }
        }
        .font(.subheadline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private var noMagicHour: some View {
        if let segment = content.run.segments(from: now).first {
            WidgetHero(segment.phase.title)
            Spacer(minLength: 4)
            Text(content.run.rangeText(segment.interval, span: segment.span, startsLine: true))
                .font(.subheadline.weight(.semibold))
            if content.run.reachesTomorrow {
                Text("No golden or blue hour")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

#Preview {
    let now = Date.now
    let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
    MagicHourSummary(content: .preview(at: now), now: now)
        .skyWidgetBackground(for: entry)
        .padding(16)
        .frame(width: 164, height: 164)
        .background(SkyBackground(entry: entry))
}

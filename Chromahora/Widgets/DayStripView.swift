//
//  DayStripView.swift
//  Chromahora
//

import SwiftUI

/// The medium widget for the whole day: its sky on its side, with now marked, and below, the
/// next golden and blue hours, their skies, and how long until the first, or with a forecast
/// that covers them, their outlooks and cloud cover in its place. Once the day's last golden or
/// blue hour is over it shows tomorrow's, whose come sooner.
struct DayStripView: View {
    let entry: SkyEntry

    /// How many golden and blue hours the rows list, which is one end of a typical day.
    private static let rows = 2

    var body: some View {
        WidgetContent(entry: entry, loaded: loaded)
    }

    private func loaded(_ content: SkyContent) -> some View {
        let day = content.run.featuredDay(at: entry.date)
        let magicHours = Array(content.run.segments(from: entry.date).filter(\.phase.isMagicHour).prefix(Self.rows))
        let spells = magicHours.map { content.spell(at: max($0.interval.start, entry.date)) }
        let outlooks = magicHours.map { Outlook(rating: content.session(for: $0)?.rating, cloudCover: content.cloudCover(over: $0.interval)) }
        let showsOutlook = outlooks.contains { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                WidgetPlaceHeader(place: content.place, deviceName: content.deviceName)
                Spacer(minLength: 8)
                Text(day.dayText(day.dayStart))
                    .font(.subheadline)
                    .lineLimit(1)
            }
            SkyStrip(day: day, now: entry.date)
            if magicHours.isEmpty {
                if content.run.reachesTomorrow {
                    Text("No golden or blue hour")
                        .font(.subheadline)
                }
            } else {
                // A grid, so the titles and ranges line up past glyphs of different widths.
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(Array(magicHours.enumerated()), id: \.element.id) { index, segment in
                        magicHourRow(
                            segment,
                            spell: spells[index],
                            outlook: showsOutlook ? outlooks[index] : nil,
                            showsCountdown: index == 0,
                            in: content.run
                        )
                    }
                }
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
            WidgetCredit(showsWeather: spells.contains { $0 != nil } || showsOutlook, linksSources: true)
        }
    }

    /// A golden or blue hour's session rating and its own cloud cover, as far as the forecast reaches.
    private struct Outlook {
        let rating: OutlookRating?
        let cloudCover: Double?

        var isEmpty: Bool {
            rating == nil && cloudCover == nil
        }
    }

    /// With `outlook`, the row gives it in place of the countdown, with the phase's short title,
    /// since the row has no room for both beside a range.
    private func magicHourRow(
        _ segment: DaySegment, spell: WeatherSpell?, outlook: Outlook?, showsCountdown: Bool, in run: DayRun
    ) -> some View {
        GridRow {
            SkyGlyph(phase: segment.phase, spell: spell)
                .gridColumnAlignment(.center)
            Text(outlook == nil ? segment.phase.title : segment.phase.shortTitle)
                .fontWeight(.semibold)
                .accessibilityLabel(segment.phase.title)
            Text(run.rangeText(segment.interval, span: segment.span))
                .monospacedDigit()
            Group {
                if let outlook {
                    OutlookLabel(rating: outlook.rating, cloudCover: outlook.cloudCover)
                } else if showsCountdown {
                    if segment.interval.start <= entry.date {
                        Text("Now")
                    } else {
                        WidgetCountdown(date: segment.interval.start, now: entry.date)
                    }
                }
            }
            .multilineTextAlignment(.trailing)
            .padding(.leading, 2)
            .frame(maxWidth: .infinity, alignment: .trailing)
            // Sized last, so a tight row shrinks it rather than the range, which the grid
            // would otherwise cut to an even share with this flexible cell.
            .layoutPriority(-1)
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    VStack(spacing: 16) {
        ForEach([16, 22], id: \.self) { hour in
            let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
            let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
            DayStripView(entry: entry)
                .skyWidgetBackground(for: entry)
                .padding(16)
                .frame(width: 348, height: 164)
                .background(SkyBackground(entry: entry))
                .clipShape(.rect(cornerRadius: 24))
        }
    }
}

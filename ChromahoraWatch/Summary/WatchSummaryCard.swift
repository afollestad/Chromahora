//
//  WatchSummaryCard.swift
//  ChromahoraWatch
//

import SwiftUI

/// The day at a glance, first of its cards. Today it counts down to the next golden or blue
/// hour, or while one is under way, to its end; another day gives its sunrise and sunset. Either
/// rates them by their outlook while the forecast covers them. Under either, the whole day's sky
/// on its side.
///
/// Behind it, the sky climbs from night to the light now, or on another day to its brightest,
/// so the system's white clock always sits on night, and the light shows where the strip sits.
struct WatchSummaryCard: View {
    let day: SolarDay
    /// The day after, when it's held, which the countdown reads into after the day's last golden
    /// or blue hour.
    let nextDay: SolarDay?
    let now: Date
    /// Where the day is for, which the title leaves to the day's name.
    let placeName: String?
    /// The forecast's hours, of any day, which the outlooks read.
    let hours: [SkyHour]

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The phases the background climbs through, in order of the sun's altitude.
    private static let ladder: [DayPhase] = [.night, .blueHour, .goldenHour, .daylight]

    /// How far down night holds, behind the clock and the text, before the sky climbs to the light.
    private static let nightDepth = 0.45

    /// Where the sky reaches the light, which holds from there to the bottom, behind the strip's
    /// hours, whose scheme is the light's.
    private static let lightDepth = 0.78

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)
            if day.contains(now) {
                today
            } else {
                otherDay
            }
            Spacer(minLength: 8)
            SkyStrip(day: day, now: now)
                .environment(\.colorScheme, SkyGradient.labelScheme(over: light.color))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .environment(\.colorScheme, .dark)
        .containerBackground(for: .tabView) {
            background
        }
    }

    // MARK: Today

    @ViewBuilder
    private var today: some View {
        if let magicHour = run.magicHour(at: now) {
            let isUnderWay = magicHour.interval.start <= now
            VStack(alignment: .leading, spacing: 2) {
                phaseTitle(magicHour.phase, rating: todaySession?.rating)
                Text(isUnderWay ? "\(remaining(until: magicHour.interval.end)) left" : "in \(remaining(until: magicHour.interval.start))")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                // "until 7:10 PM", or for one the loaded days can't see the end of, "from 11:17 PM".
                Text(run.rangeText(magicHour.interval, span: isUnderWay && magicHour.span == .range ? .until : magicHour.span))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken(magicHour, isUnderWay: isUnderWay, rating: todaySession?.rating, in: run))
        } else if let segment = run.segments(from: now).first {
            holding(segment, in: run)
        }
    }

    /// Through a polar night or a midnight sun, the phase that holds instead.
    private func holding(_ segment: DaySegment, in run: DayRun) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            phaseTitle(segment.phase)
            Text(run.rangeText(segment.interval, span: segment.span, startsLine: true))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if run.reachesTomorrow {
                Text("No golden or blue hour")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Another day

    @ViewBuilder
    private var otherDay: some View {
        let events = day.events.sorted { $0.date < $1.date }
        if events.isEmpty {
            // Without a sunrise or sunset, as near the poles, the brightest phase the day reaches,
            // which a polar day or night holds all day.
            if let segment = day.segments.filter({ $0.phase == light }).max(by: { $0.interval.duration < $1.interval.duration }) {
                VStack(alignment: .leading, spacing: 2) {
                    phaseTitle(segment.phase)
                    Text(day.rangeText(of: segment, startsLine: true))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                }
                .accessibilityElement(children: .combine)
            }
        } else {
            eventRows(events, ratings: endRatings)
        }
    }

    /// Each end's rating beside its time, or at accessibility sizes under its name, rather than
    /// squeeze the name and time on a small watch, or add rows the card has no height for.
    private func eventRows(_ events: [SolarEvent], ratings: [SolarEvent.Kind: OutlookRating]) -> some View {
        let beside = !dynamicTypeSize.isAccessibilitySize
        return Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
            ForEach(events) { event in
                let rating = ratings[event.kind]
                let time = day.timeText(event.date)
                GridRow {
                    Image(systemName: event.symbolName)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(DayPhase.goldenHour.color)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.title)
                            .font(.headline)
                        if !beside, let rating {
                            rated(rating)
                        }
                    }
                    Text(time)
                        .font(.system(.headline, design: .rounded))
                        .monospacedDigit()
                    if beside, let rating {
                        rated(rating)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    [event.title, time, rating.map { OutlookLabel.spoken(rating: $0, cloudCover: nil) }].compactMap(\.self).joined(separator: ", ")
                )
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// In the text's color, which reads over the sky's orange where gray doesn't, and in a
    /// lighter weight than the name.
    private func rated(_ rating: OutlookRating) -> some View {
        OutlookLabel(rating: rating)
            .font(.footnote)
    }

    // MARK: Outlook

    private var run: DayRun {
        DayRun(day, then: nextDay.map { [$0] } ?? [])
    }

    /// Today, the session of the golden or blue hour the card counts down to, while the forecast covers it.
    private var todaySession: OutlookSession? {
        guard day.contains(now), let magicHour = run.magicHour(at: now) else {
            return nil
        }
        return PhotoOutlook.session(for: magicHour, in: run, hours: hours)
    }

    /// Another day's morning and evening ratings, by the sunrise or sunset each end holds.
    private var endRatings: [SolarEvent.Kind: OutlookRating] {
        guard !day.contains(now) else {
            return [:]
        }
        var ratings: [SolarEvent.Kind: OutlookRating] = [:]
        for session in PhotoOutlook.sessions(on: day, in: run, hours: hours) {
            switch session.kind {
            case .morning: ratings[.sunrise] = session.rating
            case .evening: ratings[.sunset] = session.rating
            case .beforeDawn, .daylight, .night: break
            }
        }
        return ratings
    }

    /// Whether a rating is on the card, which Apple Weather's mark credits.
    private var showsWeather: Bool {
        todaySession != nil || !endRatings.isEmpty
    }

    // MARK: Pieces

    /// The place, and while the card shows an outlook, Apple Weather's mark beside it, or under it
    /// where there's no room. Up here on night's dark rather than beside a rating, where "Great
    /// Weather" would read as a forecast.
    @ViewBuilder
    private var header: some View {
        if placeName != nil || showsWeather {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    place
                    Spacer(minLength: 4)
                    weatherMark
                }
                VStack(alignment: .leading, spacing: 0) {
                    place
                    weatherMark
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            // Clear of the page dots beside the Crown, which the mark reaches.
            .padding(.trailing, showsWeather ? 14 : 0)
        }
    }

    @ViewBuilder
    private var place: some View {
        if let placeName {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text(placeName)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var weatherMark: some View {
        if showsWeather {
            AppleWeatherCredit.mark
                .font(.caption2)
                .fixedSize()
        }
    }

    private func phaseTitle(_ phase: DayPhase, rating: OutlookRating? = nil) -> some View {
        HStack(spacing: 6) {
            PhaseDot(phase: phase)
            PhaseOutlookTitle(phase: phase, rating: rating)
                .font(.headline)
        }
    }

    /// The time from now until `date`, to the nearest minute and never under one, as in "1 hr, 4 min".
    private func remaining(until date: Date, width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated) -> String {
        let minutes = max((date.timeIntervalSince(now) / 60).rounded(), 1)
        return DaySegment.durationText(minutes * 60, width: width)
    }

    private func spoken(_ magicHour: DaySegment, isUnderWay: Bool, rating: OutlookRating?, in run: DayRun) -> String {
        let range = run.rangeText(magicHour.interval, span: magicHour.span)
        let outlook = rating.map { ", \(OutlookLabel.spoken(rating: $0, cloudCover: nil))" } ?? ""
        return isUnderWay
            ? "\(magicHour.phase.title), \(remaining(until: magicHour.interval.end, width: .wide)) left, \(range)\(outlook)"
            : "\(magicHour.phase.title) in \(remaining(until: magicHour.interval.start, width: .wide)), \(range)\(outlook)"
    }

    /// The phase the sky climbs to: the one now, or on another day the brightest it reaches.
    private var light: DayPhase {
        if day.contains(now) {
            return day.phase(at: now)
        }
        return day.segments.map(\.phase).max { Self.rank($0) < Self.rank($1) } ?? .night
    }

    private static func rank(_ phase: DayPhase) -> Int {
        ladder.firstIndex(of: phase) ?? 0
    }

    /// Night down to `nightDepth`, then each phase up to `light` spread evenly to `lightDepth`, with
    /// the timeline's mauve between blue and golden hours. Night alone glows faintly blue at the
    /// bottom, so the card still reads as sky.
    private var background: some View {
        let phases = Array(Self.ladder.prefix(Self.rank(light) + 1))
        var colors = phases.flatMap { phase in
            phase == .goldenHour ? [SkyGradient.duskBridge, phase.color] : [phase.color]
        }
        if colors.count == 1 {
            colors.append(DayPhase.night.color.mix(with: DayPhase.blueHour.color, by: 0.35))
        }
        let step = (Self.lightDepth - Self.nightDepth) / Double(colors.count - 1)
        var stops = [Gradient.Stop(color: colors[0], location: 0)]
        for (index, color) in colors.enumerated() {
            stops.append(Gradient.Stop(color: color, location: Self.nightDepth + Double(index) * step))
        }
        stops.append(Gradient.Stop(color: colors[colors.count - 1], location: 1))
        return Rectangle()
            .fill(.linearGradient(Gradient(stops: stops).colorSpace(.perceptual), startPoint: .top, endPoint: .bottom))
            .overlay(.black.opacity(isLuminanceReduced ? 0.5 : 0))
    }
}

#Preview {
    @Previewable @State var card = 0
    let now = Date.now
    let day = SolarDay.mock(for: now)
    TabView(selection: $card) {
        WatchSummaryCard(day: day, nextDay: nil, now: now, placeName: "San Francisco", hours: SkyHour.mock(for: now))
            .tag(0)
        WatchSummaryCard(day: day, nextDay: nil, now: day.dayEnd.addingTimeInterval(3600), placeName: "San Francisco", hours: SkyHour.mock(for: now))
            .tag(1)
    }
    .tabViewStyle(.verticalPage)
}

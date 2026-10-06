//
//  WatchSummaryCard.swift
//  ChromahoraWatch
//

import SwiftUI

/// The day at a glance, first of its cards. Today it counts down to the next golden or blue
/// hour, or while one is under way, to its end; another day gives its sunrise and sunset. Under
/// either, the whole day's sky on its side.
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

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// The phases the background climbs through, in order of the sun's altitude.
    private static let ladder: [DayPhase] = [.night, .blueHour, .goldenHour, .daylight]

    /// How far down night holds, behind the clock and the text, before the sky climbs to the light.
    private static let nightDepth = 0.45

    /// Where the sky reaches the light, which holds from there to the bottom, behind the strip's
    /// hours, whose scheme is the light's.
    private static let lightDepth = 0.78

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let placeName {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .imageScale(.small)
                        .accessibilityHidden(true)
                    Text(placeName)
                        .lineLimit(1)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
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
        let run = DayRun(day, then: nextDay.map { [$0] } ?? [])
        if let magicHour = run.magicHour(at: now) {
            let isUnderWay = magicHour.interval.start <= now
            VStack(alignment: .leading, spacing: 2) {
                phaseTitle(magicHour.phase)
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
            .accessibilityLabel(spoken(magicHour, isUnderWay: isUnderWay, in: run))
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
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                ForEach(events) { event in
                    GridRow {
                        Image(systemName: event.symbolName)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(DayPhase.goldenHour.color)
                            .accessibilityHidden(true)
                        Text(event.title)
                            .font(.headline)
                        Text(day.timeText(event.date))
                            .font(.system(.headline, design: .rounded))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    // MARK: Pieces

    private func phaseTitle(_ phase: DayPhase) -> some View {
        HStack(spacing: 6) {
            PhaseDot(phase: phase)
            Text(phase.title)
                .font(.headline)
                .lineLimit(1)
        }
    }

    /// The time from now until `date`, to the nearest minute and never under one, as in "1 hr, 4 min".
    private func remaining(until date: Date, width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated) -> String {
        let minutes = max((date.timeIntervalSince(now) / 60).rounded(), 1)
        return DaySegment.durationText(minutes * 60, width: width)
    }

    private func spoken(_ magicHour: DaySegment, isUnderWay: Bool, in run: DayRun) -> String {
        let range = run.rangeText(magicHour.interval, span: magicHour.span)
        return isUnderWay
            ? "\(magicHour.phase.title), \(remaining(until: magicHour.interval.end, width: .wide)) left, \(range)"
            : "\(magicHour.phase.title) in \(remaining(until: magicHour.interval.start, width: .wide)), \(range)"
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
        WatchSummaryCard(day: day, nextDay: nil, now: now, placeName: "San Francisco")
            .tag(0)
        WatchSummaryCard(day: day, nextDay: nil, now: day.dayEnd.addingTimeInterval(3600), placeName: "San Francisco")
            .tag(1)
    }
    .tabViewStyle(.verticalPage)
}

//
//  PhaseComplicationView.swift
//  Chromahora
//

import SwiftUI
import WidgetKit

/// The golden or blue hour under way or next, as a complication on the watch face: when it
/// starts and how long until then, or while one is under way, when it ends. Through a polar night
/// or a midnight sun, the phase that holds instead.
///
/// Complications carry no credit and no weather, since none has room for a credit line; the
/// watch app, a tap away, shows both.
struct PhaseComplicationView: View {
    /// The shapes a watch face gives a complication. Named apart from `WidgetFamily`, whose
    /// corner exists only on the watch, so the phone's snapshots reach every one.
    enum Layout: CaseIterable {
        case circular
        case corner
        case inline
        case rectangular
    }

    let entry: SkyEntry
    let layout: Layout

    var body: some View {
        Group {
            switch entry.state {
            case .loaded(let content):
                loaded(content.run)
            case .unavailable:
                unavailable
            }
        }
        // The largest a complication's fixed size holds, as for the widgets.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private var now: Date {
        entry.date
    }

    // MARK: Layouts

    @ViewBuilder
    private func loaded(_ run: DayRun) -> some View {
        if let magicHour = run.magicHour(at: now) {
            upcoming(magicHour, in: run)
        } else if let segment = run.segments(from: now).first {
            holding(segment, in: run)
        }
    }

    /// The golden or blue hour under way or next: when it starts, or while under way, when it ends.
    @ViewBuilder
    private func upcoming(_ magicHour: DaySegment, in run: DayRun) -> some View {
        let isUnderWay = magicHour.interval.start <= now
        switch layout {
        case .circular:
            circular(magicHour, isUnderWay: isUnderWay, in: run)
        case .corner:
            Text(isUnderWay ? endText(magicHour, in: run) : run.timeText(magicHour.interval.start))
                .minimumScaleFactor(0.6)
                .widgetCurvesContent()
                .widgetLabel {
                    Text(isUnderWay && magicHour.span.endsInRun ? "\(magicHour.phase.title) until" : magicHour.phase.title)
                        .widgetAccentable()
                }
        case .inline:
            Text("\(magicHour.phase.title) \(isUnderWay ? untilText(magicHour, in: run) : run.timeText(magicHour.interval.start))")
        case .rectangular:
            rectangular(title: magicHour.phase.title, phase: magicHour.phase) {
                if isUnderWay {
                    Text("Now")
                    Text(untilText(magicHour, in: run))
                } else {
                    Text(run.timeText(magicHour.interval.start))
                    WidgetCountdown(date: magicHour.interval.start, now: now)
                }
            }
        }
    }

    /// The phase that holds when neither golden nor blue hour comes before the run ends, as
    /// through a polar night or a midnight sun.
    @ViewBuilder
    private func holding(_ segment: DaySegment, in run: DayRun) -> some View {
        let range = run.rangeText(segment.interval, span: segment.span)
        switch layout {
        case .circular:
            ZStack {
                AccessoryWidgetBackground()
                Text(segment.phase.shortTitle)
                    .font(.caption.weight(.semibold))
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                    .padding(4)
            }
        case .corner:
            Text(segment.phase.shortTitle)
                .minimumScaleFactor(0.6)
                .widgetCurvesContent()
                .widgetLabel {
                    Text(range)
                }
        case .inline:
            Text("\(segment.phase.title) \(range)")
        case .rectangular:
            rectangular(title: segment.phase.title, phase: segment.phase) {
                Text(run.rangeText(segment.interval, span: segment.span, startsLine: true))
                if run.reachesTomorrow {
                    Text("No golden or blue hour")
                }
            }
        }
    }

    /// The phase's name over two lines of when, in the widgets' order: a dot for the phase, which
    /// the name says too, since a tinted face draws the dot in one color.
    private func rectangular(title: String, phase: DayPhase, @ViewBuilder lines: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                PhaseDot(phase: phase)
                Text(title)
                    .font(.headline)
                    .widgetAccentable()
            }
            lines()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The short name over its time. While a golden or blue hour is under way, where the run holds
    /// both its ends, a ring shows how much of it is left, moving on with the timeline's entries,
    /// which come every quarter hour while the sky's color shifts.
    @ViewBuilder
    private func circular(_ magicHour: DaySegment, isUnderWay: Bool, in run: DayRun) -> some View {
        if isUnderWay, magicHour.span == .range {
            Gauge(value: share(of: magicHour, leftAt: now)) {
                Text(magicHour.phase.shortTitle)
                    .widgetAccentable()
            } currentValueLabel: {
                // The ring's middle holds no more than "7:10", and the end of a golden or blue
                // hour under way is never far enough off to mistake its half of the day.
                Text(run.clockText(magicHour.interval.end))
                    .minimumScaleFactor(0.6)
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(magicHour.phase.shortTitle)
                        .font(.caption2.weight(.semibold))
                        .widgetAccentable()
                    Text(isUnderWay ? endText(magicHour, in: run) : run.timeText(magicHour.interval.start))
                        .font(.caption2)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(4)
            }
        }
    }

    /// How much of `segment` is still to come at `date`, from 1 as it starts to 0 as it ends.
    private func share(of segment: DaySegment, leftAt date: Date) -> Double {
        guard segment.interval.duration > 0 else {
            return 0
        }
        return min(max(segment.interval.end.timeIntervalSince(date) / segment.interval.duration, 0), 1)
    }

    /// Until when a golden or blue hour under way runs, or where the run can't see its end,
    /// that it runs all day or from when it began.
    private func untilText(_ magicHour: DaySegment, in run: DayRun) -> String {
        run.rangeText(magicHour.interval, span: magicHour.span == .range ? .until : magicHour.span)
    }

    /// When a golden or blue hour under way ends, or "Now" where the run can't see its end, rather
    /// than the run's own end, where the interval stops short.
    private func endText(_ magicHour: DaySegment, in run: DayRun) -> String {
        magicHour.span.endsInRun ? run.timeText(magicHour.interval.end) : "Now"
    }

    @ViewBuilder
    private var unavailable: some View {
        switch layout {
        case .circular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "sun.horizon")
                    .accessibilityLabel("Sun times will show once they load")
            }
        case .corner:
            Image(systemName: "sun.horizon")
                .accessibilityLabel("Sun times will show once they load")
                .widgetLabel("Sun times loading")
        case .inline:
            Text("Sun times loading")
        case .rectangular:
            // The widgets' note in one row, as their larger glyph would crowd out its words.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "sun.horizon")
                    .accessibilityHidden(true)
                Text("Sun times will show once they load.")
                    .font(.footnote)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let now = Date.now
    let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
    VStack(spacing: 16) {
        ForEach(PhaseComplicationView.Layout.allCases, id: \.self) { layout in
            PhaseComplicationView(entry: entry, layout: layout)
                .frame(width: layout == .rectangular || layout == .inline ? 180 : 50, height: layout == .rectangular ? 60 : 50)
        }
    }
    .padding()
    .background(.black)
    .environment(\.colorScheme, .dark)
}

private extension DaySegment.Span {
    /// Whether a segment with this span ends inside the run, as one cut off by its start still does.
    var endsInRun: Bool {
        self == .range || self == .until
    }
}

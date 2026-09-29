//
//  WatchTimelineOverlay.swift
//  ChromahoraWatch
//

import SwiftUI

/// Annotates the watch's sky: an hour ruler on the leading edge, and one column of labels, each
/// on a line at its time, for every change of light, sunrise and sunset, now, and the weather.
///
/// The phone names each phase beside its band, in a column of its own. The watch is too narrow
/// for two columns of labels, and sunrise falls in the middle of golden hour, so the phase's
/// name beside it would have no room. Here each phase is named where it begins instead.
struct WatchTimelineOverlay: View {
    let day: SolarDay
    let now: Date
    /// The forecast's spells, of any day. Those overlapping this one get a marker each.
    let weather: [WeatherSpell]

    private let horizontalPadding: CGFloat = 8

    /// Narrower than the phone's, which would darken most of the watch's width.
    private let scrimWidth: CGFloat = 56

    /// Minimum vertical distance between neighboring labels. Labels that would sit closer
    /// than this are moved apart; lines stay put. It leaves a visible gap between capsules at
    /// the watch's text sizes, and grows with them.
    @ScaledMetric(relativeTo: .caption2) private var labelSpacing: CGFloat = 32

    /// Hour labels within this distance of a label are hidden so they don't collide.
    @ScaledMetric(relativeTo: .caption2) private var hourLabelClearance: CGFloat = 30

    private enum MarkerKind {
        /// A phase beginning, or one under way since midnight or all day.
        case phase(DaySegment)
        /// Sunrise or sunset.
        case event(SolarEvent)
        case now
        /// A weather spell, with when it runs as the day words it, and whether its icon shows the sun.
        case weather(WeatherSpell, range: String, inDaylight: Bool)
    }

    private struct Marker: Identifiable {
        let id: String
        let date: Date
        let kind: MarkerKind
    }

    private struct PlacedMarker: Identifiable {
        let marker: Marker
        let lineY: CGFloat
        let labelY: CGFloat

        var id: String { marker.id }
    }

    /// Every label is laid out twice: once as itself, and once as its bare capsule in the
    /// mask that cuts it out of the lines.
    private enum LabelStyle {
        case glass
        case cutout
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let markers = placedMarkers(size: size)

            // No `GlassEffectContainer`: it renders every capsule in the container's color
            // scheme, overriding the one each label takes from the sky behind it.
            ZStack {
                RulerScrim(leadingInset: 0, width: scrimWidth)
                hourRuler(size: size, avoiding: markers)
                lines(markers, size: size)
                labels(markers, size: size, style: .glass)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: Layers

    private func hourRuler(size: CGSize, avoiding markers: [PlacedMarker]) -> some View {
        ForEach(day.hourMarks) { mark in
            let y = y(for: mark.date, in: size)
            let isMajor = mark.hour % 2 == 0
            let showsLabel = isMajor && !markers.contains { abs($0.labelY - y) < hourLabelClearance }

            row(at: y, size: size) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(.white.opacity(isMajor ? 0.7 : 0.4))
                        .frame(width: isMajor ? 8 : 4, height: 1)
                        .accessibilityHidden(true)

                    if showsLabel {
                        Text(day.hourText(mark.date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                    }
                }
            }
        }
    }

    /// Lines run under the labels and break around each one, since glass shows a line through
    /// its text, and a label pushed off its own line can sit on a neighbor's.
    private func lines(_ markers: [PlacedMarker], size: CGSize) -> some View {
        ZStack {
            ForEach(markers.filter { drawsLine($0.marker) }) { placed in
                line(for: placed.marker)
                    .position(x: size.width / 2, y: placed.lineY)
            }
        }
        .mask {
            Rectangle()
                .overlay {
                    labels(markers, size: size, style: .cutout)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
        .accessibilityHidden(true)
    }

    private func labels(_ markers: [PlacedMarker], size: CGSize, style: LabelStyle) -> some View {
        ForEach(markers) { placed in
            row(at: placed.labelY, size: size) {
                label(for: placed.marker, over: skyColor(at: placed.labelY, in: size), style: style)
                    .padding(.leading, horizontalPadding)
                    .padding(.trailing, horizontalPadding)
            }
        }
    }

    // MARK: Pieces

    /// A phase's line marks where the sky's color turns, which it blends across over most of an
    /// hour. Sunrise, sunset and now draw one too, and so does precipitation where it begins,
    /// as the weather worth lining up against the light. A spell carried over from the night
    /// before draws none, and neither does a phase under way since midnight, which starts the day.
    private func drawsLine(_ marker: Marker) -> Bool {
        switch marker.kind {
        case .phase, .event, .now:
            marker.date > day.dayStart
        case .weather(let spell, _, _):
            spell.condition.isPrecipitation && spell.interval.start > day.dayStart
        }
    }

    /// A change of light's line is fainter than the sun's and now's, which are the day's firm
    /// times. Precipitation's is dashed, with short even dashes that read as a forecast.
    @ViewBuilder
    private func line(for marker: Marker) -> some View {
        switch marker.kind {
        case .event, .now:
            Rectangle()
                .fill(.white.opacity(0.6))
                .frame(height: 1)
        case .phase:
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(height: 1)
        case .weather:
            HorizontalRule()
                .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func label(for marker: Marker, over sky: Color, style: LabelStyle) -> some View {
        switch marker.kind {
        case .phase(let segment):
            // Tinted with the phase's own color, which picks its scheme too.
            let phaseColor = segment.phase.color
            let scheme = SkyGradient.labelScheme(over: phaseColor)
            label(phaseText(for: segment), glass: .regular.tint(phaseColor.opacity(0.5)), scheme: scheme, style: style)
                .accessibilityLabel("\(segment.phase.title), \(day.rangeText(of: segment))")
        case .event(let event):
            label("\(event.title) · \(day.timeText(event.date))", scheme: SkyGradient.labelScheme(over: sky), style: style)
        case .now:
            label("Now · \(day.timeText(marker.date))", scheme: SkyGradient.labelScheme(over: sky), style: style)
        case .weather(let spell, let range, let inDaylight):
            switch style {
            case .glass:
                WeatherButton(spell: spell, range: range, inDaylight: inDaylight, scheme: SkyGradient.labelScheme(over: sky))
            case .cutout:
                WeatherButton.glyph(for: spell.condition, inDaylight: inDaylight)
                    .background(Capsule())
            }
        }
    }

    /// `scheme` comes from the sky or phase behind the label, which the system's appearance
    /// knows nothing about. White text over daylight contrasts at only 1.5:1. A long label
    /// shrinks rather than truncate on the smallest watches.
    @ViewBuilder
    private func label(_ text: String, glass: Glass = .regular, scheme: ColorScheme, style: LabelStyle) -> some View {
        let content = Text(text)
            .font(.caption2.weight(.semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        switch style {
        case .glass:
            content
                .glassEffect(glass, in: Capsule())
                .environment(\.colorScheme, scheme)
        case .cutout:
            content.background(Capsule())
        }
    }

    /// Where a phase begins, or for one under way since midnight, when it ends.
    private func phaseText(for segment: DaySegment) -> String {
        switch segment.span {
        case .range, .from:
            "\(segment.phase.title) · \(day.timeText(segment.interval.start))"
        case .until, .allDay:
            "\(segment.phase.title) · \(day.rangeText(of: segment))"
        }
    }

    /// Lays `content` across the full width, aligned to the leading edge, centered on `y`.
    private func row<Content: View>(at y: CGFloat, size: CGSize, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .position(x: size.width / 2, y: y)
    }

    // MARK: Geometry

    private func y(for date: Date, in size: CGSize) -> CGFloat {
        size.height * day.fraction(of: date)
    }

    private func skyColor(at y: CGFloat, in size: CGSize) -> Color {
        SkyGradient.color(at: size.height > 0 ? y / size.height : 0, in: day)
    }

    /// Every phase, sunrise, sunset, now and the weather in time order, with labels nudged apart
    /// where they'd overlap. Labels on lines move for each other, and weather labels without one
    /// move for them. A night under way since midnight goes unlabeled, as its band is
    /// unmistakable and the blue hour that ends it is named, but a night that fills the day is
    /// named, since nothing else would be.
    private func placedMarkers(size: CGSize) -> [PlacedMarker] {
        var markers = day.segments
            .filter { $0.phase != .night || $0.span != .until }
            .map { Marker(id: "phase-\($0.id)", date: $0.span == .until ? day.dayStart : $0.interval.start, kind: .phase($0)) }
        markers += day.events.map { Marker(id: $0.title, date: $0.date, kind: .event($0)) }
        if day.contains(now) {
            markers.append(Marker(id: "Now", date: now, kind: .now))
        }
        for spell in weather {
            guard let span = spell.span(within: day) else {
                continue
            }
            markers.append(Marker(
                id: "weather-\(spell.interval.start.timeIntervalSinceReferenceDate)",
                date: spell.start(on: day),
                kind: .weather(spell, range: day.rangeText(spell.interval, span: span), inDaylight: spell.startsInDaylight(on: day))
            ))
        }
        // Ties break by id, so markers at the same instant keep one order.
        markers.sort { ($0.date, $0.id) < ($1.date, $1.id) }
        let lineYs = markers.map { y(for: $0.date, in: size) }
        let labelYs = LabelSpacing.spaced(lineYs, pinned: markers.map(drawsLine), spacing: labelSpacing)

        return zip(zip(markers, lineYs), labelYs).map { pair, labelY in
            PlacedMarker(marker: pair.0, lineY: pair.1, labelY: labelY)
        }
    }
}

#Preview {
    let now = Date.now
    let day = SolarDay.mock(for: now)
    ScrollView {
        WatchTimelineOverlay(day: day, now: now, weather: WeatherSpell.mock())
            .frame(height: day.duration / 3600 * WatchTimeline.pointsPerHour)
            .background(SkyGradient(day: day))
    }
}

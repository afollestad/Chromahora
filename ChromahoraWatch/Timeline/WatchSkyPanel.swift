//
//  WatchSkyPanel.swift
//  ChromahoraWatch
//

import SwiftUI

/// A stretch of the day's sky in a rounded panel, zoomed so the stretch fills it: the timeline's
/// gradient, with one column of labels, each on a line at its time, for every change of light,
/// sunrise and sunset, now, and the weather.
///
/// The phone names each phase beside its band, in a column of its own. The watch is too narrow
/// for two columns of labels, and sunrise falls in the middle of golden hour, so the phase's
/// name beside it would have no room. Here each phase is named where it begins instead.
struct WatchSkyPanel: View {
    let day: SolarDay
    /// The stretch the labels mark, from the first change of light to the last, which the panel
    /// fills but for room at either end for the labels centered on them.
    let span: DateInterval
    let now: Date
    /// The forecast's spells, of any day. Those reaching the stretch get a marker each.
    let weather: [WeatherSpell]
    /// The height the page leaves it, which it grows past only when its labels need more.
    var fillHeight: CGFloat = 0

    private let horizontalPadding: CGFloat = 8

    /// Rounded at the top like a platter, and at the bottom, which runs down near the screen's
    /// corners, concentric with them.
    static let shape = ConcentricRectangle(uniformTopCorners: .fixed(22), uniformBottomCorners: .concentric(minimum: .fixed(22)))

    /// Minimum vertical distance between neighboring labels. Labels that would sit closer
    /// than this are moved apart; lines stay put. A capsule's height and a hairline gap, which
    /// grows with the text, tighter than the phone's, so five labels fit a 46 mm watch's panel
    /// without scrolling.
    @ScaledMetric(relativeTo: .caption2) private var labelSpacing: CGFloat = 27

    /// Room above the first line for half a label and a margin, so its label clears the panel's
    /// rounded top.
    @ScaledMetric(relativeTo: .caption2) private var topInset: CGFloat = 16

    /// Room below the last line, more than above the first, since the panel runs down into the
    /// screen's rounded corners, which cut off the leading end of a label any lower on a 49 mm watch.
    @ScaledMetric(relativeTo: .caption2) private var bottomInset: CGFloat = 27

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private enum MarkerKind {
        /// A phase beginning.
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

    /// The spells reaching `span` on `day`, which the panel marks and whose credit its card shows.
    static func spells(in weather: [WeatherSpell], reaching span: DateInterval, on day: SolarDay) -> [WeatherSpell] {
        weather.filter { $0.interval.start < span.end && $0.interval.end > span.start && $0.span(within: day) != nil }
    }

    var body: some View {
        let markers = markers()
        GeometryReader { geometry in
            let size = geometry.size
            let placed = place(markers, in: size)

            // No `GlassEffectContainer`: it renders every capsule in the container's color
            // scheme, overriding the one each label takes from the sky behind it.
            ZStack {
                sky(in: size)
                lines(placed, size: size)
                labels(placed, size: size, style: .glass)
            }
            .frame(width: size.width, height: size.height)
        }
        // Taller than the page leaves only when the labels need it, and the page scrolls.
        .frame(height: max(fillHeight, CGFloat(max(markers.count - 1, 0)) * labelSpacing + topInset + bottomInset))
        .clipShape(Self.shape)
    }

    // MARK: Layers

    /// The day's gradient, scaled so `span` fills the panel between its insets: the timeline's
    /// stops within the panel, between the colors at its edges.
    private func sky(in size: CGSize) -> some View {
        let dayStops = SkyGradient.stops(for: day)
        let top = dayFraction(at: 0, in: size)
        let bottom = dayFraction(at: size.height, in: size)
        var stops = [Gradient.Stop(color: SkyGradient.color(at: top, in: dayStops), location: 0)]
        for stop in dayStops where stop.location > top && stop.location < bottom {
            stops.append(Gradient.Stop(color: stop.color, location: (stop.location - top) / (bottom - top)))
        }
        stops.append(Gradient.Stop(color: SkyGradient.color(at: bottom, in: dayStops), location: 1))
        return Rectangle()
            .fill(.linearGradient(Gradient(stops: stops).colorSpace(.perceptual), startPoint: .top, endPoint: .bottom))
            // Always On dims the sky, as the system dims a watch face's colors.
            .overlay(.black.opacity(isLuminanceReduced ? 0.5 : 0))
            .accessibilityHidden(true)
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
            label(for: placed.marker, over: skyColor(at: placed.labelY, in: size), style: style)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .position(x: size.width / 2, y: placed.labelY)
        }
    }

    // MARK: Pieces

    /// A phase's line marks where the sky's color turns, which it blends across over most of an
    /// hour. Sunrise, sunset and now draw one too, and so does precipitation where it begins,
    /// as the weather worth lining up against the light. A spell already under way as the
    /// stretch begins draws none.
    private func drawsLine(_ marker: Marker) -> Bool {
        switch marker.kind {
        case .phase, .event, .now:
            true
        case .weather(let spell, _, _):
            spell.condition.isPrecipitation && spell.interval.start >= span.start
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
            let text = "\(segment.phase.title) · \(day.timeText(segment.interval.start))"
            label(text, glass: .regular.tint(phaseColor.opacity(0.5)), scheme: scheme, style: style)
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
    /// shrinks rather than truncate on the smallest watches, even at `accessibility1`.
    @ViewBuilder
    private func label(_ text: String, glass: Glass = .regular, scheme: ColorScheme, style: LabelStyle) -> some View {
        let content = Text(text)
            .font(.caption2.weight(.semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
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

    // MARK: Geometry

    /// What fits between the insets: `span`, widened about its middle to half an hour, so a
    /// stretch that's nearly an instant doesn't zoom the sky to one flat color.
    private var shownSpan: DateInterval {
        let minimum: TimeInterval = 30 * 60
        guard span.duration < minimum else {
            return span
        }
        return DateInterval(start: span.start.addingTimeInterval((span.duration - minimum) / 2), duration: minimum)
    }

    private func pointsPerSecond(in size: CGSize) -> CGFloat {
        max(size.height - topInset - bottomInset, 1) / shownSpan.duration
    }

    private func y(for date: Date, in size: CGSize) -> CGFloat {
        topInset + date.timeIntervalSince(shownSpan.start) * pointsPerSecond(in: size)
    }

    /// How far through the day the point `y` down the panel falls, kept to the day.
    private func dayFraction(at y: CGFloat, in size: CGSize) -> Double {
        let date = shownSpan.start.addingTimeInterval((y - topInset) / pointsPerSecond(in: size))
        return min(max(day.fraction(of: date), 0), 1)
    }

    private func skyColor(at y: CGFloat, in size: CGSize) -> Color {
        SkyGradient.color(at: dayFraction(at: y, in: size), in: day)
    }

    /// Every phase beginning in the stretch, sunrise, sunset, now and the weather in time order.
    private func markers() -> [Marker] {
        var markers = day.segments
            .filter { $0.interval.start > day.dayStart && span.contains($0.interval.start) }
            .map { Marker(id: "phase-\($0.id)", date: $0.interval.start, kind: .phase($0)) }
        markers += day.events.filter { span.contains($0.date) }.map { Marker(id: $0.title, date: $0.date, kind: .event($0)) }
        if span.contains(now) {
            markers.append(Marker(id: "Now", date: now, kind: .now))
        }
        for spell in Self.spells(in: weather, reaching: span, on: day) {
            let span = spell.span(within: day) ?? .range
            markers.append(Marker(
                id: "weather-\(spell.interval.start.timeIntervalSinceReferenceDate)",
                date: max(spell.interval.start, self.span.start),
                kind: .weather(spell, range: day.rangeText(spell.interval, span: span), inDaylight: spell.startsInDaylight(on: day))
            ))
        }
        // Ties break by id, so markers at the same instant keep one order.
        return markers.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    /// Puts each marker's line at its time and its label as near it as the labels around allow,
    /// within the panel. Labels on lines move for each other, and weather labels without one
    /// move for them.
    private func place(_ markers: [Marker], in size: CGSize) -> [PlacedMarker] {
        let lineYs = markers.map { y(for: $0.date, in: size) }
        let labelYs = LabelSpacing.spaced(lineYs, pinned: markers.map(drawsLine), spacing: labelSpacing, limit: size.height - bottomInset)
        return zip(zip(markers, lineYs), labelYs).map { pair, labelY in
            PlacedMarker(marker: pair.0, lineY: pair.1, labelY: labelY)
        }
    }
}

#Preview {
    let now = Date.now
    let day = SolarDay.mock(for: now)
    let evening = day.segments.filter(\.phase.isMagicHour).suffix(2)
    if let first = evening.first, let last = evening.last {
        WatchSkyPanel(day: day, span: DateInterval(start: first.interval.start, end: last.interval.end), now: now, weather: WeatherSpell.mock())
            .padding(4)
    }
}

//
//  DayTimelineOverlay.swift
//  Chromahora
//

import SwiftUI

/// The darkened gutter behind the hour ruler, which keeps its white labels legible
/// over the bright daylight band. `DayTimeline` also paints it past the day's ends,
/// so overscrolling doesn't cut it off.
struct RulerScrim: View {
    let leadingInset: CGFloat

    private let width: CGFloat = 112

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.38), location: 0),
                .init(color: .black.opacity(0.2), location: 0.35),
                .init(color: .black.opacity(0.06), location: 0.7),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width + leadingInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// Annotates the sky gradient: an hour ruler on the leading edge, sunrise,
/// sunset and "now" markers, and a label for each phase but night on the trailing edge.
struct DayTimelineOverlay: View {
    let day: SolarDay
    let now: Date
    /// The screen's safe area. The timeline scrolls edge to edge, so this view sees
    /// no insets of its own, and each edge differs by device and orientation.
    let safeAreaInsets: EdgeInsets

    private let horizontalPadding: CGFloat = 16

    /// Keeps a phase label held at the screen's edge visibly apart from the
    /// navigation bar's glass and the home indicator.
    private let heldLabelInset: CGFloat = 8

    /// Minimum vertical distance between neighboring labels on the same edge.
    /// Labels that would sit closer than this are pushed down; marker lines stay
    /// put. It leaves a gap wider than the glass container's merge distance, so
    /// stacked capsules stay separate, and grows with the labels' text.
    @ScaledMetric(relativeTo: .caption2) private var labelSpacing: CGFloat = 28

    /// Hour labels within this distance of a marker label are hidden so they don't collide.
    @ScaledMetric(relativeTo: .caption2) private var hourLabelClearance: CGFloat = 30

    /// Keeps a phase label visibly apart from a marker label on the same row, and
    /// wider than the glass container's merge distance so the two never fuse.
    private let sideBySideGap: CGFloat = 8

    /// Each marker label's width, so a phase label that can land beside it knows
    /// how much of the row is left.
    @State private var markerLabelWidths: [String: CGFloat] = [:]

    private struct Marker: Identifiable {
        let title: String
        let date: Date
        let isNow: Bool

        var id: String { title }
    }

    private struct PlacedMarker: Identifiable {
        let marker: Marker
        let lineY: CGFloat
        let labelY: CGFloat

        var id: String { marker.id }
    }

    private struct PlacedPhase: Identifiable {
        let segment: DaySegment
        let labelY: CGFloat
        /// How far the label may slide from `labelY` to stay on screen, negative for up.
        let slack: ClosedRange<CGFloat>

        var id: Int { segment.id }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let markers = placedMarkers(size: size)

            GlassEffectContainer(spacing: 4) {
                ZStack {
                    RulerScrim(leadingInset: safeAreaInsets.leading)
                    hourRuler(size: size, avoiding: markers)
                    markerLayer(markers, size: size)
                    // Labels are keyed by segment index, so a new phase sequence gets new
                    // labels rather than morphing one phase's capsule into another's.
                    phaseLabels(size: size, beside: markers)
                        .id(day.phaseSequence)
                }
                .frame(width: size.width, height: size.height)
            }
        }
    }

    // MARK: Layers

    private func hourRuler(size: CGSize, avoiding markers: [PlacedMarker]) -> some View {
        ForEach(day.hourMarks) { mark in
            let y = y(for: mark.date, in: size)
            let isMajor = mark.hour % 2 == 0
            let showsLabel = isMajor && !markers.contains { abs($0.labelY - y) < hourLabelClearance }

            row(at: y, alignment: .leading, size: size) {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(.white.opacity(isMajor ? 0.7 : 0.4))
                        .frame(width: isMajor ? 12 : 6, height: 1)
                        .accessibilityHidden(true)

                    if showsLabel {
                        Text(mark.date, format: .dateTime.hour())
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                    }
                }
                .padding(.leading, safeAreaInsets.leading)
            }
        }
    }

    private func markerLayer(_ markers: [PlacedMarker], size: CGSize) -> some View {
        ForEach(markers) { placed in
            Rectangle()
                .fill(.white.opacity(placed.marker.isNow ? 0.9 : 0.35))
                .frame(height: 1)
                .position(x: size.width / 2, y: placed.lineY)
                .accessibilityHidden(true)

            row(at: placed.labelY, alignment: .leading, size: size) {
                label("\(placed.marker.title) · \(placed.marker.date.formatted(date: .omitted, time: .shortened))")
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { width in
                        markerLabelWidths[placed.marker.id] = width
                    }
                    .padding(.leading, safeAreaInsets.leading + horizontalPadding)
            }
        }
    }

    /// Phase labels drop their time range when the full text won't fit beside a marker
    /// label, which happens at large text sizes. VoiceOver still reads the range.
    private func phaseLabels(size: CGSize, beside markers: [PlacedMarker]) -> some View {
        ForEach(placedPhases(size: size)) { placed in
            let glass = Glass.regular.tint(placed.segment.phase.color.opacity(0.5))
            row(at: placed.labelY, alignment: .trailing, size: size) {
                ViewThatFits(in: .horizontal) {
                    label(text(for: placed.segment), glass: glass)
                    label(placed.segment.phase.title, glass: glass)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text(for: placed.segment))
                .accessibilityAddTraits(.isStaticText)
                .frame(maxWidth: phaseLabelWidth(for: placed, beside: markers, size: size), alignment: .trailing)
                .padding(.trailing, safeAreaInsets.trailing + horizontalPadding)
                .visualEffect { [safeAreaInsets, heldLabelInset, slack = placed.slack] content, proxy in
                    // The scroll view's bounds in the label's own space, where the label spans 0 to its height.
                    guard let visible = proxy.bounds(of: .scrollView) else {
                        return content.offset(y: 0)
                    }
                    let top = visible.minY + safeAreaInsets.top + heldLabelInset
                    let bottom = visible.maxY - safeAreaInsets.bottom - heldLabelInset - proxy.size.height
                    let onScreen = min(max(0, top), bottom)
                    return content.offset(y: min(max(onScreen, slack.lowerBound), slack.upperBound))
                }
            }
        }
    }

    // MARK: Pieces

    private func label(_ text: String, glass: Glass = .regular) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(glass, in: Capsule())
    }

    private func text(for segment: DaySegment) -> String {
        "\(segment.phase.title) · \(rangeText(for: segment))"
    }

    /// A phase cut off by midnight began or ends on another day, so its label gives only
    /// the side it has on this one.
    private func rangeText(for segment: DaySegment) -> String {
        let time = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: day.calendar.timeZone)
        switch segment.span {
        case .range:
            let range = Date.IntervalFormatStyle(date: .omitted, time: .shortened, timeZone: day.calendar.timeZone)
            return (segment.interval.start..<segment.interval.end).formatted(range)
        case .until:
            return "until \(segment.interval.end.formatted(time))"
        case .from:
            return "from \(segment.interval.start.formatted(time))"
        case .allDay:
            return "all day"
        }
    }

    /// Lays `content` across the full width, aligned to one edge, centered on `y`.
    private func row<Content: View>(
        at y: CGFloat, alignment: Alignment, size: CGSize, @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: alignment)
            .position(x: size.width / 2, y: y)
    }

    // MARK: Geometry

    /// The row's width left for a phase label after the widest marker label it can
    /// land beside, anywhere its label may slide to while scrolling.
    private func phaseLabelWidth(for placed: PlacedPhase, beside markers: [PlacedMarker], size: CGSize) -> CGFloat {
        let reach = (placed.labelY + placed.slack.lowerBound - labelSpacing)...(placed.labelY + placed.slack.upperBound + labelSpacing)
        let widestMarker = markers
            .filter { reach.contains($0.labelY) }
            .compactMap { markerLabelWidths[$0.id] }
            .max()
        let row = size.width - safeAreaInsets.leading - safeAreaInsets.trailing - 2 * horizontalPadding
        guard let widestMarker else {
            return row
        }
        return max(row - widestMarker - sideBySideGap, 0)
    }

    private func y(for date: Date, in size: CGSize) -> CGFloat {
        size.height * day.fraction(of: date)
    }

    /// Sunrise, sunset and "now" in time order, with labels nudged apart when
    /// they'd overlap. "Now" only appears when the current time falls on this day.
    private func placedMarkers(size: CGSize) -> [PlacedMarker] {
        var markers = day.events.map { Marker(title: $0.title, date: $0.date, isNow: false) }
        if day.contains(now) {
            markers.append(Marker(title: "Now", date: now, isNow: true))
        }
        markers.sort { $0.date < $1.date }
        let lineYs = markers.map { y(for: $0.date, in: size) }

        return zip(zip(markers, lineYs), spaced(lineYs)).map { pair, labelY in
            PlacedMarker(marker: pair.0, lineY: pair.1, labelY: labelY)
        }
    }

    /// A phase's label rests at the phase's midpoint, nudged apart like the markers.
    /// While the phase is partly on screen, the label may slide toward the visible
    /// part, but only within its own phase and clear of its neighbors' resting spots.
    private func placedPhases(size: CGSize) -> [PlacedPhase] {
        // Night goes unlabeled. Its band is unmistakable, midnight cuts its range
        // short, and the blue hour labels already mark where it begins and ends.
        // A night that fills the day is the exception, since nothing else would.
        let segments = day.segments.filter { $0.phase != .night || $0.span == .allDay }
        let labelYs = spaced(segments.map { y(for: $0.midpoint, in: size) })

        return segments.indices.map { index in
            let segment = segments[index]
            let labelY = labelYs[index]
            // A phase that fills the day has no neighbors, so its label may follow the screen
            // anywhere. Any other label leaving its phase would stop at a neighbor's resting
            // spot, which can sit under a bar once the view moves on.
            let fillsDay = segment.span == .allDay
            var highest = fillsDay ? -.infinity : y(for: segment.interval.start, in: size) + labelSpacing / 2
            var lowest = fillsDay ? .infinity : y(for: segment.interval.end, in: size) - labelSpacing / 2
            if index > 0 {
                highest = max(highest, labelYs[index - 1] + labelSpacing)
            }
            if index + 1 < labelYs.count {
                lowest = min(lowest, labelYs[index + 1] - labelSpacing)
            }
            return PlacedPhase(
                segment: segment,
                labelY: labelY,
                slack: (min(highest, labelY) - labelY)...(max(lowest, labelY) - labelY)
            )
        }
    }

    /// Pushes ascending positions down as needed so neighbors sit at least `labelSpacing` apart.
    private func spaced(_ positions: [CGFloat]) -> [CGFloat] {
        var result: [CGFloat] = []
        for y in positions {
            if let previous = result.last, y - previous < labelSpacing {
                result.append(previous + labelSpacing)
            } else {
                result.append(y)
            }
        }
        return result
    }
}

#Preview {
    DayTimelineOverlay(day: .mock(), now: .now, safeAreaInsets: EdgeInsets())
        .frame(height: 24 * 72)
        .background(SkyGradient(day: .mock()))
}

//
//  DayTimelineOverlay.swift
//  Chromahora
//

import SwiftUI

/// Annotates the sky gradient: an hour ruler on the leading edge, sunrise,
/// sunset and "now" markers, and a label for each phase on the trailing edge.
struct DayTimelineOverlay: View {
    let day: SolarDay
    let now: Date

    private let horizontalPadding: CGFloat = 16

    /// Width of the darkened gutter behind the hour ruler, which keeps its
    /// white labels legible over the bright daylight band.
    private let rulerScrimWidth: CGFloat = 112

    /// Minimum vertical distance between neighboring labels on the same edge.
    /// Labels that would sit closer than this are pushed down; marker lines stay
    /// put. It leaves a gap wider than the glass container's merge distance, so
    /// stacked capsules stay separate.
    private let labelSpacing: CGFloat = 28

    /// Hour labels within this distance of a marker label are hidden so they don't collide.
    private let hourLabelClearance: CGFloat = 30

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

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let markers = placedMarkers(size: size)

            GlassEffectContainer(spacing: 4) {
                ZStack {
                    rulerScrim
                    hourRuler(size: size, avoiding: markers)
                    markerLayer(markers, size: size)
                    phaseLabels(size: size)
                }
                .frame(width: size.width, height: size.height)
            }
        }
    }

    // MARK: Layers

    private var rulerScrim: some View {
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
        .frame(width: rulerScrimWidth)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

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
                    .padding(.leading, horizontalPadding)
            }
        }
    }

    private func phaseLabels(size: CGSize) -> some View {
        let segments = day.segments
        let labelYs = spaced(segments.map { y(for: $0.midpoint, in: size) })

        return ForEach(Array(zip(segments, labelYs)), id: \.0.id) { segment, labelY in
            row(at: labelY, alignment: .trailing, size: size) {
                label(text(for: segment), glass: .regular.tint(segment.phase.color.opacity(0.5)))
                    .padding(.trailing, horizontalPadding)
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
        guard segment.phase != .night else { return segment.phase.title }
        let range = (segment.interval.start..<segment.interval.end)
            .formatted(date: .omitted, time: .shortened)
        return "\(segment.phase.title) · \(range)"
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
    @Previewable @State var selectedDate = Date.now
    NavigationStack {
        DayTimeline(day: .mock(for: selectedDate), now: .now, selectedDate: $selectedDate)
    }
}

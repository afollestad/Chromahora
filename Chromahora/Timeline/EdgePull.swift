//
//  EdgePull.swift
//  Chromahora
//

import SwiftUI

/// How far the timeline is pulled past one of its ends, and whether letting go there pages
/// to the day beyond it.
nonisolated struct EdgePull: Equatable, Sendable {
    /// Far enough into the rubber band that paging takes a deliberate push through its
    /// resistance, about 140 pt of finger travel on an 874 pt-tall screen, while a drag that
    /// only meets the end springs back.
    static let threshold: CGFloat = 72

    let edge: VerticalEdge
    /// How far past the end the content is pulled, in points on screen.
    let distance: CGFloat

    init(edge: VerticalEdge, distance: CGFloat) {
        self.edge = edge
        self.distance = distance
    }

    /// The pull a scroll offset makes, or nil while the content is within its bounds.
    init?(offset: CGFloat, contentHeight: CGFloat, containerHeight: CGFloat, insets: EdgeInsets) {
        let rest = Self.restingOffsets(contentHeight: contentHeight, containerHeight: containerHeight, insets: insets)
        if offset < rest.lowerBound {
            self.init(edge: .top, distance: rest.lowerBound - offset)
        } else if offset > rest.upperBound {
            self.init(edge: .bottom, distance: offset - rest.upperBound)
        } else {
            return nil
        }
    }

    init?(_ geometry: ScrollGeometry) {
        self.init(
            offset: geometry.contentOffset.y,
            contentHeight: geometry.contentSize.height,
            containerHeight: geometry.containerSize.height,
            insets: geometry.contentInsets
        )
    }

    /// Whether the content is at `edge` or pulled past it, within a point for rounding.
    static func isAt(_ edge: VerticalEdge, offset: CGFloat, contentHeight: CGFloat, containerHeight: CGFloat, insets: EdgeInsets) -> Bool {
        let rest = restingOffsets(contentHeight: contentHeight, containerHeight: containerHeight, insets: insets)
        return switch edge {
        case .top: offset <= rest.lowerBound + 1
        case .bottom: offset >= rest.upperBound - 1
        }
    }

    static func isAt(_ edge: VerticalEdge, in geometry: ScrollGeometry) -> Bool {
        isAt(
            edge,
            offset: geometry.contentOffset.y,
            contentHeight: geometry.contentSize.height,
            containerHeight: geometry.containerSize.height,
            insets: geometry.contentInsets
        )
    }

    /// The offsets the content rests at, from its top end to its bottom one. Content shorter
    /// than its container can't scroll, so both ends rest at the top.
    private static func restingOffsets(contentHeight: CGFloat, containerHeight: CGFloat, insets: EdgeInsets) -> ClosedRange<CGFloat> {
        let top = -insets.top
        return top...max(contentHeight + insets.bottom - containerHeight, top)
    }

    /// How close the pull is to arming, from 0 at the end to 1 at the threshold.
    var progress: CGFloat {
        min(distance / Self.threshold, 1)
    }

    var isArmed: Bool {
        distance >= Self.threshold
    }

    /// How many days the day beyond `edge` is from the one pulled: the day before past the top,
    /// and after past the bottom.
    static func dayOffset(beyond edge: VerticalEdge) -> Int {
        edge == .top ? -1 : 1
    }

    /// The start of the day beyond `edge` of `day`, in the day's own calendar.
    static func dayStart(beyond edge: VerticalEdge, of day: SolarDay) -> Date? {
        day.calendar.date(byAdding: .day, value: dayOffset(beyond: edge), to: day.dayStart)
    }
}

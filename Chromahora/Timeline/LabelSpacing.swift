//
//  LabelSpacing.swift
//  Chromahora
//

import CoreGraphics

/// Keeps a column of labels from overlapping. Pure layout, so the phone's timeline and the
/// watch's share it.
nonisolated enum LabelSpacing {
    /// Pushes ascending positions down as needed so neighbors sit at least `spacing` apart.
    /// A pinned position first lifts the unpinned ones right above it to make room, since a
    /// label off its line reads as marking another time, and one without a line has none to
    /// leave. They rise no higher than the pinned one above them allows, or than the top of
    /// the day, where the timeline leaves only enough room for a label centered on it.
    static func spaced(_ positions: [CGFloat], pinned: [Bool] = [], spacing: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        for (index, y) in positions.enumerated() {
            if pinned.indices.contains(index), pinned[index] {
                var start = result.endIndex
                while start > 0, !pinned[start - 1] {
                    start -= 1
                }
                let highest = start > 0 ? result[start - 1] + spacing : 0
                for lifted in start..<result.endIndex {
                    let wanted = y - CGFloat(result.endIndex - lifted) * spacing
                    let allowed = highest + CGFloat(lifted - start) * spacing
                    result[lifted] = min(result[lifted], max(wanted, allowed))
                }
            }
            if let previous = result.last, y - previous < spacing {
                result.append(previous + spacing)
            } else {
                result.append(y)
            }
        }
        return result
    }
}

//
//  TimelineFocus.swift
//  Chromahora
//

import Foundation

/// A request to scroll a timeline, as Today and the rows of the day's details make. Each gets a
/// new `id`, so asking for the same time again scrolls back to it.
struct TimelineFocus: Equatable {
    private(set) var id = 0
    /// The time to center on, or nil for the timeline's own focus time.
    private(set) var date: Date?

    mutating func request(_ date: Date? = nil) {
        id += 1
        self.date = date
    }
}

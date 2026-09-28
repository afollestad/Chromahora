//
//  DayTitle.swift
//  Chromahora
//

import Foundation

nonisolated extension Date {
    /// The day, as in "Monday, September 21", read in `timeZone` rather than the device's, so a
    /// place in another zone names the day its own calendar shows. `.dateTime` always reads the
    /// device's zone.
    func dayTitle(in timeZone: TimeZone) -> String {
        formatted(Date.FormatStyle(timeZone: timeZone).weekday(.wide).month(.wide).day())
    }
}

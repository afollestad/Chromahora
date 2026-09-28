//
//  EdgePullTests.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
@testable import Chromahora

struct EdgePullTests {
    /// A day of content in a phone-sized scroll view, which can scroll from 0 to 1000.
    private let contentHeight: CGFloat = 1874
    private let containerHeight: CGFloat = 874

    private func pull(at offset: CGFloat, insets: EdgeInsets = EdgeInsets()) -> EdgePull? {
        EdgePull(offset: offset, contentHeight: contentHeight, containerHeight: containerHeight, insets: insets)
    }

    @Test func noPullWithinTheContent() {
        #expect(pull(at: 0) == nil)
        #expect(pull(at: 500) == nil)
        #expect(pull(at: 1000) == nil)
    }

    @Test func pullsPastEitherEnd() {
        #expect(pull(at: -30) == EdgePull(edge: .top, distance: 30))
        #expect(pull(at: 1040) == EdgePull(edge: .bottom, distance: 40))
    }

    /// Insets move where each end rests: the top up by its inset, and the bottom down by its own.
    @Test func insetsMoveTheEnds() {
        let insets = EdgeInsets(top: 100, leading: 0, bottom: 50, trailing: 0)

        #expect(pull(at: -100, insets: insets) == nil)
        #expect(pull(at: -130, insets: insets) == EdgePull(edge: .top, distance: 30))
        #expect(pull(at: 1050, insets: insets) == nil)
        #expect(pull(at: 1090, insets: insets) == EdgePull(edge: .bottom, distance: 40))
    }

    /// Content shorter than its container can't scroll, so either way from rest is a pull.
    @Test func shortContentPullsFromRest() {
        let short = { (offset: CGFloat) in
            EdgePull(offset: offset, contentHeight: 400, containerHeight: 874, insets: EdgeInsets())
        }

        #expect(short(0) == nil)
        #expect(short(-20) == EdgePull(edge: .top, distance: 20))
        #expect(short(20) == EdgePull(edge: .bottom, distance: 20))
    }

    /// A drag pages only through an end it began at, where rounding can leave the offset a fraction off.
    @Test func tellsWhichEndTheContentIsAt() {
        let isAt = { (edge: VerticalEdge, offset: CGFloat) in
            EdgePull.isAt(edge, offset: offset, contentHeight: contentHeight, containerHeight: containerHeight, insets: EdgeInsets())
        }

        #expect(isAt(.top, 0))
        #expect(isAt(.top, 0.5))
        #expect(isAt(.top, -30))
        #expect(!isAt(.top, 2))
        #expect(isAt(.bottom, 1000))
        #expect(isAt(.bottom, 999.5))
        #expect(isAt(.bottom, 1040))
        #expect(!isAt(.bottom, 998))
        #expect(!isAt(.top, 500))
        #expect(!isAt(.bottom, 500))
    }

    @Test func armsAtTheThreshold() {
        let short = EdgePull(edge: .top, distance: EdgePull.threshold - 1)
        let armed = EdgePull(edge: .top, distance: EdgePull.threshold)
        let past = EdgePull(edge: .bottom, distance: EdgePull.threshold * 2)

        #expect(!short.isArmed)
        #expect(short.progress < 1)
        #expect(armed.isArmed)
        #expect(armed.progress == 1)
        #expect(past.isArmed)
        #expect(past.progress == 1)
    }

    /// November 1, 2026 is 25 hours long in Chicago, where daylight saving time ends.
    @Test func theDaysBeyondStartAtTheirMidnights() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        let longDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)))
        let day = SolarDay.mock(for: longDay, calendar: calendar)

        let before = try #require(EdgePull.dayStart(beyond: .top, of: day))
        let after = try #require(EdgePull.dayStart(beyond: .bottom, of: day))

        #expect(calendar.dateComponents([.month, .day, .hour], from: before) == DateComponents(month: 10, day: 31, hour: 0))
        #expect(calendar.dateComponents([.month, .day, .hour], from: after) == DateComponents(month: 11, day: 2, hour: 0))
        #expect(after.timeIntervalSince(day.dayStart) == 25 * 60 * 60)
    }
}

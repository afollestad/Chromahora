//
//  DayTimelineOverlayTests.swift
//  ChromahoraTests
//

import SwiftUI
import Testing
@testable import Chromahora

/// `DayTimelineOverlay` is a main-actor view.
@MainActor
struct DayTimelineOverlayTests {
    @Test func crowdedPositionsArePushedDown() {
        #expect(DayTimelineOverlay.spaced([0, 10, 50, 100], spacing: 28) == [0, 28, 56, 100])
    }

    @Test func pinnedPositionLiftsTheUnpinnedOneAboveIt() {
        #expect(DayTimelineOverlay.spaced([100, 110], pinned: [false, true], spacing: 28) == [82, 110])
    }

    @Test func pinnedPositionsPushEachOtherDown() {
        #expect(DayTimelineOverlay.spaced([100, 110], pinned: [true, true], spacing: 28) == [100, 128])
    }

    @Test func unpinnedPositionIsPushedBelowAPinnedOne() {
        #expect(DayTimelineOverlay.spaced([100, 110], pinned: [true, false], spacing: 28) == [100, 128])
    }

    @Test func liftedRunKeepsItsSpacing() {
        #expect(DayTimelineOverlay.spaced([100, 110, 120], pinned: [false, false, true], spacing: 28) == [64, 92, 120])
    }

    /// The label above the lifted one stays put, so the pinned one is pushed down by what's left.
    @Test func liftStopsAtAPinnedPosition() {
        #expect(DayTimelineOverlay.spaced([50, 90, 100], pinned: [true, false, true], spacing: 28) == [50, 78, 106])
    }

    @Test func liftStopsAtTheTopOfTheDay() {
        #expect(DayTimelineOverlay.spaced([0, 10], pinned: [false, true], spacing: 28) == [0, 28])
    }

    @Test func liftLeavesPositionsAlreadyClear() {
        #expect(DayTimelineOverlay.spaced([10, 100, 110], pinned: [false, false, true], spacing: 28) == [10, 82, 110])
    }
}

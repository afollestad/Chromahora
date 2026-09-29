//
//  SolarDayStoreTodayTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Following today past midnight, as a screen left open overnight must. Held requests are
/// awaited, so a regression that never makes one would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SolarDayStoreTodayTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Mid-afternoon, so a selected time is distinguishable from the start of its day.
    private let monday = Date(timeIntervalSince1970: 1_790_000_000)
    private var tuesday: Date { monday.addingTimeInterval(24 * 60 * 60) }
    private var wednesday: Date { monday.addingTimeInterval(2 * 24 * 60 * 60) }

    private let provider = StubSolarDayProvider()
    private let places = StubPlaceProvider()

    private func makeStore() -> SolarDayStore {
        SolarDayStore(provider: provider, placeProvider: places, calendar: calendar, selectedDate: monday)
    }

    private func dayStart(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    @Test func midnightMovesTodayToTheNextDay() async {
        let store = makeStore()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        store.advanceToToday(from: monday, to: tuesday)

        #expect(store.selectedDayStart == dayStart(tuesday))
        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))
    }

    @Test func midnightLeavesTheNextDayToLoadWhenItIsntHeld() async {
        let store = makeStore()
        await store.loadSelectedDay()

        store.advanceToToday(from: monday, to: tuesday)

        #expect(store.selectedDayStart == dayStart(tuesday))
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    /// A day the person paged to isn't today, so midnight leaves it.
    @Test func midnightKeepsADayPagedTo() {
        let store = makeStore()
        store.selectedDate = wednesday

        store.advanceToToday(from: monday, to: tuesday)

        #expect(store.selectedDayStart == dayStart(wednesday))
    }

    @Test func aTimeOnTheSameDayChangesNothing() {
        let store = makeStore()

        store.advanceToToday(from: monday, to: monday.addingTimeInterval(60 * 60))

        #expect(store.selectedDate == monday)
    }
}

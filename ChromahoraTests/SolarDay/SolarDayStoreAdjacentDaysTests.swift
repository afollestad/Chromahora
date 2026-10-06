//
//  SolarDayStoreAdjacentDaysTests.swift
//  ChromahoraTests
//

import Foundation
import Observation
import Testing
@testable import Chromahora

/// The days either side of the selected one: loading them, showing them before they're
/// selected, and paging to them. Held requests are awaited, so a regression that never makes
/// one would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SolarDayStoreAdjacentDaysTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Mid-afternoon, so a selected time is distinguishable from the start of its day.
    private let monday = Date(timeIntervalSince1970: 1_790_000_000)
    private var tuesday: Date { monday.addingTimeInterval(24 * 60 * 60) }
    private var sunday: Date { monday.addingTimeInterval(-24 * 60 * 60) }
    private var wednesday: Date { monday.addingTimeInterval(2 * 24 * 60 * 60) }

    private let provider = StubSolarDayProvider()
    private let places = StubPlaceProvider()

    private func makeStore() -> SolarDayStore {
        SolarDayStore(provider: provider, placeProvider: places, calendar: calendar, selectedDate: monday)
    }

    private func dayStart(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    @Test func theDaysEitherSideLoadAfterTheSelectedOne() async {
        let store = makeStore()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(sunday), dayStart(tuesday)])
    }

    @Test func heldDaysArentAskedForAgain() async {
        let store = makeStore()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()
        store.selectedDate = tuesday
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(sunday), dayStart(tuesday), dayStart(wednesday)])
    }

    /// A provider that failed the selected day isn't asked for more.
    @Test func theDaysEitherSideWaitForTheSelectedOne() async {
        let store = makeStore()
        await store.loadAdjacentDays()
        provider.error = StubError()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        #expect(provider.requestedDates == [dayStart(monday)])
    }

    @Test func pagingToAHeldDayShowsItAtOnce() async throws {
        let store = makeStore()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        #expect(store.selectDay(offsetBy: 1, from: try #require(store.state.day)))
        #expect(store.selectedDayStart == dayStart(tuesday))
        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))

        await store.loadSelectedDay()

        #expect(provider.requestedDates.count == 3)
        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))
    }

    @Test func pagingToADayNotHeldLeavesItToLoad() async throws {
        let store = makeStore()
        await store.loadSelectedDay()

        #expect(!store.selectDay(offsetBy: 1, from: try #require(store.state.day)))
        #expect(store.selectedDayStart == dayStart(tuesday))
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))

        await store.loadSelectedDay()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(tuesday)])
        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))
    }

    @Test func heldNeighborsShowWithoutBeingSelected() async throws {
        let store = makeStore()
        await store.loadSelectedDay()
        let shown = try #require(store.state.day)
        #expect(store.loadedDay(offsetBy: 1, from: shown) == nil)

        await store.loadAdjacentDays()

        #expect(store.loadedDay(offsetBy: -1, from: shown)?.dayStart == dayStart(sunday))
        #expect(store.loadedDay(offsetBy: 1, from: shown)?.dayStart == dayStart(tuesday))
        #expect(store.loadedDay(offsetBy: 2, from: shown) == nil)
        #expect(store.selectedDayStart == dayStart(monday))
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    /// The watch shows tomorrow through `loadedDay(offsetBy:from:)` before it's paged to, so it
    /// has to hear when `loadAdjacentDays()` brings it in.
    @Test func aNeighborArrivingIsObserved() async throws {
        let store = makeStore()
        await store.loadSelectedDay()
        let shown = try #require(store.state.day)
        let (changes, continuation) = AsyncStream.makeStream(of: Void.self)
        withObservationTracking {
            _ = store.loadedDay(offsetBy: 1, from: shown)
        } onChange: {
            continuation.yield()
        }

        await store.loadAdjacentDays()
        continuation.finish()

        var iterator = changes.makeAsyncIterator()
        let change: Void? = await iterator.next()
        #expect(change != nil)
    }

    /// Reykjavik keeps GMT's offset all year, so its days start when the held GMT ones do.
    @Test func daysHeldForAnotherZoneArentPagedTo() async throws {
        let store = makeStore()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()
        let shown = try #require(store.state.day)

        store.changeTimeZone(to: try #require(TimeZone(identifier: "Atlantic/Reykjavik")))

        #expect(store.loadedDay(offsetBy: 1, from: shown) == nil)
        #expect(!store.selectDay(offsetBy: 1, from: shown))
        #expect(store.state.isLoading)
    }

    /// GMT's Monday stays on screen while Los Angeles's loads. The midnights that start GMT's
    /// Tuesday and Sunday fall on Monday and Saturday there, so paging by their instants would
    /// stay put or skip a day.
    @Test func pagingGoesByTheDateOnScreenAfterAZoneChange() async throws {
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        var losAngelesCalendar = calendar
        losAngelesCalendar.timeZone = losAngeles
        let store = makeStore()
        await store.loadSelectedDay()
        let shown = try #require(store.state.day)

        store.changeTimeZone(to: losAngeles)

        #expect(!store.selectDay(offsetBy: 1, from: shown))
        #expect(losAngelesCalendar.dateComponents([.month, .day], from: store.selectedDayStart) == DateComponents(month: 9, day: 22))
        #expect(!store.selectDay(offsetBy: -1, from: shown))
        #expect(losAngelesCalendar.dateComponents([.month, .day], from: store.selectedDayStart) == DateComponents(month: 9, day: 20))
    }
}

//
//  SolarDayStoreTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Held requests are awaited, so a regression that never makes one would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SolarDayStoreTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Mid-afternoon, so a selected time is distinguishable from the start of its day.
    private let monday = Date(timeIntervalSince1970: 1_790_000_000)
    private var tuesday: Date { monday.addingTimeInterval(24 * 60 * 60) }

    private let provider = StubSolarDayProvider()

    private func makeStore() -> SolarDayStore {
        SolarDayStore(provider: provider, calendar: calendar, selectedDate: monday)
    }

    private func dayStart(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    @Test func loadsTheSelectedDayByItsStart() async {
        let store = makeStore()
        #expect(store.state.isLoading)
        #expect(store.state.day == nil)

        await store.loadSelectedDay()

        #expect(provider.requestedDates == [dayStart(monday)])
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    @Test func revisitedDaysComeFromTheCache() async {
        let store = makeStore()
        await store.loadSelectedDay()
        store.selectedDate = tuesday
        await store.loadSelectedDay()

        store.selectedDate = monday.addingTimeInterval(2 * 60 * 60)
        await store.loadSelectedDay()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(tuesday)])
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    @Test func failureShowsAndRetryRecovers() async {
        let store = makeStore()
        provider.error = StubError()
        await store.loadSelectedDay()
        #expect(store.state.failure is StubError)

        provider.error = nil
        await store.loadSelectedDay()

        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    @Test func keepsThePreviousDayOnScreenWhileTheNextLoads() async throws {
        let store = makeStore()
        await store.loadSelectedDay()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        store.selectedDate = tuesday
        let loading = Task { await store.loadSelectedDay() }
        let request = try #require(await requests.next())

        #expect(store.state.isLoading)
        #expect(store.state.day?.dayStart == dayStart(monday))

        request.answer()
        await loading.value

        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))
    }

    @Test func aLateResponseKeepsTheNewerSelectionAndIsCached() async throws {
        let store = makeStore()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loadingMonday = Task { await store.loadSelectedDay() }
        let mondayRequest = try #require(await requests.next())
        store.selectedDate = tuesday
        let loadingTuesday = Task { await store.loadSelectedDay() }
        let tuesdayRequest = try #require(await requests.next())

        tuesdayRequest.answer()
        await loadingTuesday.value
        mondayRequest.answer()
        await loadingMonday.value

        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))

        provider.holdsResponses = false
        store.selectedDate = monday
        await store.loadSelectedDay()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(tuesday)])
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    @Test func aLateFailureKeepsTheNewerSelection() async throws {
        let store = makeStore()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loadingMonday = Task { await store.loadSelectedDay() }
        let mondayRequest = try #require(await requests.next())
        store.selectedDate = tuesday
        let loadingTuesday = Task { await store.loadSelectedDay() }
        let tuesdayRequest = try #require(await requests.next())

        tuesdayRequest.answer()
        await loadingTuesday.value
        mondayRequest.fail(with: StubError())
        await loadingMonday.value

        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))
    }

    @Test func aCancelledLoadReportsNoFailure() async throws {
        let store = makeStore()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loading = Task { await store.loadSelectedDay() }
        let request = try #require(await requests.next())
        loading.cancel()
        request.fail(with: CancellationError())
        await loading.value

        #expect(store.state.isLoading)
    }
}

private extension SolarDayStore.LoadState {
    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    var loadedDay: SolarDay? {
        if case .loaded(let day) = self { day } else { nil }
    }

    var failure: (any Error)? {
        if case .failed(let error) = self { error } else { nil }
    }
}

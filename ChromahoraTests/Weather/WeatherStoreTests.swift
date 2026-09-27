//
//  WeatherStoreTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Held requests are awaited, so a regression that never makes one would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WeatherStoreTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Mid-afternoon, so the window's start is distinguishable from now.
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let provider = StubWeatherProvider()
    private let chicago = Place(latitude: 41.85, longitude: -87.65, source: .device)
    private let sanFrancisco = MockPlaceProvider.sanFrancisco

    private var mock: [WeatherSpell] {
        WeatherSpell.mock(for: now, calendar: calendar)
    }

    private func makeStore() -> WeatherStore {
        WeatherStore(provider: provider, calendar: calendar)
    }

    @Test func loadsTenDaysFromTheStartOfToday() async throws {
        provider.spells = mock
        let store = makeStore()

        await store.load(at: chicago, now: now)

        let start = calendar.startOfDay(for: now)
        let end = try #require(calendar.date(byAdding: .day, value: 10, to: start))
        #expect(provider.requestedWindows == [DateInterval(start: start, end: end)])
        #expect(provider.requestedPlaces == [chicago])
        #expect(store.spells == mock)
    }

    @Test func withoutAPlaceNothingLoads() async {
        let store = makeStore()

        await store.load(at: nil, now: now)

        #expect(provider.requestedPlaces.isEmpty)
        #expect(store.spells.isEmpty)
    }

    /// Weather only adds to the timeline, so a failure, like a spent quota, keeps what's shown.
    @Test func aFailureKeepsTheLastSpells() async {
        provider.spells = mock
        let store = makeStore()
        await store.load(at: chicago, now: now)

        provider.error = StubError()
        await store.load(at: chicago, now: now)

        #expect(store.spells == mock)
    }

    @Test func aNewPlaceClearsTheSpellsAtOnce() async throws {
        provider.spells = mock
        let store = makeStore()
        await store.load(at: chicago, now: now)
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loading = Task { await store.load(at: sanFrancisco, now: now) }
        let request = try #require(await requests.next())

        #expect(store.spells.isEmpty)
        request.answer(mock)
        await loading.value
        #expect(store.spells == mock)
    }

    /// A relocation while a load is out: the old place's late answer isn't shown.
    @Test func aStalePlacesAnswerIsDropped() async throws {
        let store = makeStore()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loadingOld = Task { await store.load(at: chicago, now: now) }
        let oldRequest = try #require(await requests.next())
        let loadingNew = Task { await store.load(at: sanFrancisco, now: now) }
        let newRequest = try #require(await requests.next())

        let newSpells = Array(mock.prefix(1))
        newRequest.answer(newSpells)
        await loadingNew.value
        oldRequest.answer(mock)
        await loadingOld.value

        #expect(store.spells == newSpells)
    }
}

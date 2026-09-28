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

    private var mock: Forecast {
        Forecast(spells: WeatherSpell.mock(for: now, calendar: calendar), hours: SkyHour.mock(for: now, calendar: calendar))
    }

    private func makeStore() -> WeatherStore {
        WeatherStore(provider: provider)
    }

    @Test func loadsTenDaysFromTheStartOfToday() async throws {
        provider.forecast = mock
        let store = makeStore()

        await store.load(at: chicago, now: now, calendar: calendar)

        let start = calendar.startOfDay(for: now)
        let end = try #require(calendar.date(byAdding: .day, value: 10, to: start))
        #expect(provider.requestedWindows == [DateInterval(start: start, end: end)])
        #expect(provider.requestedPlaces == [chicago])
        #expect(store.spells(at: chicago) == mock.spells)
        #expect(store.hours(at: chicago) == mock.hours)
    }

    @Test func withoutAPlaceNothingLoads() async {
        let store = makeStore()

        await store.load(at: nil, now: now, calendar: calendar)

        #expect(provider.requestedPlaces.isEmpty)
        #expect(store.spells(at: nil).isEmpty)
        #expect(store.hours(at: nil).isEmpty)
    }

    /// A time zone change moves the day store's place before weather can follow.
    @Test func theForecastOnlyShowsForItsPlace() async {
        provider.forecast = mock
        let store = makeStore()
        await store.load(at: chicago, now: now, calendar: calendar)

        #expect(store.spells(at: chicago) == mock.spells)
        #expect(store.spells(at: sanFrancisco).isEmpty)
        #expect(store.spells(at: nil).isEmpty)
        #expect(store.hours(at: chicago) == mock.hours)
        #expect(store.hours(at: sanFrancisco).isEmpty)
    }

    /// Weather only adds to the timeline, so a failure, like a spent quota, keeps what's shown.
    @Test func aFailureKeepsTheLastSpells() async {
        provider.forecast = mock
        let store = makeStore()
        await store.load(at: chicago, now: now, calendar: calendar)

        provider.error = StubError()
        await store.load(at: chicago, now: now, calendar: calendar)

        #expect(store.spells(at: chicago) == mock.spells)
        #expect(store.hours(at: chicago) == mock.hours)
    }

    @Test func aNewPlaceClearsTheForecastAtOnce() async throws {
        provider.forecast = mock
        let store = makeStore()
        await store.load(at: chicago, now: now, calendar: calendar)
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loading = Task { await store.load(at: sanFrancisco, now: now, calendar: calendar) }
        let request = try #require(await requests.next())

        #expect(store.spells(at: sanFrancisco).isEmpty)
        #expect(store.hours(at: sanFrancisco).isEmpty)
        request.answer(mock)
        await loading.value
        #expect(store.spells(at: sanFrancisco) == mock.spells)
    }

    /// A relocation while a load is out: the old place's late answer isn't shown.
    @Test func aStalePlacesAnswerIsDropped() async throws {
        let store = makeStore()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loadingOld = Task { await store.load(at: chicago, now: now, calendar: calendar) }
        let oldRequest = try #require(await requests.next())
        let loadingNew = Task { await store.load(at: sanFrancisco, now: now, calendar: calendar) }
        let newRequest = try #require(await requests.next())

        let newForecast = Forecast(spells: Array(mock.spells.prefix(1)), hours: Array(mock.hours.prefix(1)))
        newRequest.answer(newForecast)
        await loadingNew.value
        oldRequest.answer(mock)
        await loadingOld.value

        #expect(store.spells(at: sanFrancisco) == newForecast.spells)
        #expect(store.hours(at: sanFrancisco) == newForecast.hours)
    }
}

//
//  CachedForecastProviderTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Each test writes to its own temporary directory.
struct CachedForecastProviderTests {
    private let temporary = TemporaryDirectory("CachedForecastProviderTests")
    private var cache: ForecastCache {
        ForecastCache(directory: temporary.url)
    }
    private let place = Place(latitude: 41.82, longitude: -87.62, source: .device)
    private let start = Date(timeIntervalSince1970: 1_790_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private var forecast: Forecast {
        Forecast(spells: WeatherSpell.mock(for: start), hours: SkyHour.mock(for: start))
    }

    private func record(at place: Place, from windowStart: Date, forecast: Forecast?) -> ForecastRecord {
        ForecastRecord(
            key: ForecastKey(place: place, start: windowStart, end: windowStart.addingTimeInterval(10 * day)),
            attemptedAt: windowStart,
            forecast: forecast
        )
    }

    /// Past midnight a complication asks for a window starting a day later than the app's last
    /// request, which still reaches the hours ahead.
    @Test func itAnswersFromThePlacesLastForecastWhateverItsWindow() async throws {
        await cache.store(record(at: place, from: start, forecast: forecast))
        let provider = CachedForecastProvider(cache: cache)

        let answer = try await provider.forecast(from: start.addingTimeInterval(day), to: start.addingTimeInterval(11 * day), at: place)

        #expect(answer == forecast)
    }

    /// The place's coordinates round to tenths, as a forecast's key does, so a fix that moved a
    /// few meters still finds it.
    @Test func aNearbyFixFindsThePlacesForecast() async throws {
        await cache.store(record(at: place, from: start, forecast: forecast))
        let nearby = Place(latitude: 41.8203, longitude: -87.6201, source: .device)

        let answer = try await CachedForecastProvider(cache: cache).forecast(from: start, to: start.addingTimeInterval(day), at: nearby)

        #expect(answer == forecast)
    }

    @Test func anotherPlaceHasNoForecast() async {
        await cache.store(record(at: place, from: start, forecast: forecast))
        let elsewhere = Place(latitude: 37.8, longitude: -122.4, source: .device)

        await #expect(throws: CachedForecastProvider.NoForecast.self) {
            try await CachedForecastProvider(cache: cache).forecast(from: start, to: start.addingTimeInterval(day), at: elsewhere)
        }
    }

    /// A request still out, or one that failed, leaves nothing to give, and an empty cache stays
    /// empty, since the provider never writes.
    @Test func aRecordWithoutAnAnswerOrNoneAtAllHasNoForecast() async {
        let provider = CachedForecastProvider(cache: cache)
        await #expect(throws: CachedForecastProvider.NoForecast.self) {
            try await provider.forecast(from: start, to: start.addingTimeInterval(day), at: place)
        }
        #expect(await cache.latestRecord() == nil)

        await cache.store(record(at: place, from: start, forecast: nil))
        await #expect(throws: CachedForecastProvider.NoForecast.self) {
            try await provider.forecast(from: start, to: start.addingTimeInterval(day), at: place)
        }
    }
}

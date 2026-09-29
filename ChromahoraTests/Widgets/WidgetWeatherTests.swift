//
//  WidgetWeatherTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Each test writes to its own temporary directory.
@MainActor
struct WidgetWeatherTests {
    private let base = StubWeatherProvider()
    private let directory = TemporaryDirectory("WidgetWeatherTests")
    private let place = Place(latitude: 41.85, longitude: -87.65, source: .device)
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private var end: Date {
        now.addingTimeInterval(10 * 24 * 60 * 60)
    }

    private var key: ForecastKey {
        ForecastKey(place: place, start: now, end: end)
    }

    private var mock: Forecast {
        Forecast(spells: WeatherSpell.mock(for: now), hours: SkyHour.mock(for: now))
    }

    private var appCache: ForecastCache {
        ForecastCache(directory: directory.url)
    }

    private var widgetCache: ForecastCache {
        ForecastCache(directory: directory.url, fileName: WidgetWeather.cacheFileName, retention: WidgetWeather.interval)
    }

    /// `patience` never passes by default: it's cancelled once the request answers.
    private func ask(
        sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in try await Task.sleep(for: .seconds(3600)) }
    ) async throws -> Forecast {
        let weather = WidgetWeather(base: base, directory: directory.url, now: { [now] in now }, sleep: sleep)
        return try await weather.forecast(from: now, to: end, at: place)
    }

    @Test func theAppsRecentForecastAnswersWithoutARequest() async throws {
        await appCache.store(ForecastRecord(key: key, attemptedAt: now.addingTimeInterval(-WidgetWeather.interval + 60), forecast: mock))

        #expect(try await ask() == mock)
        #expect(base.requestedPlaces.isEmpty)
    }

    @Test func aStaleForecastIsAskedForAgain() async throws {
        await appCache.store(ForecastRecord(key: key, attemptedAt: now.addingTimeInterval(-WidgetWeather.interval), forecast: Forecast()))
        base.forecast = mock

        #expect(try await ask() == mock)
        #expect(base.requestedPlaces == [place])
    }

    @Test func theNewerOfTheTwoAnswers() async throws {
        await appCache.store(ForecastRecord(key: key, attemptedAt: now.addingTimeInterval(-2 * 60 * 60), forecast: Forecast()))
        await widgetCache.store(ForecastRecord(key: key, attemptedAt: now.addingTimeInterval(-60 * 60), forecast: mock))

        #expect(try await ask() == mock)
        #expect(base.requestedPlaces.isEmpty)
    }

    /// Asking replaces the widgets' own answer, so a failure falls back to the last one for the
    /// window, as the app keeps what it shows.
    @Test func aFailureKeepsTheLastAnswerForTheWindow() async throws {
        await widgetCache.store(ForecastRecord(key: key, attemptedAt: now.addingTimeInterval(-WidgetWeather.interval), forecast: mock))
        base.error = StubError()

        #expect(try await ask() == mock)
        #expect(await widgetCache.record(for: key)?.forecast == nil)
    }

    /// A request slower than `patience` leaves the last answer, and goes on to store its own.
    @Test func aSlowRequestLeavesTheLastAnswer() async throws {
        await appCache.store(ForecastRecord(key: key, attemptedAt: now.addingTimeInterval(-WidgetWeather.interval), forecast: mock))
        base.holdsResponses = true

        #expect(try await ask { _ in } == mock)

        var requests = base.heldRequests.makeAsyncIterator()
        await requests.next()?.answer(Forecast())
    }

    /// The widgets' failure throttles them alone, so the app still asks on its next visit.
    @Test func aFailureLeavesTheAppsRecordAlone() async throws {
        base.error = StubError()

        await #expect(throws: StubError.self) {
            try await ask()
        }

        #expect(await appCache.record(for: key) == nil)
        #expect(await widgetCache.record(for: key)?.forecast == nil)
        #expect(await widgetCache.record(for: key) != nil)
    }
}

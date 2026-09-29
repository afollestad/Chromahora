//
//  ThrottledWeatherProviderTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Held requests are awaited, so a regression that never makes one would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ThrottledWeatherProviderTests {
    /// The provider's clock, which tests move by hand.
    private final class ManualClock {
        var now: Date

        init(_ now: Date) {
            self.now = now
        }
    }

    private let base = StubWeatherProvider()
    private let directory = TemporaryDirectory("ThrottledWeatherProviderTests")
    private let cache: ForecastCache
    private let place = Place(latitude: 41.85, longitude: -87.65, source: .device)
    private let start = Date(timeIntervalSince1970: 1_790_000_000)
    private let clock = ManualClock(Date(timeIntervalSince1970: 1_790_000_000))

    init() {
        cache = ForecastCache(directory: directory.url)
    }

    private var end: Date {
        start.addingTimeInterval(10 * 24 * 60 * 60)
    }

    private var mock: Forecast {
        Forecast(spells: WeatherSpell.mock(for: start), hours: SkyHour.mock(for: start))
    }

    private func makeProvider(interval: TimeInterval = ThrottledWeatherProvider.minimumInterval) -> ThrottledWeatherProvider {
        ThrottledWeatherProvider(base: base, cache: cache, interval: interval) { [clock] in clock.now }
    }

    private func ask(_ provider: ThrottledWeatherProvider, at place: Place? = nil, from start: Date? = nil) async throws -> Forecast {
        let start = start ?? self.start
        return try await provider.forecast(from: start, to: start.addingTimeInterval(10 * 24 * 60 * 60), at: place ?? self.place)
    }

    @Test func anAnswerIsReusedWithinTheInterval() async throws {
        base.forecast = mock
        let provider = makeProvider()
        _ = try await ask(provider)

        clock.now = start.addingTimeInterval(ThrottledWeatherProvider.minimumInterval - 1)
        let forecast = try await ask(provider)

        #expect(forecast == base.forecast)
        #expect(base.requestedPlaces == [place])
    }

    @Test func itAsksAgainOnceTheIntervalPasses() async throws {
        let provider = makeProvider()
        _ = try await ask(provider)

        clock.now = start.addingTimeInterval(ThrottledWeatherProvider.minimumInterval)
        _ = try await ask(provider)

        #expect(base.requestedPlaces == [place, place])
    }

    /// The widgets wait longer between requests than the app.
    @Test func aLongerIntervalHoldsLonger() async throws {
        let interval = 3 * ThrottledWeatherProvider.minimumInterval
        let provider = makeProvider(interval: interval)
        _ = try await ask(provider)

        clock.now = start.addingTimeInterval(interval - 1)
        _ = try await ask(provider)
        #expect(base.requestedPlaces == [place])

        clock.now = start.addingTimeInterval(interval)
        _ = try await ask(provider)
        #expect(base.requestedPlaces == [place, place])
    }

    @Test func anotherPlaceOrWindowAsksAgain() async throws {
        let provider = makeProvider()
        let sanFrancisco = MockPlaceProvider.sanFrancisco
        let tomorrow = start.addingTimeInterval(24 * 60 * 60)

        _ = try await ask(provider)
        _ = try await ask(provider, at: sanFrancisco)
        _ = try await ask(provider, at: sanFrancisco, from: tomorrow)

        #expect(base.requestedPlaces == [place, sanFrancisco, sanFrancisco])
        #expect(base.requestedWindows.map(\.start) == [start, start, tomorrow])
    }

    /// A spent quota, or any other failure, waits out the interval too, so a rejected app
    /// asks once an hour rather than on every launch.
    @Test func aFailureWaitsOutTheInterval() async throws {
        let provider = makeProvider()
        base.error = StubError()
        await #expect(throws: StubError.self) {
            try await ask(provider)
        }

        base.error = nil
        await #expect(throws: ForecastThrottled()) {
            try await ask(provider)
        }
        #expect(base.requestedPlaces == [place])

        clock.now = start.addingTimeInterval(ThrottledWeatherProvider.minimumInterval)
        _ = try await ask(provider)
        #expect(base.requestedPlaces == [place, place])
    }

    /// A small correction reuses the answer, but a clock set back an interval or more asks
    /// again, rather than holding a failure's wait for hours.
    @Test func aClockSetBackFarAsksAgain() async throws {
        let provider = makeProvider()
        _ = try await ask(provider)

        clock.now = start.addingTimeInterval(-60)
        _ = try await ask(provider)
        #expect(base.requestedPlaces == [place])

        clock.now = start.addingTimeInterval(-ThrottledWeatherProvider.minimumInterval)
        _ = try await ask(provider)
        #expect(base.requestedPlaces == [place, place])
    }

    /// A relaunch makes a new provider, which reads the last request from disk.
    @Test func aNewProviderReusesTheStoredAnswer() async throws {
        base.forecast = mock
        _ = try await ask(makeProvider())

        let forecast = try await ask(makeProvider())

        #expect(forecast == base.forecast)
        #expect(base.requestedPlaces == [place])
    }

    /// Both requests start before WeatherKit answers, so the second can only join the first.
    @Test func concurrentRequestsShareOneCall() async throws {
        let provider = makeProvider()
        base.holdsResponses = true
        var requests = base.heldRequests.makeAsyncIterator()

        let first = Task { try await ask(provider) }
        let second = Task { try await ask(provider) }
        try #require(await requests.next()).answer(mock)

        #expect(try await first.value == mock)
        #expect(try await second.value == mock)
        #expect(base.requestedPlaces == [place])
    }

    /// Switching to another place and back within the interval asks for each only once.
    @Test func alternatingPlacesAsksForEachOnce() async throws {
        let provider = makeProvider()
        let sanFrancisco = MockPlaceProvider.sanFrancisco

        _ = try await ask(provider)
        _ = try await ask(provider, at: sanFrancisco)
        _ = try await ask(provider)
        _ = try await ask(provider, at: sanFrancisco)

        #expect(base.requestedPlaces == [place, sanFrancisco])
    }

    /// A place asked for again while its request is out joins it, even after another place was
    /// asked for in between, rather than reading its own unanswered attempt as a failure. Both
    /// later requests start before the test waits for San Francisco's, so the repeat reaches the
    /// throttle while Chicago's is still out.
    @Test func returningToAPlaceWhoseRequestIsOutJoinsIt() async throws {
        let provider = makeProvider()
        let sanFrancisco = MockPlaceProvider.sanFrancisco
        base.holdsResponses = true
        var requests = base.heldRequests.makeAsyncIterator()

        let first = Task { try await ask(provider) }
        let held = try #require(await requests.next())
        let other = Task { try await ask(provider, at: sanFrancisco) }
        let again = Task { try await ask(provider) }
        let otherHeld = try #require(await requests.next())
        held.answer(mock)
        otherHeld.answer(Forecast())

        #expect(try await first.value == mock)
        #expect(try await again.value == mock)
        #expect(try await other.value == Forecast())
        #expect(base.requestedPlaces == [place, sanFrancisco])
    }
}

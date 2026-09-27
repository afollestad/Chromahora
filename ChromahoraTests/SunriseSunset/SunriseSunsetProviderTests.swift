//
//  SunriseSunsetProviderTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Held requests are awaited, so a regression that never makes one would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SunriseSunsetProviderTests {
    private let fetcher = StubSunriseSunsetFetcher()
    private let cache = SolarDayCache(
        directory: URL.temporaryDirectory.appending(path: "SunriseSunsetProviderTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    )
    private let place = Place(latitude: 41.85, longitude: -87.65, source: .device)
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
        return calendar
    }()

    private func makeProvider() -> SunriseSunsetProvider {
        SunriseSunsetProvider(fetcher: fetcher, cache: cache)
    }

    private func date(month: Int, day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)))
    }

    private func month(_ month: Int) -> CalendarMonth {
        CalendarMonth(year: 2026, month: month, timeZone: calendar.timeZone)
    }

    @Test func aCachedMonthIsntFetched() async throws {
        for month in [month(9), month(10)] {
            try await cache.store(StubSunriseSunsetFetcher.daylight(through: month), for: SolarMonthKey(place: place, month: month))
        }
        let provider = makeProvider()

        let day = try await provider.solarDay(for: try date(month: 9, day: 26), at: place, calendar: calendar)
        await provider.lastPrefetch?.value

        #expect(day.dayStart == calendar.startOfDay(for: try date(month: 9, day: 26)))
        #expect(fetcher.requestedMonths.isEmpty)
    }

    @Test func aMissIsFetchedOnceAndStored() async throws {
        let provider = makeProvider()
        _ = try await provider.solarDay(for: try date(month: 9, day: 26), at: place, calendar: calendar)
        _ = try await provider.solarDay(for: try date(month: 9, day: 27), at: place, calendar: calendar)
        await provider.lastPrefetch?.value

        #expect(fetcher.requestedMonths == [month(9), month(10)])
        #expect(await cache.records(for: SolarMonthKey(place: place, month: month(9))) != nil)
    }

    /// Both requests start before the fetch answers, so the second can only join it.
    @Test func requestsInOneMonthShareAFetch() async throws {
        let provider = makeProvider()
        fetcher.holdsResponses = true
        var requests = fetcher.heldRequests.makeAsyncIterator()

        let first = Task { try await provider.solarDay(for: try date(month: 9, day: 26), at: place, calendar: calendar) }
        let second = Task { try await provider.solarDay(for: try date(month: 9, day: 27), at: place, calendar: calendar) }
        let request = try #require(await requests.next())
        request.answer()
        _ = try await first.value
        _ = try await second.value
        // The prefetch of October is held too; answer it so the task finishes.
        try #require(await requests.next()).answer()
        await provider.lastPrefetch?.value

        #expect(fetcher.requestedMonths == [month(9), month(10)])
    }

    @Test func aFailedFetchIsTriedAgain() async throws {
        let provider = makeProvider()
        fetcher.error = SunriseSunsetError.badResponse(status: 500)
        await #expect(throws: SunriseSunsetError.badResponse(status: 500)) {
            try await provider.solarDay(for: try date(month: 9, day: 26), at: place, calendar: calendar)
        }

        fetcher.error = nil
        _ = try await provider.solarDay(for: try date(month: 9, day: 26), at: place, calendar: calendar)
        await provider.lastPrefetch?.value

        #expect(fetcher.requestedMonths == [month(9), month(9), month(10)])
    }

    @Test func aRateLimitedFetchPrefetchesNothing() async throws {
        let provider = makeProvider()
        fetcher.error = SunriseSunsetError.rateLimited(retryAfter: 30)

        await #expect(throws: SunriseSunsetError.rateLimited(retryAfter: 30)) {
            try await provider.solarDay(for: try date(month: 9, day: 26), at: place, calendar: calendar)
        }

        #expect(provider.lastPrefetch == nil)
        #expect(fetcher.requestedMonths == [month(9)])
    }

    @Test func aDayMissingFromTheMonthThrows() async throws {
        let provider = makeProvider()
        fetcher.omittedDays = ["2026-09-26"]

        await #expect(throws: SunriseSunsetError.missingDay) {
            try await provider.solarDay(for: try date(month: 9, day: 26), at: place, calendar: calendar)
        }
    }
}

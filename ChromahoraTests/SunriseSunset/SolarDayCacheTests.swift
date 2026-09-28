//
//  SolarDayCacheTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Each test writes to its own temporary directory.
struct SolarDayCacheTests {
    private let temporary = TemporaryDirectory("SolarDayCacheTests")
    private var directory: URL {
        temporary.url
    }
    private let place = Place(latitude: 41.85, longitude: -87.65, source: .device)
    private let chicago = TimeZone(identifier: "America/Chicago") ?? .gmt

    private func key(month: Int) -> SolarMonthKey {
        SolarMonthKey(place: place, month: CalendarMonth(year: 2026, month: month, timeZone: chicago))
    }

    @Test func storedMonthsReadBack() async throws {
        let cache = SolarDayCache(directory: directory)
        let records = StubSunriseSunsetFetcher.daylight(through: key(month: 9).month)

        #expect(await cache.records(for: key(month: 9)) == nil)
        try await cache.store(records, for: key(month: 9))

        #expect(await cache.records(for: key(month: 9)) == records)
        #expect(await cache.records(for: key(month: 10)) == nil)
    }

    @Test func summaryCountsMonthsAndRemoveAllEmptiesIt() async throws {
        let cache = SolarDayCache(directory: directory)
        try await cache.store(StubSunriseSunsetFetcher.daylight(through: key(month: 9).month), for: key(month: 9))
        try await cache.store(StubSunriseSunsetFetcher.daylight(through: key(month: 10).month), for: key(month: 10))

        let summary = await cache.summary()
        #expect(summary.fileNames.count == 2)
        #expect(summary.byteCount > 0)

        await cache.removeAll()
        #expect(await cache.summary().fileNames.isEmpty)
    }

    /// With now in mid-September, August is last month and stays, while July goes, as does
    /// any file from another format version.
    @Test func pruneKeepsLastMonthOnward() async throws {
        let cache = SolarDayCache(directory: directory)
        for month in [7, 8, 9, 10] {
            try await cache.store(StubSunriseSunsetFetcher.daylight(through: key(month: month).month), for: key(month: month))
        }
        let oldFormat = directory.appending(path: "v1_2026-09_419_-877_America-Chicago.json")
        try Data("[]".utf8).write(to: oldFormat)
        let now = try #require(CalendarMonth.gregorian(in: .gmt).date(from: DateComponents(year: 2026, month: 9, day: 15)))

        await cache.prune(now: now)

        #expect(await cache.records(for: key(month: 7)) == nil)
        #expect(await cache.records(for: key(month: 8)) != nil)
        #expect(await cache.records(for: key(month: 9)) != nil)
        #expect(await cache.records(for: key(month: 10)) != nil)
        #expect(!FileManager.default.fileExists(atPath: oldFormat.path(percentEncoded: false)))
    }
}

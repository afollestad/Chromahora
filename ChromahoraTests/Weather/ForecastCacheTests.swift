//
//  ForecastCacheTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Each test writes to its own temporary directory.
struct ForecastCacheTests {
    private let temporary = TemporaryDirectory("ForecastCacheTests")
    private var directory: URL {
        temporary.url
    }
    private let place = Place(latitude: 41.85, longitude: -87.65, source: .device)
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private var record: ForecastRecord {
        ForecastRecord(
            key: ForecastKey(place: place, start: start, end: start.addingTimeInterval(10 * 24 * 60 * 60)),
            attemptedAt: start,
            forecast: Forecast(spells: WeatherSpell.mock(for: start), hours: SkyHour.mock(for: start))
        )
    }

    /// A relaunch makes a new cache, which reads the same file.
    @Test func aStoredRecordReadsBack() async {
        let cache = ForecastCache(directory: directory)
        #expect(await cache.record() == nil)

        await cache.store(record)

        #expect(await cache.record() == record)
        #expect(await ForecastCache(directory: directory).record() == record)
    }

    @Test func anUnreadableFileReadsAsNoRecord() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: directory.appending(path: "Forecast.json"))

        #expect(await ForecastCache(directory: directory).record() == nil)
    }

    /// A record from before `formatVersion`, whose missing answer would otherwise decode as a
    /// failed request and hold the next one back for an interval.
    @Test func aRecordInAnOlderShapeReadsAsNoRecord() async throws {
        let cache = ForecastCache(directory: directory)
        await cache.store(record)
        let file = directory.appending(path: "Forecast.json")
        var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        json["formatVersion"] = nil
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        #expect(await cache.record() == nil)

        // The rewrite alone doesn't spoil the record: with the version back, it reads.
        json["formatVersion"] = ForecastRecord.formatVersion
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        #expect(await cache.record() == record)
    }

    @Test func removeAllForgetsTheRecord() async {
        let cache = ForecastCache(directory: directory)
        await cache.store(record)

        await cache.removeAll()

        #expect(await cache.record() == nil)
    }
}

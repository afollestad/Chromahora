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
    private let otherPlace = Place(latitude: 37.8, longitude: -122.4, source: .device)
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private var record: ForecastRecord {
        record(at: place)
    }

    private func record(at place: Place, attemptedAt: Date? = nil) -> ForecastRecord {
        ForecastRecord(
            key: ForecastKey(place: place, start: start, end: start.addingTimeInterval(10 * 24 * 60 * 60)),
            attemptedAt: attemptedAt ?? start,
            forecast: Forecast(spells: WeatherSpell.mock(for: start), hours: SkyHour.mock(for: start))
        )
    }

    /// A relaunch makes a new cache, which reads the same file.
    @Test func aStoredRecordReadsBack() async {
        let cache = ForecastCache(directory: directory)
        #expect(await cache.record(for: record.key) == nil)

        await cache.store(record)

        #expect(await cache.record(for: record.key) == record)
        #expect(await ForecastCache(directory: directory).record(for: record.key) == record)
    }

    /// The widgets keep their own file, so neither side's attempts hold back the other's.
    @Test func cachesWithOtherFilesKeepTheirOwnRecords() async {
        let app = ForecastCache(directory: directory)
        let widgets = ForecastCache(directory: directory, fileName: "WidgetForecast.json")

        await widgets.store(record)

        #expect(await widgets.record(for: record.key) == record)
        #expect(await app.record(for: record.key) == nil)
    }

    /// Switching between places keeps each one's answer, so returning to one asks nothing.
    @Test func recordsForTwoPlacesReadBack() async {
        let cache = ForecastCache(directory: directory)
        let other = record(at: otherPlace, attemptedAt: start.addingTimeInterval(60))

        await cache.store(record)
        await cache.store(other)

        let relaunched = ForecastCache(directory: directory)
        #expect(await relaunched.record(for: record.key) == record)
        #expect(await relaunched.record(for: other.key) == other)
        #expect(await relaunched.latestRecord() == other)
    }

    /// The answer to a request replaces the attempt stored before it.
    @Test func aRecordReplacesTheOneForItsKey() async {
        let cache = ForecastCache(directory: directory)
        let attempt = ForecastRecord(key: record.key, attemptedAt: start, forecast: nil)

        await cache.store(attempt)
        await cache.store(record)

        #expect(await cache.record(for: record.key) == record)
    }

    /// Past midnight a place's forecast starts a day later, and its last window is never asked for again.
    @Test func aNewWindowReplacesAPlacesLastOne() async {
        let cache = ForecastCache(directory: directory)
        let tomorrow = start.addingTimeInterval(24 * 60 * 60)
        let next = ForecastRecord(
            key: ForecastKey(place: place, start: tomorrow, end: tomorrow.addingTimeInterval(10 * 24 * 60 * 60)),
            attemptedAt: start.addingTimeInterval(60),
            forecast: nil
        )

        await cache.store(record)
        await cache.store(next)

        #expect(await cache.record(for: record.key) == nil)
        #expect(await cache.record(for: next.key) == next)
    }

    /// A record an interval away from the newest would be asked again anyway, on either side of it.
    @Test func recordsTooFarFromTheNewestAreDropped() async {
        let cache = ForecastCache(directory: directory, retention: 60 * 60)
        let old = record(at: place, attemptedAt: start)
        let new = record(at: otherPlace, attemptedAt: start.addingTimeInterval(60 * 60))

        await cache.store(old)
        await cache.store(new)

        #expect(await cache.record(for: old.key) == nil)
        #expect(await cache.record(for: new.key) == new)
    }

    @Test func onlyTheNewestRecordsAreKept() async {
        let cache = ForecastCache(directory: directory)
        let records = (0...ForecastCache.capacity).map { index in
            record(at: Place(latitude: Double(index), longitude: 0, source: .device), attemptedAt: start.addingTimeInterval(Double(index)))
        }

        for record in records {
            await cache.store(record)
        }

        #expect(await cache.record(for: records[0].key) == nil)
        for record in records.dropFirst() {
            #expect(await cache.record(for: record.key) == record)
        }
    }

    @Test func anUnreadableFileReadsAsNoRecord() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: directory.appending(path: "Forecast.json"))

        #expect(await ForecastCache(directory: directory).record(for: record.key) == nil)
    }

    /// The file once held a single record rather than a list, which reads as none and costs a request.
    @Test func aSingleRecordFileReadsAsNoRecord() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: directory.appending(path: "Forecast.json"))

        let cache = ForecastCache(directory: directory)
        #expect(await cache.record(for: record.key) == nil)
        #expect(await cache.latestRecord() == nil)
    }

    /// A record from before `formatVersion`, whose missing answer would otherwise decode as a
    /// failed request and hold the next one back for an interval.
    @Test func aRecordInAnOlderShapeReadsAsNoRecord() async throws {
        let cache = ForecastCache(directory: directory)
        await cache.store(record)
        let file = directory.appending(path: "Forecast.json")
        var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        json[0]["formatVersion"] = nil
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        #expect(await cache.record(for: record.key) == nil)

        // The rewrite alone doesn't spoil the record: with the version back, it reads.
        json[0]["formatVersion"] = ForecastRecord.formatVersion
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        #expect(await cache.record(for: record.key) == record)
    }

    @Test func removeAllForgetsTheRecord() async {
        let cache = ForecastCache(directory: directory)
        await cache.store(record)

        await cache.removeAll()

        #expect(await cache.record(for: record.key) == nil)
    }
}

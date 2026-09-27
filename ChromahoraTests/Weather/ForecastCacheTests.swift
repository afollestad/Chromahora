//
//  ForecastCacheTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Each test writes to its own temporary directory.
struct ForecastCacheTests {
    private let directory = URL.temporaryDirectory.appending(path: "ForecastCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let place = Place(latitude: 41.85, longitude: -87.65, source: .device)
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private var record: ForecastRecord {
        ForecastRecord(
            key: ForecastKey(place: place, start: start, end: start.addingTimeInterval(10 * 24 * 60 * 60)),
            attemptedAt: start,
            spells: WeatherSpell.mock(for: start)
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

    @Test func removeAllForgetsTheRecord() async {
        let cache = ForecastCache(directory: directory)
        await cache.store(record)

        await cache.removeAll()

        #expect(await cache.record() == nil)
    }
}

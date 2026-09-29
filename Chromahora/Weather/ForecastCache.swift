//
//  ForecastCache.swift
//  Chromahora
//

import Foundation

/// Identifies a forecast: the place's rounded coordinates and the window it covers. The
/// place's source doesn't matter, since the forecast doesn't.
nonisolated struct ForecastKey: Hashable, Codable, Sendable {
    let latitudeTenths: Int
    let longitudeTenths: Int
    let start: Date
    let end: Date

    init(place: Place, start: Date, end: Date) {
        latitudeTenths = place.latitudeTenths
        longitudeTenths = place.longitudeTenths
        self.start = start
        self.end = end
    }

    func isSamePlace(as other: ForecastKey) -> Bool {
        latitudeTenths == other.latitudeTenths && longitudeTenths == other.longitudeTenths
    }
}

/// The last request made for a forecast, and its answer.
nonisolated struct ForecastRecord: Codable, Equatable, Sendable {
    /// Bump it when the record's shape changes. Stored and required, so a record in any other
    /// shape reads as none, even one whose missing answer would decode as nil and read as a failure.
    static let formatVersion = 2

    let formatVersion: Int
    let key: ForecastKey
    let attemptedAt: Date
    /// Nil while the request is out, and after it failed.
    let forecast: Forecast?

    init(key: ForecastKey, attemptedAt: Date, forecast: Forecast?) {
        formatVersion = Self.formatVersion
        self.key = key
        self.attemptedAt = attemptedAt
        self.forecast = forecast
    }
}

/// The last forecast request for each place and window, on disk, so `ThrottledWeatherProvider`
/// holds its pace across relaunches and while the person switches between places. It lives in
/// Caches, where the system may purge it at the cost of a request per place.
actor ForecastCache {
    /// Room for the device's place and every recent place, so switching among them within the
    /// throttle's interval never asks again.
    static let capacity = 6

    private let directory: URL
    /// `Forecast.json` for the app. The widgets throttle in a file of their own, so a request of
    /// theirs that failed or is still out never holds back the app's, nor the app's theirs.
    private let fileName: String
    /// How long a record can still answer. Older ones would be asked again anyway, so they're dropped.
    private let retention: TimeInterval

    /// In the app group's container by default, so the widgets see the app's forecasts.
    init(
        directory: URL = AppGroup.cachesDirectory,
        fileName: String = "Forecast.json",
        retention: TimeInterval = ThrottledWeatherProvider.minimumInterval
    ) {
        self.directory = directory
        self.fileName = fileName
        self.retention = retention
    }

    /// The stored record for `key`. A file or record in an older shape reads as none, which
    /// costs at most a request.
    func record(for key: ForecastKey) -> ForecastRecord? {
        records().first { $0.key == key }
    }

    /// The most recent request for any place, for the debug drawer.
    func latestRecord() -> ForecastRecord? {
        records().max { $0.attemptedAt < $1.attemptedAt }
    }

    /// Replaces the record for `record`'s place, whatever window it covered, since only a place's
    /// newest window is asked for again, so `capacity` counts places. Drops records too far from it
    /// to answer, and the oldest past `capacity`. The distance counts either side, like the
    /// throttle's, so a clock set back far can't keep a record alive. A failed write only costs a
    /// request later.
    func store(_ record: ForecastRecord) {
        var kept = records().filter {
            !$0.key.isSamePlace(as: record.key) && abs($0.attemptedAt.timeIntervalSince(record.attemptedAt)) < retention
        }
        kept.append(record)
        kept.sort { $0.attemptedAt > $1.attemptedAt }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(Array(kept.prefix(Self.capacity))).write(to: file, options: .atomic)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: file)
    }

    /// Every stored record. A file in any other shape, including the single record it once held,
    /// reads as empty.
    private func records() -> [ForecastRecord] {
        guard let data = try? Data(contentsOf: file),
              let records = try? JSONDecoder().decode([ForecastRecord].self, from: data) else {
            return []
        }
        return records.filter { $0.formatVersion == ForecastRecord.formatVersion }
    }

    private var file: URL {
        directory.appending(path: fileName)
    }
}

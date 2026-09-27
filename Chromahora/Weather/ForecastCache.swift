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
}

/// The last request made for a forecast, and its answer.
nonisolated struct ForecastRecord: Codable, Equatable, Sendable {
    let key: ForecastKey
    let attemptedAt: Date
    /// Nil while the request is out, and after it failed.
    let spells: [WeatherSpell]?
}

/// The last forecast request, on disk, so `ThrottledWeatherProvider` holds its pace across
/// relaunches. One record is enough, since a device rarely moves between places within the
/// interval. It lives in Caches, where the system may purge it at the cost of one request.
actor ForecastCache {
    private let directory: URL

    init(directory: URL = .cachesDirectory) {
        self.directory = directory
    }

    /// The stored record. One in an older shape reads as none, which costs at most one request.
    func record() -> ForecastRecord? {
        guard let data = try? Data(contentsOf: file) else {
            return nil
        }
        return try? JSONDecoder().decode(ForecastRecord.self, from: data)
    }

    /// Replaces the stored record. A failed write only costs a request later.
    func store(_ record: ForecastRecord) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(record).write(to: file, options: .atomic)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: file)
    }

    private var file: URL {
        directory.appending(path: "Forecast.json")
    }
}

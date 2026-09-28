//
//  SolarDayCache.swift
//  Chromahora
//

import Foundation

/// Identifies a cached month: the place's rounded coordinates, and the time zone its
/// days were windowed to. The place's source doesn't matter, since the data doesn't.
nonisolated struct SolarMonthKey: Hashable, Sendable {
    let latitudeTenths: Int
    let longitudeTenths: Int
    let month: CalendarMonth

    init(place: Place, month: CalendarMonth) {
        latitudeTenths = place.latitudeTenths
        longitudeTenths = place.longitudeTenths
        self.month = month
    }

    var next: SolarMonthKey {
        SolarMonthKey(latitudeTenths: latitudeTenths, longitudeTenths: longitudeTenths, month: month.next)
    }

    private init(latitudeTenths: Int, longitudeTenths: Int, month: CalendarMonth) {
        self.latitudeTenths = latitudeTenths
        self.longitudeTenths = longitudeTenths
        self.month = month
    }
}

/// Months of sun times on disk, one JSON file each, so a relaunch draws without the network.
///
/// A place and date always have the same sun times, so nothing expires. The files live in
/// Caches, where the system may purge them, since they can always be fetched again.
actor SolarDayCache {
    /// Part of every file name. Bump it when `SolarDayRecord`'s stored shape changes, and
    /// `prune` deletes the files written in the old one.
    static let formatVersion = 2

    struct Summary: Equatable, Sendable {
        let fileNames: [String]
        let byteCount: Int
    }

    private let directory: URL

    init(directory: URL = URL.cachesDirectory.appending(path: "SolarDays", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func records(for key: SolarMonthKey) -> [SolarDayRecord]? {
        guard let data = try? Data(contentsOf: url(for: key)) else {
            return nil
        }
        return try? SolarDayRecord.makeDecoder().decode([SolarDayRecord].self, from: data)
    }

    func store(_ records: [SolarDayRecord], for key: SolarMonthKey) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try SolarDayRecord.makeEncoder().encode(records).write(to: url(for: key), options: .atomic)
    }

    /// Deletes months that ended before last month, and files from other format versions.
    /// Months are compared in UTC, since a file's name doesn't say its zone reliably, which
    /// can keep a month a day longer or drop it a day sooner.
    func prune(now: Date) {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let lastMonth = utc.date(byAdding: .month, value: -1, to: now).map { CalendarMonth(containing: $0, in: .gmt).name } ?? ""
        for name in fileNames() {
            let fields = name.split(separator: "_")
            let isCurrentFormat = fields.first == "v\(Self.formatVersion)"
            let isRecent = fields.count > 1 && String(fields[1]) >= lastMonth
            if !isCurrentFormat || !isRecent {
                try? FileManager.default.removeItem(at: directory.appending(path: name))
            }
        }
    }

    func summary() -> Summary {
        let names = fileNames().sorted()
        let bytes = names.reduce(0) { total, name in
            let size = try? directory.appending(path: name).resourceValues(forKeys: [.fileSizeKey]).fileSize
            return total + (size ?? 0)
        }
        return Summary(fileNames: names, byteCount: bytes)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// As in `v2_2026-09_378_-1224_America-Los_Angeles.json`: the version and month come
    /// first, so `prune` can read them without parsing the zone.
    private func url(for key: SolarMonthKey) -> URL {
        let zone = key.month.timeZone.identifier.replacingOccurrences(of: "/", with: "-")
        let name = "v\(Self.formatVersion)_\(key.month.name)_\(key.latitudeTenths)_\(key.longitudeTenths)_\(zone).json"
        return directory.appending(path: name)
    }

    private func fileNames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
    }
}

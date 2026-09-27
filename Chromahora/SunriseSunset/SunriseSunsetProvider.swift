//
//  SunriseSunsetProvider.swift
//  Chromahora
//

import Foundation

/// Serves days from sunrise-sunset.org a month at a time, through `SolarDayCache`.
///
/// A month is 27 KB and one request, so fetching whole months makes most day changes
/// cache hits. After each answer it prefetches the next month, so crossing into it is too.
final class SunriseSunsetProvider: SolarDayProvider {
    private let fetcher: any SunriseSunsetFetching
    private let cache: SolarDayCache
    /// Months being read or fetched, so a quick run of requests in one month shares one fetch.
    private var loads: [SolarMonthKey: Task<[SolarDayRecord], any Error>] = [:]
    /// The latest prefetch, which tests await instead of waiting on a clock.
    private(set) var lastPrefetch: Task<Void, Never>?

    init(fetcher: any SunriseSunsetFetching = SunriseSunsetClient(), cache: SolarDayCache) {
        self.fetcher = fetcher
        self.cache = cache
    }

    func solarDay(for date: Date, at place: Place, calendar: Calendar) async throws -> SolarDay {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 60 * 60)
        let key = SolarMonthKey(place: place, month: CalendarMonth(containing: dayStart, in: calendar.timeZone))

        let records = try await records(for: key)
        prefetch(key.next)

        let dayName = key.month.dayName(of: dayStart)
        guard let record = records.first(where: { $0.date == dayName }) else {
            throw SunriseSunsetError.missingDay
        }
        return try record.solarDay(calendar: calendar, dayStart: dayStart, dayEnd: dayEnd)
    }

    /// Reads the month from the cache, or fetches and stores it. The work runs in a task
    /// that outlives any one caller, so a cancelled request doesn't cancel a shared fetch.
    private func records(for key: SolarMonthKey) async throws -> [SolarDayRecord] {
        if let load = loads[key] {
            return try await load.value
        }
        let load = Task { [fetcher, cache] in
            if let cached = await cache.records(for: key) {
                return cached
            }
            let records = try await fetcher.records(for: key.month, at: Place(tenthsOf: key))
            try? await cache.store(records, for: key)
            return records
        }
        loads[key] = load
        // Cleared once settled, success or failure, so a failure is retried next time.
        defer { loads[key] = nil }
        return try await load.value
    }

    /// Only after a successful answer, so a rate-limited API isn't asked again at once.
    private func prefetch(_ key: SolarMonthKey) {
        guard loads[key] == nil else {
            return
        }
        lastPrefetch = Task {
            _ = try? await records(for: key)
        }
    }
}

private extension Place {
    /// The rounded place a key was made from. Its source doesn't reach the API.
    init(tenthsOf key: SolarMonthKey) {
        self.init(latitude: Double(key.latitudeTenths) / 10, longitude: Double(key.longitudeTenths) / 10, source: .device)
    }
}

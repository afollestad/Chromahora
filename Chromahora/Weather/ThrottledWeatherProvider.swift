//
//  ThrottledWeatherProvider.swift
//  Chromahora
//

import Foundation

/// Thrown instead of asking again while the last request for a forecast failed within
/// `ThrottledWeatherProvider.minimumInterval`.
nonisolated struct ForecastThrottled: Error, Equatable {}

/// Asks `base` for a forecast at most once per `minimumInterval` for each place and window,
/// answering from the last request in between. Requests for a forecast already on its way
/// join it, so two windows showing the same place make one request, and switching away from a
/// place and back while its request is out waits for that answer rather than asking again.
///
/// The request runs in a task that outlives any one caller, so a cancelled load doesn't
/// throw away an answer the quota already paid for.
final class ThrottledWeatherProvider: WeatherProvider {
    /// Every install shares WeatherKit's monthly quota. An hour-old forecast is still current
    /// for spells an hour long, and failures wait too, so a spent quota or a rejected app is
    /// asked once an hour rather than on every launch.
    nonisolated static let minimumInterval: TimeInterval = 60 * 60

    private let base: any WeatherProvider
    private let cache: ForecastCache
    private let now: () -> Date
    private var inFlight: [ForecastKey: Task<Forecast, any Error>] = [:]

    /// `now` times the interval, and tests replace it so they never wait for real.
    init(base: any WeatherProvider, cache: ForecastCache, now: @escaping () -> Date = { .now }) {
        self.base = base
        self.cache = cache
        self.now = now
    }

    func forecast(from start: Date, to end: Date, at place: Place) async throws -> Forecast {
        let key = ForecastKey(place: place, start: start, end: end)
        if let task = inFlight[key] {
            return try await task.value
        }
        let task = Task { [base, cache, now] in
            let attemptedAt = now()
            // An attempt counts within the interval on either side of now, so a small clock
            // correction costs no request, and a clock set back far can't hold one for hours.
            if let record = await cache.record(for: key),
               abs(attemptedAt.timeIntervalSince(record.attemptedAt)) < Self.minimumInterval {
                guard let forecast = record.forecast else {
                    throw ForecastThrottled()
                }
                return forecast
            }
            // Stored before asking, so an attempt counts even if the app quits before it answers.
            await cache.store(ForecastRecord(key: key, attemptedAt: attemptedAt, forecast: nil))
            let forecast = try await base.forecast(from: start, to: end, at: place)
            await cache.store(ForecastRecord(key: key, attemptedAt: attemptedAt, forecast: forecast))
            return forecast
        }
        inFlight[key] = task
        defer {
            if inFlight[key] == task {
                inFlight[key] = nil
            }
        }
        return try await task.value
    }
}

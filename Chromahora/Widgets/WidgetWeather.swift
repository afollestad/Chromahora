//
//  WidgetWeather.swift
//  Chromahora
//

import Foundation

/// The widgets' forecasts: the freshest answer the app or the widgets already have, or else a
/// request of the widgets' own. That request is throttled in a file apart from the app's, so a
/// failure or a request still out on either side never holds back the other's.
final class WidgetWeather: WeatherProvider {
    /// Widgets refresh while nobody looks at them, so they ask a third as often as the app: at
    /// most eight requests a day per install that shows one, against WeatherKit's monthly quota,
    /// which every install shares with the app.
    static let interval: TimeInterval = 3 * ThrottledWeatherProvider.minimumInterval
    /// Where the widgets' own requests are recorded, beside the app's `Forecast.json`.
    static let cacheFileName = "WidgetForecast.json"
    /// How long a request may take before the last answer for its window stands in for it. Short
    /// of `SkyLoader.weatherTimeout`, so the stand-in arrives before the loader gives up on weather.
    static let patience: Duration = .seconds(6)

    private let appCache: ForecastCache
    private let widgetCache: ForecastCache
    private let throttled: ThrottledWeatherProvider
    private let now: () -> Date
    /// Waits out `patience`, and tests replace it so they never wait for real.
    private let sleep: @Sendable (Duration) async throws -> Void

    /// `now` times the interval, and tests replace it so they never wait for real.
    init(
        base: any WeatherProvider,
        directory: URL = AppGroup.cachesDirectory,
        now: @escaping () -> Date = { .now },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        appCache = ForecastCache(directory: directory)
        widgetCache = ForecastCache(directory: directory, fileName: Self.cacheFileName, retention: Self.interval)
        throttled = ThrottledWeatherProvider(base: base, cache: widgetCache, interval: Self.interval, now: now)
        self.now = now
        self.sleep = sleep
    }

    func forecast(from start: Date, to end: Date, at place: Place) async throws -> Forecast {
        let key = ForecastKey(place: place, start: start, end: end)
        let answered = [await appCache.record(for: key), await widgetCache.record(for: key)]
            .compactMap(\.self)
            .filter { $0.forecast != nil }
            .max { $0.attemptedAt < $1.attemptedAt }
        if let answered, let forecast = answered.forecast, abs(now().timeIntervalSince(answered.attemptedAt)) < Self.interval {
            return forecast
        }
        // Read before asking, since asking replaces the widgets' own answer.
        guard let last = answered?.forecast else {
            return try await throttled.forecast(from: start, to: end, at: place)
        }
        // A request that fails, waits on a failure, or takes past `patience` leaves the last answer
        // for the window, however old, as the app keeps what it shows. A slow one goes on in a task
        // of its own, so its answer still reaches the cache for the next reload.
        let (answers, answer) = AsyncStream<Forecast>.makeStream()
        Task {
            answer.yield((try? await throttled.forecast(from: start, to: end, at: place)) ?? last)
        }
        let deadline = Task { [sleep] in
            try? await sleep(Self.patience)
            answer.yield(last)
        }
        defer {
            deadline.cancel()
            answer.finish()
        }
        for await forecast in answers {
            return forecast
        }
        return last
    }
}

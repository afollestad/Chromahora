//
//  CachedForecastProvider.swift
//  Chromahora
//

import Foundation

/// Answers from the last forecast another process stored for the place, and never asks
/// WeatherKit, so it spends none of the quota. The watch's complications read the watch app's
/// this way, through the app group they share.
///
/// A forecast covers `Forecast.days` days, so one from a while ago still reaches the hours ahead,
/// whatever window it was asked for. While a request is out, and after one fails,
/// `ThrottledWeatherProvider` keeps a record without an answer in its place, so there's none to
/// give until the app's next request succeeds.
struct CachedForecastProvider: WeatherProvider {
    /// Nothing stored for the place, or only a request still out or failed.
    struct NoForecast: Error {}

    let cache: ForecastCache

    func forecast(from start: Date, to end: Date, at place: Place) async throws -> Forecast {
        guard let forecast = await cache.latestRecord(at: place)?.forecast else {
            throw NoForecast()
        }
        return forecast
    }
}

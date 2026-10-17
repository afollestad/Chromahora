//
//  SkyLoader+Live.swift
//  ChromahoraWatchWidgets
//

import Foundation

extension SkyLoader {
    /// The complications' one loader, on the storage the watch app fills, so every family shares
    /// its loads. It places the watch where the app last found it, since watchOS gives a widget no
    /// location of its own, and reads the forecast the app last stored there without asking
    /// WeatherKit, so the complications spend none of the quota.
    static let live = SkyLoader(
        placeProvider: DevicePlaceProvider(source: AppFixSource()),
        solarDays: SunriseSunsetProvider(cache: SolarDayCache()),
        weather: CachedForecastProvider(cache: ForecastCache())
    )
}

//
//  SkyLoader+Live.swift
//  ChromahoraWidgets
//

import Foundation

extension SkyLoader {
    /// The widgets' one loader, on the storage the app fills too, so every kind of widget shares
    /// its loads. Here rather than beside `SkyLoader`, since only the extension has
    /// `WidgetLocationSource`.
    static let live = SkyLoader(
        placeProvider: DevicePlaceProvider(source: WidgetLocationSource(), timeout: WidgetLocationSource.timeout),
        solarDays: SunriseSunsetProvider(cache: SolarDayCache()),
        weather: WidgetWeather(base: WeatherKitProvider())
    )
}

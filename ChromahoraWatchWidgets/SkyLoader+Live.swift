//
//  SkyLoader+Live.swift
//  ChromahoraWatchWidgets
//

import Foundation

extension SkyLoader {
    /// The complications' one loader, on the storage the watch app fills, so every family shares
    /// its loads. It places the watch where the app last found it, since watchOS gives a widget no
    /// location of its own, and asks for no weather, which no complication shows.
    static let live = SkyLoader(
        placeProvider: DevicePlaceProvider(source: AppFixSource()),
        solarDays: SunriseSunsetProvider(cache: SolarDayCache()),
        weather: nil
    )
}

//
//  DebugWeatherProvider.swift
//  Chromahora
//

#if DEBUG
import Foundation

/// Wraps the app's weather provider so the debug drawer can swap in a mock day or no
/// weather, and prints live failures, which the app otherwise keeps off the screen.
struct DebugWeatherProvider: WeatherProvider {
    let base: any WeatherProvider
    let settings: DebugSettings

    func forecast(from start: Date, to end: Date, at place: Place) async throws -> Forecast {
        switch settings.weatherMode {
        case .live:
            do {
                return try await base.forecast(from: start, to: end, at: place)
            } catch {
                print("Weather failed: \(error)")
                throw error
            }
        case .mock:
            return try await MockWeatherProvider().forecast(from: start, to: end, at: place)
        case .off:
            return Forecast()
        }
    }
}
#endif

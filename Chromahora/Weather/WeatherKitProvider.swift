//
//  WeatherKitProvider.swift
//  Chromahora
//

import CoreLocation
import Foundation
import WeatherKit

/// Reads hourly forecasts from WeatherKit. Every request spends the app's shared monthly
/// quota, so the app only asks through `ThrottledWeatherProvider`.
///
/// The only file that imports WeatherKit: its types have no public initializers, so
/// everything past here works with `WeatherHour`, `WeatherSpell` and `SkyHour`, which tests can build.
struct WeatherKitProvider: WeatherProvider {
    func forecast(from start: Date, to end: Date, at place: Place) async throws -> Forecast {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let hours = try await WeatherService.shared.weather(for: location, including: .hourly(startDate: start, endDate: end))
        return Forecast(spells: WeatherSpell.spells(from: hours.map(WeatherHour.init)), hours: hours.map(SkyHour.init))
    }

    /// WeatherKit's legal attribution as text, which it offers for screens that can't open its
    /// legal page, as the watch can't. Nil when WeatherKit can't be reached.
    static func legalAttributionText() async -> String? {
        try? await WeatherService.shared.attribution.legalAttributionText
    }
}

private extension SkyHour {
    init(_ hour: HourWeather) {
        let clouds = hour.cloudCoverByAltitude
        self.init(
            date: hour.date,
            uvIndex: hour.uvIndex.value,
            lowCloud: clouds.low,
            midCloud: clouds.medium,
            highCloud: clouds.high,
            visibility: hour.visibility.converted(to: .meters).value
        )
    }
}

private extension WeatherHour {
    init(_ hour: HourWeather) {
        self.init(
            date: hour.date,
            cloudCover: hour.cloudCover,
            precipitation: SkyCondition(hour.precipitation),
            precipitationChance: hour.precipitationChance,
            isFoggy: hour.condition == .foggy
        )
    }
}

private extension SkyCondition {
    init?(_ precipitation: Precipitation) {
        switch precipitation {
        case .none: return nil
        case .rain: self = .rain
        case .snow: self = .snow
        case .sleet: self = .sleet
        case .hail: self = .hail
        case .mixed: self = .mixed
        @unknown default: return nil
        }
    }
}

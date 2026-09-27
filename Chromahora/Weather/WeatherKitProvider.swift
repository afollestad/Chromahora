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
/// everything past here works with `WeatherHour` and `WeatherSpell`, which tests can build.
struct WeatherKitProvider: WeatherProvider {
    func spells(from start: Date, to end: Date, at place: Place) async throws -> [WeatherSpell] {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let hours = try await WeatherService.shared.weather(for: location, including: .hourly(startDate: start, endDate: end))
        return WeatherSpell.spells(from: hours.map(WeatherHour.init))
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

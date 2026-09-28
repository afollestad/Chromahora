//
//  DebugSettings.swift
//  Chromahora
//

#if DEBUG
import Foundation
import Observation

/// Overrides for states the app otherwise only reaches by chance, like a stalled
/// network or 3 AM. Launch arguments seed them, so scripts reach them without a tap,
/// and nothing is persisted, so an override can't outlive the session that set it.
@Observable
final class DebugSettings {
    /// How `DebugSolarDayProvider` treats each request.
    enum ProviderMode: String, CaseIterable, Identifiable {
        case live
        case slow
        case hang
        case fail

        var id: Self { self }

        var title: String {
            switch self {
            case .live: "Live"
            case .slow: "Slow"
            case .hang: "Never answers"
            case .fail: "Always fails"
            }
        }
    }

    /// Where `DebugWeatherProvider` gets forecasts.
    enum WeatherMode: String, CaseIterable, Identifiable {
        case live
        case mock
        case off

        var id: Self { self }

        var title: String {
            switch self {
            case .live: "Live"
            case .mock: "Mock day"
            case .off: "None"
            }
        }
    }

    var providerMode: ProviderMode
    var weatherMode: WeatherMode
    /// Replaces the app's provider with a fixed day shape, like a high-latitude day.
    var scenario: MockScenario?
    /// Stands in for the clock everywhere the app asks what time it is.
    var nowOverride: Date?
    /// Stands in for wherever the place provider would put the device.
    var placeOverride: Place?
    var opensPanelOnLaunch: Bool
    /// The page beside the timeline the app opens on, since `simctl` can't swipe to it.
    var initialPane: DayPager.Pane
    /// The app's sun-time cache, which the drawer summarizes and clears.
    var cache: SolarDayCache?
    /// The app's place provider, whose stored fix the drawer can forget.
    var devicePlaces: DevicePlaceProvider?
    /// The app's forecast cache, whose last request the drawer shows and clears.
    var forecastCache: ForecastCache?

    /// Reads `-DebugProviderMode`, `-DebugScenario`, `-DebugWeather`, `-DebugNow`, `-DebugPlace`,
    /// `-DebugPanel` and `-DebugPane` from `arguments`, ignoring values it can't parse. `-DebugNow` is
    /// local time, as in `2026-09-16T03:00:00`, `-DebugPlace` is as in `59.9N,30.3E`, and `-DebugPane`
    /// is `timeline` or `details`.
    init(arguments: [String: Any] = [:], timeZone: TimeZone = .current) {
        providerMode = (arguments["DebugProviderMode"] as? String).flatMap(ProviderMode.init(rawValue:)) ?? .live
        scenario = (arguments["DebugScenario"] as? String).flatMap(MockScenario.init(rawValue:))
        weatherMode = (arguments["DebugWeather"] as? String).flatMap(WeatherMode.init(rawValue:)) ?? .live
        nowOverride = (arguments["DebugNow"] as? String).flatMap { Self.localDate(from: $0, in: timeZone) }
        placeOverride = (arguments["DebugPlace"] as? String).flatMap(Self.place(from:))
        opensPanelOnLaunch = (arguments["DebugPanel"] as? String).map(Self.isTrue) ?? false
        initialPane = (arguments["DebugPane"] as? String).flatMap(DayPager.Pane.init(rawValue:)) ?? .timeline
    }

    /// Settings from this process's launch arguments. Only the argument domain is read, so
    /// nothing a previous session wrote to `UserDefaults` can switch an override on.
    static func fromLaunchArguments() -> DebugSettings {
        DebugSettings(arguments: UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain))
    }

    private nonisolated static func localDate(from string: String, in timeZone: TimeZone) -> Date? {
        let style = Date.ISO8601FormatStyle(timeZone: timeZone)
            .year().month().day()
            .dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: false)
        // The style requires seconds, which are rarely worth typing.
        let withSeconds = string.filter { $0 == ":" }.count == 1 ? string + ":00" : string
        return try? style.parse(withSeconds)
    }

    /// Takes hemisphere letters, as in `33.9S,151.2E`, since the argument domain reads a
    /// value starting with `-` as another argument and drops it. Plain signed degrees
    /// work too, as long as the latitude is north.
    private nonisolated static func place(from string: String) -> Place? {
        let parts = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
        guard parts.count == 2,
              let latitude = degrees(parts[0], negative: "S", positive: "N"),
              let longitude = degrees(parts[1], negative: "W", positive: "E") else {
            return nil
        }
        return Place(latitude: latitude, longitude: longitude, source: .device)
    }

    private nonisolated static func degrees(_ text: String, negative: Character, positive: Character) -> Double? {
        guard let last = text.last else {
            return nil
        }
        if last == negative || last == positive {
            return Double(text.dropLast()).map { last == negative ? -$0 : $0 }
        }
        return Double(text)
    }

    private nonisolated static func isTrue(_ string: String) -> Bool {
        ["yes", "true", "1"].contains(string.lowercased())
    }
}
#endif

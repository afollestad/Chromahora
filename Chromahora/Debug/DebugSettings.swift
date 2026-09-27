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

    var providerMode: ProviderMode
    /// Stands in for the clock everywhere the app asks what time it is.
    var nowOverride: Date?
    var opensPanelOnLaunch: Bool

    /// Reads `-DebugProviderMode`, `-DebugNow` and `-DebugPanel` from `arguments`,
    /// ignoring values it can't parse. `-DebugNow` is local time, as in `2026-09-16T03:00:00`.
    init(arguments: [String: Any] = [:], timeZone: TimeZone = .current) {
        providerMode = (arguments["DebugProviderMode"] as? String).flatMap(ProviderMode.init(rawValue:)) ?? .live
        nowOverride = (arguments["DebugNow"] as? String).flatMap { Self.localDate(from: $0, in: timeZone) }
        opensPanelOnLaunch = (arguments["DebugPanel"] as? String).map(Self.isTrue) ?? false
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

    private nonisolated static func isTrue(_ string: String) -> Bool {
        ["yes", "true", "1"].contains(string.lowercased())
    }
}
#endif

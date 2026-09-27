//
//  DebugSolarDayProvider.swift
//  Chromahora
//

#if DEBUG
import Foundation

/// Wraps the app's provider so the debug drawer can slow, stall or fail a load on demand,
/// or swap in a fixed day shape.
final class DebugSolarDayProvider: SolarDayProvider {
    struct SimulatedFailure: LocalizedError {
        var errorDescription: String? { "The debug drawer failed this load on purpose." }
    }

    /// Long enough to watch the loading state and the reveal that ends it.
    static let slowDelay: Duration = .seconds(3)

    private let base: any SolarDayProvider
    private let settings: DebugSettings
    private let sleep: (Duration) async throws -> Void

    /// `sleep` waits out `.slow`, and tests replace it so they never wait for real.
    init(
        base: any SolarDayProvider,
        settings: DebugSettings,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.base = base
        self.settings = settings
        self.sleep = sleep
    }

    func solarDay(for date: Date, calendar: Calendar) async throws -> SolarDay {
        switch settings.providerMode {
        case .live:
            break
        case .slow:
            try await sleep(Self.slowDelay)
        case .hang:
            // A century, which cancellation always cuts short.
            try await Task.sleep(for: .seconds(100 * 365 * 24 * 60 * 60))
        case .fail:
            throw SimulatedFailure()
        }
        let provider = settings.scenario.map { MockSolarDayProvider(scenario: $0) } ?? base
        return try await provider.solarDay(for: date, calendar: calendar)
    }
}
#endif

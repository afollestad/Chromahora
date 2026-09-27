//
//  WeatherStore.swift
//  Chromahora
//

import Foundation
import Observation

/// Loads the weather spells for the current place, for every day the forecast reaches.
///
/// Weather only adds to the timeline, so a failure, including a spent quota, keeps what's
/// shown and never reaches the screen. Days and sun times load separately, in `SolarDayStore`.
@Observable
final class WeatherStore {
    /// What restarts a view's load: a finished location lookup, which launching and returning
    /// to the app both run, or a reload.
    struct Trigger: Hashable {
        let locatedCount: Int
        let reloadCount: Int
    }

    /// WeatherKit forecasts hourly about ten days out, so one request covers every day it can.
    static let forecastDays = 10

    /// Every spell in the forecast, which the timeline filters to its day.
    private(set) var spells: [WeatherSpell] = []
    /// Where `spells` are for.
    private var place: Place?

    private let calendar: Calendar
    private let provider: any WeatherProvider

    init(provider: any WeatherProvider, calendar: Calendar = .current) {
        self.provider = provider
        self.calendar = calendar
    }

    /// Loads the forecast from the start of `now`'s day. A new place clears the spells at once,
    /// and an answer for a place that has since changed is dropped.
    func load(at place: Place?, now: Date) async {
        if place != self.place {
            self.place = place
            spells = []
        }
        guard let place else {
            return
        }
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: Self.forecastDays, to: start) else {
            return
        }
        do {
            let spells = try await provider.spells(from: start, to: end, at: place)
            if place == self.place {
                self.spells = spells
            }
        } catch {
            // Weather only adds to the timeline, so a failure keeps what's shown.
        }
    }
}

//
//  WeatherStore.swift
//  Chromahora
//

import Foundation
import Observation

/// Loads the forecast for the current place, for every day it reaches.
///
/// Weather only adds to the timeline, so a failure, including a spent quota, keeps what's
/// shown and never reaches the screen. Days and sun times load separately, in `SolarDayStore`.
@Observable
final class WeatherStore {
    /// What restarts a view's load: a finished location lookup, which launching and returning
    /// to the app both run, and which choosing a place counts as, or a reload.
    struct Trigger: Hashable {
        let locatedCount: Int
        let reloadCount: Int
    }

    /// Every spell and hour in the forecast, which the timeline and the day's details filter to
    /// their day. Read through `spells(at:)` and `hours(at:)`, which check they're for the place on screen.
    private var forecast = Forecast()
    /// Where `forecast` is for.
    private var place: Place?

    private let provider: any WeatherProvider

    init(provider: any WeatherProvider) {
        self.provider = provider
    }

    /// The spells, while they're for `place`, the place of the day on screen. A new place's
    /// forecast can arrive before its day, and another place's spells mustn't mark the old one.
    func spells(at place: Place?) -> [WeatherSpell] {
        place == self.place ? forecast.spells : []
    }

    /// The hours, while they're for `place`, for the same reason.
    func hours(at place: Place?) -> [SkyHour] {
        place == self.place ? forecast.hours : []
    }

    /// Loads the forecast for `Forecast.window` in `calendar`, which is the day store's, so the
    /// window follows the zone days are windowed to: the device's, or a chosen place's. A new
    /// place clears the forecast at once, and an answer for a place that has since changed is dropped.
    func load(at place: Place?, now: Date, calendar: Calendar) async {
        if place != self.place {
            self.place = place
            forecast = Forecast()
        }
        guard let place else {
            return
        }
        guard let window = Forecast.window(at: now, calendar: calendar) else {
            return
        }
        do {
            let forecast = try await provider.forecast(from: window.start, to: window.end, at: place)
            if place == self.place {
                self.forecast = forecast
            }
        } catch {
            // Weather only adds to the timeline, so a failure keeps what's shown.
        }
    }
}

//
//  SkyEntry.swift
//  Chromahora
//

import Foundation
import WidgetKit

/// What the widgets show, loaded once for a timeline and shared by its entries: the place, the
/// days around now there, and the sky over them.
nonisolated struct SkyContent: Sendable {
    let place: Place
    /// The device's town from the app's last lookup. Nil for a cell the app hasn't named yet,
    /// which the title calls "Current Location" until it does.
    let deviceName: String?
    let run: DayRun
    /// The forecast's spells over the run. Empty without weather, which the widgets then leave
    /// out, Apple Weather's mark with it.
    let spells: [WeatherSpell]

    /// The spell the sky is under at `date`.
    func spell(at date: Date) -> WeatherSpell? {
        spells.first { $0.interval.start <= date && date < $0.interval.end }
    }
}

/// A moment in a widget's timeline.
nonisolated struct SkyEntry: TimelineEntry, Sendable {
    enum State: Sendable {
        case loaded(SkyContent)
        /// Today's sun times couldn't load, from the cache or the network.
        case unavailable
    }

    let date: Date
    let state: State
}

nonisolated extension SkyContent {
    /// San Francisco on a typical day with weather, for the placeholder, the gallery and previews.
    static func preview(at date: Date, calendar: Calendar = .current) -> SkyContent {
        let today = SolarDay.mock(for: date, calendar: calendar)
        let tomorrow = SolarDay.mock(for: today.dayEnd, calendar: calendar)
        return SkyContent(
            place: MockPlaceProvider.sanFrancisco,
            deviceName: "San Francisco",
            run: DayRun(today, then: [tomorrow]),
            spells: WeatherSpell.mock(for: today.dayStart, calendar: calendar) + WeatherSpell.mock(for: tomorrow.dayStart, calendar: calendar)
        )
    }
}

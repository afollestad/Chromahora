//
//  DayLoading.swift
//  Chromahora
//

import SwiftUI

/// Places the device and loads the selected day, its neighbors, the town's name and the
/// forecast, in the order every app showing a `SolarDayStore` needs, so the phone and the
/// watch share one set of rules for when each is asked.
private struct DayLoading: ViewModifier {
    /// Locating waits for the app to be on screen, and runs again each time it returns
    /// from the background.
    private struct LocateTrigger: Hashable {
        let isOnScreen: Bool
        let count: Int
    }

    /// Names the device's town once each lookup finishes, including after returning to the app,
    /// so a name that failed offline is asked for again.
    private struct NameTrigger: Hashable {
        let place: Place?
        let locatedCount: Int
    }

    let store: SolarDayStore
    let weather: WeatherStore
    let placeNames: PlaceNames
    /// The debug drawer's clock, if it overrides the real one.
    let nowOverride: Date?
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            // Returning to the app after travel relocates. Only the background counts as leaving:
            // the permission prompt and Control Center make the app inactive, and restarting
            // for them would drop the fix in progress.
            .task(id: LocateTrigger(isOnScreen: scenePhase != .background, count: store.locateCount)) {
                if scenePhase != .background {
                    await store.locate()
                }
            }
            .task(id: store.loadKey) {
                await store.loadSelectedDay()
                await store.loadAdjacentDays()
            }
            // Travel can change the device's zone while the app is suspended, and days are windowed to it.
            .task {
                for await _ in NotificationCenter.default.notifications(named: .NSSystemTimeZoneDidChange) {
                    store.changeTimeZone(to: Calendar.current.timeZone)
                }
            }
            .task(id: NameTrigger(place: store.place, locatedCount: store.locatedCount)) {
                if let place = store.place {
                    await placeNames.load(place)
                }
            }
            // Waits for each location lookup, so no request goes to a stored place the device has
            // left, and only asks WeatherKit when its throttle allows. A reload while a lookup is out
            // waits for it too, and the lookup finishing loads the forecast.
            .task(id: WeatherStore.Trigger(locatedCount: store.locatedCount, reloadCount: store.reloadCount)) {
                if store.isPlaceSettled, scenePhase != .background {
                    await weather.load(at: store.place, now: nowOverride ?? .now, calendar: store.calendar)
                }
            }
    }
}

extension View {
    /// Keeps `store` placed and loaded, with `weather` and `placeNames` following its place, for
    /// as long as the view is on screen. `nowOverride` stands in for the clock, as the debug
    /// drawer's does.
    func dayLoading(store: SolarDayStore, weather: WeatherStore, placeNames: PlaceNames, nowOverride: Date?) -> some View {
        modifier(DayLoading(store: store, weather: weather, placeNames: placeNames, nowOverride: nowOverride))
    }
}

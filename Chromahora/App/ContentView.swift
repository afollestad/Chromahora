//
//  ContentView.swift
//  Chromahora
//
//  Created by Aidan Follestad on 9/26/26.
//

import SwiftUI

struct ContentView: View {
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

    /// One store per window, so each window can show its own day and place.
    @State private var store: SolarDayStore
    @State private var weather: WeatherStore
    private let placeSearch: any PlaceSearch
    private let placeNames: PlaceNames
    private let recentPlaces: RecentPlaces
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    init(
        provider: any SolarDayProvider,
        placeProvider: any PlaceProvider,
        weatherProvider: any WeatherProvider,
        placeSearch: any PlaceSearch,
        placeNames: PlaceNames,
        recentPlaces: RecentPlaces,
        selectedDate: Date = .now
    ) {
        _store = State(initialValue: SolarDayStore(provider: provider, placeProvider: placeProvider, selectedDate: selectedDate))
        _weather = State(initialValue: WeatherStore(provider: weatherProvider))
        self.placeSearch = placeSearch
        self.placeNames = placeNames
        self.recentPlaces = recentPlaces
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                DayScreen(
                    state: store.state,
                    now: now(from: context.date),
                    selectedDate: $store.selectedDate,
                    calendar: store.calendar,
                    place: store.place,
                    deviceName: placeNames.name(for: store.place),
                    chooser: chooser,
                    // For the day on screen, which keeps the last place's until the new one's loads.
                    weather: weather.spells(at: store.shownPlace),
                    hours: weather.hours(at: store.shownPlace),
                    initialPane: initialPane,
                    onRetry: store.reload,
                    onPage: store.selectDay(offsetBy:from:)
                )
            }
        }
        // Returning to the app after travel relocates. Only the background counts as leaving:
        // the permission prompt and Control Center make the app inactive, and restarting
        // for them would drop the fix in progress.
        .task(id: LocateTrigger(isOnScreen: scenePhase != .background, count: store.locateCount)) {
            if scenePhase != .background {
                await store.locate()
            }
        }
        // WidgetKit hands the app every link a widget holds, so the credits' links, which the
        // services' terms ask for, pass through here on their way to Safari. Matched by host,
        // in case the system normalizes a path on the way.
        .onOpenURL { url in
            let creditHosts = [SunriseSunsetClient.siteURL, AppleWeatherCredit.legalPage].compactMap { $0?.host() }
            if url.scheme == "https", let host = url.host(), creditHosts.contains(host) {
                openURL(url)
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
                await weather.load(at: store.place, now: now(from: .now), calendar: store.calendar)
            }
        }
        #if DEBUG
        .debugDrawer(store: store, settings: debug)
        // `-DebugChosenPlace` opens on a chosen place, since `simctl` can't type into the search.
        .task {
            if let place = debug?.chosenPlace {
                store.choose(place, now: now(from: .now))
            }
        }
        #endif
    }

    /// Chooses places for this window's store, at the time the choice is made.
    private var chooser: PlaceChooser {
        let store = store
        // Read here, where the environment is installed, rather than whenever a place is chosen.
        let nowOverride = nowOverride
        return PlaceChooser(search: placeSearch, recents: recentPlaces) { place in
            let now = nowOverride ?? .now
            if let place {
                store.choose(place, now: now)
            } else {
                store.useCurrentLocation(now: now)
            }
        }
    }

    /// The page beside the timeline to open on, which `-DebugPane` sets in debug builds.
    private var initialPane: DayPager.Pane {
        #if DEBUG
        debug?.initialPane ?? .timeline
        #else
        .timeline
        #endif
    }

    /// The time the app shows as now, which the debug drawer can override.
    private func now(from date: Date) -> Date {
        nowOverride ?? date
    }

    /// The debug drawer's clock, if it overrides the real one.
    private var nowOverride: Date? {
        #if DEBUG
        debug?.nowOverride
        #else
        nil
        #endif
    }
}

#Preview {
    let search = MockPlaceSearch()
    ContentView(
        provider: MockSolarDayProvider(),
        placeProvider: MockPlaceProvider(),
        weatherProvider: MockWeatherProvider(),
        placeSearch: search,
        placeNames: PlaceNames(search: search, defaults: nil),
        recentPlaces: RecentPlaces(defaults: nil)
    )
}

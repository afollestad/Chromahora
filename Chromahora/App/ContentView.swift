//
//  ContentView.swift
//  Chromahora
//
//  Created by Aidan Follestad on 9/26/26.
//

import SwiftUI

struct ContentView: View {
    /// One store per window, so each window can show its own day and place.
    @State private var store: SolarDayStore
    @State private var weather: WeatherStore
    private let placeSearch: any PlaceSearch
    private let placeNames: PlaceNames
    private let recentPlaces: RecentPlaces
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
        .dayLoading(store: store, weather: weather, placeNames: placeNames, nowOverride: nowOverride)
        // WidgetKit hands the app every link a widget holds, so the credits' links, which the
        // services' terms ask for, pass through here on their way to Safari. Matched by host,
        // in case the system normalizes a path on the way.
        .onOpenURL { url in
            let creditHosts = [SunriseSunsetClient.siteURL, AppleWeatherCredit.legalPage].compactMap { $0?.host() }
            if url.scheme == "https", let host = url.host(), creditHosts.contains(host) {
                openURL(url)
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

//
//  ChromahoraApp.swift
//  Chromahora
//
//  Created by Aidan Follestad on 9/26/26.
//

import SwiftUI
import WidgetKit

@main
struct ChromahoraApp: App {
    /// Tests run inside the app, which keeps running underneath them. Without this it
    /// would fetch sun times and ask for location in the middle of a run.
    static var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Made once and shared by every window, so they share one cache and one set of fetches.
    private let cache = SolarDayCache()
    private let provider: any SolarDayProvider
    private let placeProvider: any PlaceProvider
    private let weatherProvider: any WeatherProvider
    /// Shared by every window too, so windows share town lookups, and a place chosen in one is
    /// recent in the others.
    private let placeSearch = MapKitPlaceSearch()
    private let placeNames: PlaceNames
    private let recentPlaces = RecentPlaces()
    #if DEBUG
    @State private var debug: DebugSettings
    #endif
    @Environment(\.scenePhase) private var scenePhase

    init() {
        placeNames = PlaceNames(search: placeSearch)
        let provider = SunriseSunsetProvider(cache: cache)
        let placeProvider = DevicePlaceProvider(source: CoreLocationSource())
        let forecastCache = ForecastCache()
        let weatherProvider = ThrottledWeatherProvider(base: WeatherKitProvider(), cache: forecastCache)
        #if DEBUG
        let debug = DebugSettings.fromLaunchArguments()
        debug.cache = cache
        debug.devicePlaces = placeProvider
        debug.forecastCache = forecastCache
        _debug = State(initialValue: debug)
        self.provider = DebugSolarDayProvider(base: provider, settings: debug)
        self.placeProvider = DebugPlaceProvider(base: placeProvider, settings: debug)
        self.weatherProvider = DebugWeatherProvider(base: weatherProvider, settings: debug)
        #else
        self.provider = provider
        self.placeProvider = placeProvider
        self.weatherProvider = weatherProvider
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if Self.isHostingTests {
                Color.clear
            } else {
                content
                    .task {
                        await cache.prune(now: .now)
                    }
            }
        }
        // A visit may bring a new fix, forecast or permission, which the widgets should show
        // without waiting for their next reload. The app tells them whenever it stops being
        // active, which leaving starts with, while it's still in the foreground and a reload
        // doesn't count against their budget; the permission prompt and Control Center only cost
        // a reload more.
        .onChange(of: scenePhase) { oldPhase, _ in
            if oldPhase == .active, !Self.isHostingTests {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        ContentView(
            provider: provider,
            placeProvider: placeProvider,
            weatherProvider: weatherProvider,
            placeSearch: placeSearch,
            placeNames: placeNames,
            recentPlaces: recentPlaces,
            selectedDate: debug.nowOverride ?? .now
        )
        .environment(debug)
        #else
        ContentView(
            provider: provider,
            placeProvider: placeProvider,
            weatherProvider: weatherProvider,
            placeSearch: placeSearch,
            placeNames: placeNames,
            recentPlaces: recentPlaces
        )
        #endif
    }
}

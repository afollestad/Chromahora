//
//  ChromahoraWatchApp.swift
//  ChromahoraWatch
//

import SwiftUI
import WidgetKit

@main
struct ChromahoraWatchApp: App {
    /// Made once, on the App Group's storage by default, like the phone app's.
    private let cache = SolarDayCache()
    private let provider: any SolarDayProvider
    private let placeProvider: any PlaceProvider
    private let weatherProvider: any WeatherProvider
    private let placeNames = PlaceNames(search: MapKitPlaceSearch())
    #if DEBUG
    @State private var debug: DebugSettings
    #endif
    @Environment(\.scenePhase) private var scenePhase

    init() {
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
            content
                .task {
                    await cache.prune(now: .now)
                }
        }
        // A visit may bring a new fix, which the complications place themselves by, so the app
        // tells them whenever it stops being active, as lowering the wrist starts with, while a
        // reload doesn't count against their budget.
        .onChange(of: scenePhase) { oldPhase, _ in
            if oldPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        WatchContentView(
            provider: provider,
            placeProvider: placeProvider,
            weatherProvider: weatherProvider,
            placeNames: placeNames,
            selectedDate: debug.nowOverride ?? .now
        )
        .environment(debug)
        #else
        WatchContentView(
            provider: provider,
            placeProvider: placeProvider,
            weatherProvider: weatherProvider,
            placeNames: placeNames
        )
        #endif
    }
}

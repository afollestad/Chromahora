//
//  WatchContentView.swift
//  ChromahoraWatch
//

import SwiftUI

struct WatchContentView: View {
    /// Two thirds of the phone's, for the smaller screen.
    private static let pointsPerHour: CGFloat = 48

    @State private var store: SolarDayStore
    @State private var weather: WeatherStore
    private let placeNames: PlaceNames
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    init(
        provider: any SolarDayProvider,
        placeProvider: any PlaceProvider,
        weatherProvider: any WeatherProvider,
        placeNames: PlaceNames,
        selectedDate: Date = .now
    ) {
        _store = State(initialValue: SolarDayStore(provider: provider, placeProvider: placeProvider, selectedDate: selectedDate))
        _weather = State(initialValue: WeatherStore(provider: weatherProvider))
        self.placeNames = placeNames
    }

    var body: some View {
        NavigationStack {
            Group {
                if let day = store.state.day {
                    ScrollView {
                        SkyGradient(day: day)
                            .frame(height: day.duration / 3600 * Self.pointsPerHour)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(store.place?.title(deviceName: placeNames.name(for: store.place)) ?? "")
        }
        .dayLoading(store: store, weather: weather, placeNames: placeNames, nowOverride: nowOverride)
    }

    /// The debug settings' clock, if it overrides the real one.
    private var nowOverride: Date? {
        #if DEBUG
        debug?.nowOverride
        #else
        nil
        #endif
    }
}

#Preview {
    WatchContentView(
        provider: MockSolarDayProvider(),
        placeProvider: MockPlaceProvider(),
        weatherProvider: MockWeatherProvider(),
        placeNames: PlaceNames(search: MockPlaceSearch(), defaults: nil)
    )
}

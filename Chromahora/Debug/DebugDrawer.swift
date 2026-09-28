//
//  DebugDrawer.swift
//  Chromahora
//

#if DEBUG
import CoreLocation
import SwiftUI

extension View {
    /// Adds the debug drawer, opened by swiping in from the right edge. Without
    /// settings, as in previews and snapshot tests, the view is left alone.
    @ViewBuilder
    func debugDrawer(store: SolarDayStore, settings: DebugSettings?) -> some View {
        if let settings {
            modifier(DebugDrawer(store: store, settings: settings))
        } else {
            self
        }
    }
}

private struct DebugDrawer: ViewModifier {
    let store: SolarDayStore
    let settings: DebugSettings

    @State private var isOpen = false

    // The scrim and panel are inserted separately, since a transition only applies
    // to the view an `if` inserts, not to its descendants.
    func body(content: Content) -> some View {
        content
            .gesture(ScreenEdgeSwipe { setOpen(true) })
            .overlay {
                if isOpen {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { setOpen(false) }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .trailing) {
                if isOpen {
                    panel
                        .transition(.move(edge: .trailing))
                }
            }
            .task {
                guard settings.opensPanelOnLaunch else {
                    return
                }
                // Presentations on the first frame don't render.
                try? await Task.sleep(for: .milliseconds(500))
                setOpen(true)
            }
    }

    private var panel: some View {
        DebugPanel(store: store, settings: settings) {
            setOpen(false)
        }
        // Leaves a strip of the app showing, so the drawer reads as dismissible.
        .containerRelativeFrame(.horizontal) { width, _ in
            min(340, width - 44)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(.trailing, 8)
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.width > 60 {
                    setOpen(false)
                }
            }
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { setOpen(false) }
    }

    private func setOpen(_ open: Bool) {
        withAnimation(.snappy) {
            isOpen = open
        }
    }
}

/// The drawer's controls, which later tools add sections to.
private struct DebugPanel: View {
    let store: SolarDayStore
    @Bindable var settings: DebugSettings
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Loading") {
                    Picker("Sun times", selection: $settings.providerMode) {
                        ForEach(DebugSettings.ProviderMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Picker("Day shape", selection: $settings.scenario) {
                        Text("App's provider").tag(MockScenario?.none)
                        ForEach(MockScenario.allCases) { scenario in
                            Text(scenario.title).tag(Optional(scenario))
                        }
                    }
                    // The store keeps loaded days, so a new shape only shows once they're gone.
                    .onChange(of: settings.scenario, reloadFromScratch)
                    Picker("Weather", selection: $settings.weatherMode) {
                        ForEach(DebugSettings.WeatherMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    // A reload asks for weather again, while the days come back from memory.
                    .onChange(of: settings.weatherMode) { store.reload() }
                    Button("Reload from scratch", action: reloadFromScratch)
                }

                DebugCacheSection(store: store, cache: settings.cache, forecastCache: settings.forecastCache)

                Section("Place") {
                    if let place = store.place {
                        LabeledContent("Coordinates", value: "\(place.latitude), \(place.longitude)")
                        LabeledContent("Source", value: place.summary)
                    } else {
                        Text("None yet")
                    }
                    LabeledContent("Time zone", value: store.calendar.timeZone.identifier)
                    LabeledContent("Permission", value: Self.authorization)
                    Button("Relocate", action: store.relocate)
                    Button("Forget last device fix") {
                        settings.devicePlaces?.forgetLastFix()
                    }
                    .disabled(settings.devicePlaces == nil)
                }

                Section {
                    Toggle("Override now", isOn: isOverridingNow)
                    if let override = settings.nowOverride {
                        DatePicker("Now", selection: nowOverride(defaultingTo: override))
                    }
                } header: {
                    Text("Time")
                } footer: {
                    Text("Also selects that day.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }

    private static var authorization: String {
        switch CLLocationManager().authorizationStatus {
        case .notDetermined: "Not asked"
        case .restricted: "Restricted"
        case .denied: "Denied"
        case .authorizedAlways: "Always"
        case .authorizedWhenInUse: "When in use"
        @unknown default: "Unknown"
        }
    }

    private func reloadFromScratch() {
        store.discardLoadedDays()
        store.reload()
    }

    private var isOverridingNow: Binding<Bool> {
        Binding {
            settings.nowOverride != nil
        } set: { isOn in
            setNow(isOn ? .now : nil)
        }
    }

    private func nowOverride(defaultingTo date: Date) -> Binding<Date> {
        Binding {
            settings.nowOverride ?? date
        } set: { newValue in
            setNow(newValue)
        }
    }

    private func setNow(_ date: Date?) {
        settings.nowOverride = date
        store.selectedDate = date ?? .now
    }
}

/// The cache's size and the last forecast request, and a way to empty both and reload as
/// if launching cold, which also lets the next load ask WeatherKit at once.
private struct DebugCacheSection: View {
    let store: SolarDayStore
    let cache: SolarDayCache?
    let forecastCache: ForecastCache?

    @State private var summary: SolarDayCache.Summary?
    @State private var lastRequest: ForecastRecord?

    var body: some View {
        Section("Cache") {
            if let summary {
                LabeledContent("Months", value: "\(summary.fileNames.count)")
                LabeledContent("Size", value: summary.byteCount.formatted(.byteCount(style: .file)))
            }
            LabeledContent("Forecast requested", value: forecastSummary)
            Button("Clear cache", role: .destructive) {
                Task {
                    await cache?.removeAll()
                    await forecastCache?.removeAll()
                    store.discardLoadedDays()
                    store.reload()
                    await refresh()
                }
            }
            .disabled(cache == nil)
        }
        .task {
            await refresh()
        }
    }

    /// When WeatherKit was last asked, and what came back: spell and hour counts, or nothing when it failed or is still out.
    private var forecastSummary: String {
        guard let lastRequest else {
            return "Never"
        }
        let time = lastRequest.attemptedAt.formatted(date: .omitted, time: .standard)
        return lastRequest.forecast.map { "\(time), \($0.spells.count) spells, \($0.hours.count) hours" } ?? "\(time), no answer"
    }

    private func refresh() async {
        summary = await cache?.summary()
        lastRequest = await forecastCache?.latestRecord()
    }
}

#Preview {
    Color.clear
        .debugDrawer(
            store: SolarDayStore(provider: MockSolarDayProvider(), placeProvider: MockPlaceProvider()),
            settings: DebugSettings(arguments: ["DebugPanel": "YES"])
        )
}
#endif

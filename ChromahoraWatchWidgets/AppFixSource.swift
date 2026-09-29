//
//  AppFixSource.swift
//  ChromahoraWatchWidgets
//

/// Answers no fix, so `DevicePlaceProvider` places a complication at the watch app's last fix,
/// then at the time zone's city. watchOS gives a widget no location of its own, as
/// `CLLocationManager.isAuthorizedForWidgetUpdates`, which the phone's widgets ask, is unavailable there.
struct AppFixSource: LocationSource {
    func updates() -> AsyncStream<LocationUpdate> {
        AsyncStream { $0.finish() }
    }
}

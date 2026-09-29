//
//  WidgetLocationSource.swift
//  ChromahoraWidgets
//

import CoreLocation

/// One fix for a widget, as far as the app's permission lets widgets have one. A widget can't
/// show the permission prompt, so it never waits on one. It reports denied only when the app's
/// own permission is, which forgets the app's last fix too; widgets that aren't allowed while the
/// app is, or an app not asked yet, just get no fix, and the app's last one stands.
struct WidgetLocationSource: LocationSource {
    /// How long a reload waits for a fix before using the stored one. WidgetKit gives a reload
    /// only seconds, and the system tends to answer a widget only soon after it was on screen.
    static let timeout: Duration = .seconds(5)
    /// A fix CoreLocation took this recently answers at once, since places round to 11 km.
    static let freshness: TimeInterval = 15 * 60

    func updates() -> AsyncStream<LocationUpdate> {
        let (updates, continuation) = AsyncStream<LocationUpdate>.makeStream()
        let locator = OneShotLocator(continuation: continuation)
        // Holds the locator, and its manager, until the listener stops.
        continuation.onTermination = { _ in
            Task { @MainActor in
                locator.stop()
            }
        }
        locator.start()
        return updates
    }
}

/// A location manager and its delegate, asking once for a fix.
private final class OneShotLocator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let continuation: AsyncStream<LocationUpdate>.Continuation

    init(continuation: AsyncStream<LocationUpdate>.Continuation) {
        self.continuation = continuation
        super.init()
        manager.delegate = self
    }

    func start() {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            continuation.yield(.denied)
            continuation.finish()
            return
        case .authorizedWhenInUse, .authorizedAlways:
            break
        default:
            continuation.finish()
            return
        }
        guard manager.isAuthorizedForWidgetUpdates else {
            continuation.finish()
            return
        }
        if let location = manager.location, abs(location.timestamp.timeIntervalSinceNow) < WidgetLocationSource.freshness {
            finish(with: location)
            return
        }
        // There's no prompt to wait on, so the timeout starts now.
        continuation.yield(.noFix)
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        manager.requestLocation()
    }

    func stop() {
        manager.delegate = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            finish(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        continuation.finish()
    }

    private nonisolated func finish(with location: CLLocation) {
        continuation.yield(.fix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, takenAt: location.timestamp))
        continuation.finish()
    }
}

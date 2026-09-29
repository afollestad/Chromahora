//
//  CoreLocationSource.swift
//  Chromahora
//

import CoreLocation

/// CoreLocation's live updates, under a When In Use service session, which shows the
/// permission prompt the first time. The app's source only: a widget can't show the prompt, and
/// Apple documents widget location through `CLLocationManager` instead.
struct CoreLocationSource: LocationSource {
    func updates() -> AsyncStream<LocationUpdate> {
        AsyncStream { continuation in
            let task = Task {
                // Held for as long as updates are wanted.
                let session = CLServiceSession(authorization: .whenInUse)
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        continuation.yield(LocationUpdate(update))
                    }
                } catch {
                    // The stream ends either way.
                }
                session.invalidate()
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private extension LocationUpdate {
    init(_ update: CLLocationUpdate) {
        if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
            self = .denied
        } else if update.authorizationRequestInProgress {
            self = .awaitingPermission
        } else if let location = update.location {
            self = .fix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, takenAt: location.timestamp)
        } else {
            self = .noFix
        }
    }
}

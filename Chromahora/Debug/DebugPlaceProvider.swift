//
//  DebugPlaceProvider.swift
//  Chromahora
//

#if DEBUG
import Foundation

/// Wraps the app's place provider so the debug drawer's place override wins.
struct DebugPlaceProvider: PlaceProvider {
    let base: any PlaceProvider
    let settings: DebugSettings

    func lastKnownPlace(in timeZone: TimeZone) -> Place? {
        settings.placeOverride ?? base.lastKnownPlace(in: timeZone)
    }

    func currentPlace(in timeZone: TimeZone) async throws -> Place {
        if let place = settings.placeOverride {
            return place
        }
        return try await base.currentPlace(in: timeZone)
    }
}
#endif

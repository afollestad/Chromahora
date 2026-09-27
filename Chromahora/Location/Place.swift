//
//  Place.swift
//  Chromahora
//

import Foundation

/// Where sun times are worked out for, rounded to a tenth of a degree.
///
/// A tenth of a degree is about 11 km, which moves sun times by well under a minute at
/// mid-latitudes. Rounding lets nearby fixes share cached days, and means no precise
/// location ever leaves the device. Stored as whole tenths so `-0.0` can't split keys.
nonisolated struct Place: Hashable, Codable, Sendable {
    enum Source: Hashable, Codable, Sendable {
        /// A fix from the device's location.
        case device
        /// The reference city of the named time zone, standing in for a location.
        case timeZone(String)
    }

    let latitudeTenths: Int
    let longitudeTenths: Int
    let source: Source

    init(latitude: Double, longitude: Double, source: Source) {
        latitudeTenths = Int((latitude * 10).rounded())
        longitudeTenths = Int((longitude * 10).rounded())
        self.source = source
    }

    var latitude: Double {
        Double(latitudeTenths) / 10
    }

    var longitude: Double {
        Double(longitudeTenths) / 10
    }

    /// Where the times are for, in a phrase for the day picker.
    var summary: String {
        switch source {
        case .device:
            "At your location"
        case .timeZone(let identifier):
            "Approximate, from your time zone (\(Self.cityName(of: identifier)))"
        }
    }

    /// A zone's city, as in "Los Angeles" for `America/Los_Angeles`.
    static func cityName(of timeZoneIdentifier: String) -> String {
        (timeZoneIdentifier.split(separator: "/").last.map(String.init) ?? timeZoneIdentifier)
            .replacingOccurrences(of: "_", with: " ")
    }
}

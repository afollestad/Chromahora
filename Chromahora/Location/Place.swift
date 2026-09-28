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
        /// A place the person searched for, named as they picked it, with the zone its days
        /// are windowed to, since it may lie far from the device's.
        case chosen(name: String, timeZone: String)
    }

    /// What the title names while nothing places the device, as in a zone with no city.
    static let unplacedTitle = "Choose a Place"

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

    /// The name a chosen place was picked by. Nil for the device's own place.
    var name: String? {
        if case .chosen(let name, _) = source { name } else { nil }
    }

    /// The zone a chosen place's days are windowed to. Nil for the device's own place, whose
    /// days follow the device's zone.
    var timeZone: TimeZone? {
        if case .chosen(_, let identifier) = source { TimeZone(identifier: identifier) } else { nil }
    }

    /// What the title calls the place: a chosen place's name, the device's town once
    /// `deviceName` has it, or the time zone's city.
    func title(deviceName: String?) -> String {
        switch source {
        case .device:
            deviceName ?? "Current Location"
        case .timeZone(let identifier):
            Self.cityName(of: identifier)
        case .chosen(let name, _):
            name
        }
    }

    /// The symbol beside the title, which tells the device's place from a stand-in for it. The
    /// stand-in shows while the first permission prompt is up, so it isn't marked as denied.
    var glyph: String? {
        switch source {
        case .device: "location.fill"
        case .timeZone: "location"
        case .chosen: nil
        }
    }

    /// A note under the place in the location sheet: how the time zone stands in for the device,
    /// or the zone a chosen place's times read in. Nil for a device fix, which needs none.
    var note: String? {
        switch source {
        case .device:
            nil
        case .timeZone(let identifier):
            "Approximate, from your time zone (\(Self.cityName(of: identifier)))"
        case .chosen(_, let identifier):
            "Times in \(TimeZone(identifier: identifier)?.localizedName(for: .generic, locale: .current) ?? Self.cityName(of: identifier))"
        }
    }

    /// A zone's city, as in "Los Angeles" for `America/Los_Angeles`.
    static func cityName(of timeZoneIdentifier: String) -> String {
        (timeZoneIdentifier.split(separator: "/").last.map(String.init) ?? timeZoneIdentifier)
            .replacingOccurrences(of: "_", with: " ")
    }
}

//
//  PlaceSearch.swift
//  Chromahora
//

import Foundation

/// A place the search suggests while the person types, before it's looked up.
nonisolated struct PlaceSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    /// What the search needs to look the suggestion up, kept opaque so only the search knows its type.
    let handle: AnyObject?

    init(title: String, subtitle: String, handle: AnyObject? = nil) {
        id = "\(title)\n\(subtitle)"
        self.title = title
        self.subtitle = subtitle
        self.handle = handle
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

/// Finds places by name as the person types, and names the town the device is in.
/// A protocol so previews, tests and snapshots never reach Apple Maps.
protocol PlaceSearch {
    /// Towns, landmarks and features whose names match `query`, best first.
    func suggestions(for query: String) async throws -> [PlaceSuggestion]

    /// The place `suggestion` stands for, named as it was suggested, with its time zone.
    func place(for suggestion: PlaceSuggestion) async throws -> Place

    /// The town `place` lies in, or nil when it lies in none.
    func townName(of place: Place) async throws -> String?
}

nonisolated enum PlaceSearchError: Error, Equatable {
    /// The suggestion no longer leads to a place.
    case notFound
    /// The place has no time zone to window its days to, like a spot out at sea. Guessing one
    /// near a border would shift every time on screen by an hour without a word.
    case noTimeZone
}

/// Answers from a fixed list, for previews and snapshots.
struct MockPlaceSearch: PlaceSearch {
    /// Kyoto, which the chosen place previews and snapshots show.
    static let kyoto = Place(latitude: 35.0, longitude: 135.8, source: .chosen(name: "Kyoto", timeZone: "Asia/Tokyo"))
    /// Reykjavík, a second recent place in previews and snapshots.
    static let reykjavik = Place(latitude: 64.1, longitude: -21.9, source: .chosen(name: "Reykjavík", timeZone: "Atlantic/Reykjavik"))

    /// Each suggestion and where it leads.
    static let places: [(suggestion: PlaceSuggestion, place: Place)] = [
        suggestion("Kyoto", "Japan", kyoto),
        suggestion("Yosemite Valley", "California, United States", latitude: 37.7, longitude: -119.6, zone: "America/Los_Angeles"),
        suggestion("Yokohama", "Kanagawa, Japan", latitude: 35.4, longitude: 139.6, zone: "Asia/Tokyo"),
        suggestion("York", "England", latitude: 54.0, longitude: -1.1, zone: "Europe/London"),
        suggestion("Yorkshire Dales National Park", "England", latitude: 54.2, longitude: -2.1, zone: "Europe/London"),
        suggestion("Reykjavík", "Iceland", reykjavik)
    ]

    /// Thrown by every search while set, as when the device is offline.
    var failure: (any Error)?
    var townName = "San Francisco"

    func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        if let failure {
            throw failure
        }
        return Self.places.map(\.suggestion).filter {
            $0.title.range(of: query, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    func place(for suggestion: PlaceSuggestion) async throws -> Place {
        if let failure {
            throw failure
        }
        guard let place = Self.places.first(where: { $0.suggestion == suggestion })?.place else {
            throw PlaceSearchError.notFound
        }
        return place
    }

    func townName(of place: Place) async throws -> String? {
        if let failure {
            throw failure
        }
        return townName
    }

    private static func suggestion(_ title: String, _ subtitle: String, _ place: Place) -> (PlaceSuggestion, Place) {
        (PlaceSuggestion(title: title, subtitle: subtitle), place)
    }

    private static func suggestion(
        _ title: String,
        _ subtitle: String,
        latitude: Double,
        longitude: Double,
        zone: String
    ) -> (PlaceSuggestion, Place) {
        suggestion(title, subtitle, Place(latitude: latitude, longitude: longitude, source: .chosen(name: title, timeZone: zone)))
    }
}

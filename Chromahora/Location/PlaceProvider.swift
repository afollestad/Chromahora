//
//  PlaceProvider.swift
//  Chromahora
//

import Foundation

/// A source of the place to work sun times out for.
protocol PlaceProvider {
    /// A place to start with before `currentPlace` answers, so a relaunch can draw cached
    /// days at once. Nil when there's nothing to go on yet.
    func lastKnownPlace(in timeZone: TimeZone) -> Place?

    /// Where the device is now, as well as the provider can tell.
    func currentPlace(in timeZone: TimeZone) async throws -> Place
}

nonisolated enum PlaceError: Error, Equatable {
    /// Nothing places the device, and its time zone has no city to stand in, like `GMT`.
    case unavailable(timeZone: String)
}

/// Places the device at its time zone's reference city, which can be off by up to about an
/// hour of sun time in wide zones, but needs no permission.
struct TimeZonePlaceProvider: PlaceProvider {
    var zones: ZoneTable = .bundled

    func lastKnownPlace(in timeZone: TimeZone) -> Place? {
        zones.place(for: timeZone.identifier)
    }

    func currentPlace(in timeZone: TimeZone) async throws -> Place {
        guard let place = lastKnownPlace(in: timeZone) else {
            throw PlaceError.unavailable(timeZone: timeZone.identifier)
        }
        return place
    }
}

/// Always answers with `place`, for previews and tests.
struct MockPlaceProvider: PlaceProvider {
    /// Central San Francisco.
    static let sanFrancisco = Place(latitude: 37.8, longitude: -122.4, source: .device)

    var place = Self.sanFrancisco

    func lastKnownPlace(in timeZone: TimeZone) -> Place? {
        place
    }

    func currentPlace(in timeZone: TimeZone) async throws -> Place {
        place
    }
}

/// Each time zone's reference city, from IANA's `zone.tab` and the links in `tzdata.zi`.
///
/// iOS still reports some old names that `zone.tab` has dropped, like `Asia/Calcutta` for
/// `Asia/Kolkata`, so links resolve to a current zone before the lookup.
nonisolated struct ZoneTable: Sendable {
    private let coordinates: [String: (latitude: Double, longitude: Double)]
    private let links: [String: String]

    /// The copies bundled in `Location/`. Empty if they're missing, so lookups fail
    /// rather than crash.
    static let bundled: ZoneTable = {
        func contents(_ name: String, _ ext: String) -> String {
            Bundle.main.url(forResource: name, withExtension: ext)
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        }
        return ZoneTable(zoneTab: contents("zone", "tab"), links: contents("zone-links", "txt"))
    }()

    /// `zoneTab` has `zone.tab`'s tab-separated lines, and `links` has `tzdata.zi`'s
    /// `L target link` lines. Lines it can't read are skipped.
    init(zoneTab: String, links: String) {
        var coordinates: [String: (latitude: Double, longitude: Double)] = [:]
        for line in zoneTab.split(separator: "\n") where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t")
            if fields.count >= 3, let position = Self.position(iso6709: fields[1]) {
                coordinates[String(fields[2])] = position
            }
        }
        self.coordinates = coordinates

        var targets: [String: String] = [:]
        for line in links.split(separator: "\n") {
            let fields = line.split(separator: " ")
            if fields.count == 3, fields[0] == "L" {
                targets[String(fields[2])] = String(fields[1])
            }
        }
        self.links = targets
    }

    func place(for identifier: String) -> Place? {
        // Links can chain; a handful of hops covers every real one.
        var zone = identifier
        for _ in 0..<5 where coordinates[zone] == nil {
            guard let target = links[zone] else {
                break
            }
            zone = target
        }
        return coordinates[zone].map { Place(latitude: $0.latitude, longitude: $0.longitude, source: .timeZone(identifier)) }
    }

    /// Reads ISO 6709 degrees and minutes, with optional seconds, as `zone.tab` writes
    /// them: `+4230+00131` or `+404251-0740023`.
    static func position(iso6709 text: Substring) -> (latitude: Double, longitude: Double)? {
        guard let split = text.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }),
              let latitude = degrees(text[..<split], wholeDegreeDigits: 2),
              let longitude = degrees(text[split...], wholeDegreeDigits: 3) else {
            return nil
        }
        return (latitude, longitude)
    }

    private static func degrees(_ text: Substring, wholeDegreeDigits: Int) -> Double? {
        guard let sign = text.first, sign == "+" || sign == "-" else {
            return nil
        }
        let digits = Array(text.dropFirst())
        guard digits.count == wholeDegreeDigits + 2 || digits.count == wholeDegreeDigits + 4,
              digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber) else {
            return nil
        }
        func number(_ range: Range<Int>) -> Double {
            Double(String(digits[range])) ?? 0
        }
        let minutesEnd = wholeDegreeDigits + 2
        let seconds = digits.count > minutesEnd ? number(minutesEnd..<digits.count) : 0
        let value = number(0..<wholeDegreeDigits) + number(wholeDegreeDigits..<minutesEnd) / 60 + seconds / 3600
        return sign == "-" ? -value : value
    }
}

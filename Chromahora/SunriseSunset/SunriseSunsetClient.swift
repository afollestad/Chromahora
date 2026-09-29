//
//  SunriseSunsetClient.swift
//  Chromahora
//

import Foundation

nonisolated enum SunriseSunsetError: Error, Equatable {
    /// The API asked for a pause, for `retryAfter` seconds when it said how long.
    case rateLimited(retryAfter: TimeInterval?)
    case badResponse(status: Int)
    /// The response left out the day, which the API warns a range can do.
    case missingDay
}

/// Fetches days from sunrise-sunset.org. A protocol so tests can answer instead.
protocol SunriseSunsetFetching {
    /// Every day of `month` at `place`, windowed to `month`'s time zone.
    func records(for month: CalendarMonth, at place: Place) async throws -> [SolarDayRecord]
}

struct SunriseSunsetClient: SunriseSunsetFetching {
    /// The site sunrise-sunset.org's terms ask every credit to link back to.
    nonisolated static let siteURL = URL(string: "https://sunrise-sunset.org")

    private struct Response: Decodable {
        let days: [SolarDayRecord]
    }

    /// Ephemeral, so `URLCache` keeps no second copy of the months `SolarDayCache` already
    /// stores. The API marks them immutable, which would otherwise let a stale copy answer
    /// the debug drawer's cold reload.
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()

    func records(for month: CalendarMonth, at place: Place) async throws -> [SolarDayRecord] {
        let (data, response) = try await session.data(from: Self.url(for: month, at: place))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 429 {
            let retryAfter = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw SunriseSunsetError.rateLimited(retryAfter: retryAfter)
        }
        guard (200..<300).contains(status) else {
            throw SunriseSunsetError.badResponse(status: status)
        }
        return try Self.records(from: data)
    }

    /// The days in a range response's body.
    static func records(from data: Data) throws -> [SolarDayRecord] {
        try SolarDayRecord.makeDecoder().decode(Response.self, from: data).days
    }

    /// `tz` makes each day run midnight to midnight in the device's zone, matching the
    /// timeline, and `time_format=unix` gives instants that need no zone to read.
    static func url(for month: CalendarMonth, at place: Place) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.sunrise-sunset.org"
        components.path = "/v2"
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(place.latitude)),
            URLQueryItem(name: "lng", value: String(place.longitude)),
            URLQueryItem(name: "date_start", value: month.firstDay),
            URLQueryItem(name: "date_end", value: month.lastDay),
            URLQueryItem(name: "tz", value: month.timeZone.identifier),
            URLQueryItem(name: "time_format", value: "unix")
        ]
        // Every part above is fixed or formatted here, so the URL always forms.
        return components.url ?? URL(fileURLWithPath: "/")
    }
}

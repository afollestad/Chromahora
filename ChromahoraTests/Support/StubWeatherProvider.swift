//
//  StubWeatherProvider.swift
//  ChromahoraTests
//

import Foundation
@testable import Chromahora

/// Stands in for WeatherKit. It answers with `forecast` right away, or while `holdsResponses`
/// is set, parks each request until the test answers it.
@MainActor
final class StubWeatherProvider: WeatherProvider {
    struct Request {
        fileprivate let continuation: CheckedContinuation<Forecast, any Error>

        func answer(_ forecast: Forecast) {
            continuation.resume(returning: forecast)
        }

        func fail(with error: any Error) {
            continuation.resume(throwing: error)
        }
    }

    var forecast = Forecast()
    /// Thrown for every request while set.
    var error: (any Error)?
    var holdsResponses = false
    /// The window of every request, in order, including ones that failed.
    private(set) var requestedWindows: [DateInterval] = []
    /// The place of each request, in the same order.
    private(set) var requestedPlaces: [Place] = []
    /// Requests parked while `holdsResponses` is set, in the order they arrived.
    let heldRequests: AsyncStream<Request>
    private let heldRequestsContinuation: AsyncStream<Request>.Continuation

    init() {
        (heldRequests, heldRequestsContinuation) = AsyncStream.makeStream()
    }

    func forecast(from start: Date, to end: Date, at place: Place) async throws -> Forecast {
        requestedWindows.append(DateInterval(start: start, end: end))
        requestedPlaces.append(place)
        if let error {
            throw error
        }
        guard holdsResponses else {
            return forecast
        }
        return try await withCheckedThrowingContinuation { continuation in
            heldRequestsContinuation.yield(Request(continuation: continuation))
        }
    }
}

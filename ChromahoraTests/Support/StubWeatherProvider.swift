//
//  StubWeatherProvider.swift
//  ChromahoraTests
//

import Foundation
@testable import Chromahora

/// Stands in for WeatherKit. It answers with `spells` right away, or while `holdsResponses`
/// is set, parks each request until the test answers it.
@MainActor
final class StubWeatherProvider: WeatherProvider {
    struct Request {
        fileprivate let continuation: CheckedContinuation<[WeatherSpell], any Error>

        func answer(_ spells: [WeatherSpell]) {
            continuation.resume(returning: spells)
        }

        func fail(with error: any Error) {
            continuation.resume(throwing: error)
        }
    }

    var spells: [WeatherSpell] = []
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

    func spells(from start: Date, to end: Date, at place: Place) async throws -> [WeatherSpell] {
        requestedWindows.append(DateInterval(start: start, end: end))
        requestedPlaces.append(place)
        if let error {
            throw error
        }
        guard holdsResponses else {
            return spells
        }
        return try await withCheckedThrowingContinuation { continuation in
            heldRequestsContinuation.yield(Request(continuation: continuation))
        }
    }
}

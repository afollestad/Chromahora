//
//  StubPlaceProvider.swift
//  ChromahoraTests
//

import Foundation
@testable import Chromahora

/// Stands in for a real place provider. It answers with `current` right away, or while
/// `holdsResponses` is set, parks each request until the test answers it.
@MainActor
final class StubPlaceProvider: PlaceProvider {
    struct Request {
        fileprivate let continuation: CheckedContinuation<Place, any Error>

        func answer(_ place: Place) {
            continuation.resume(returning: place)
        }

        func fail(with error: any Error) {
            continuation.resume(throwing: error)
        }
    }

    /// San Francisco by default, so a store starts with a place, as it does after a first launch.
    var lastKnown: Place? = MockPlaceProvider.sanFrancisco
    var current = MockPlaceProvider.sanFrancisco
    /// Thrown for every request while set.
    var error: (any Error)?
    var holdsResponses = false
    /// The zone of each `currentPlace` request, in order.
    private(set) var requestedTimeZones: [TimeZone] = []
    let heldRequests: AsyncStream<Request>
    private let heldRequestsContinuation: AsyncStream<Request>.Continuation

    init() {
        (heldRequests, heldRequestsContinuation) = AsyncStream.makeStream()
    }

    func lastKnownPlace(in timeZone: TimeZone) -> Place? {
        lastKnown
    }

    func currentPlace(in timeZone: TimeZone) async throws -> Place {
        requestedTimeZones.append(timeZone)
        if let error {
            throw error
        }
        guard holdsResponses else {
            return current
        }
        return try await withCheckedThrowingContinuation { continuation in
            heldRequestsContinuation.yield(Request(continuation: continuation))
        }
    }
}

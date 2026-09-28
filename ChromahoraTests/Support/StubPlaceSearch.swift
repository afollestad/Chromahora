//
//  StubPlaceSearch.swift
//  ChromahoraTests
//

import Foundation
@testable import Chromahora

/// Stands in for Apple Maps' search. It names every town `townName` right away, or while
/// `holdsResponses` is set, parks each lookup until the test answers it. A cancelled lookup
/// throws, as MapKit's does.
@MainActor
final class StubPlaceSearch: PlaceSearch {
    final class Request {
        fileprivate var continuation: CheckedContinuation<String?, any Error>?

        func answer(_ name: String?) {
            continuation?.resume(returning: name)
            continuation = nil
        }

        fileprivate func cancel() {
            continuation?.resume(throwing: CancellationError())
            continuation = nil
        }
    }

    var townName: String? = "San Francisco"
    /// Thrown for every lookup while set.
    var error: (any Error)?
    var holdsResponses = false
    /// The place of each town lookup, in order.
    private(set) var townNameRequests: [Place] = []
    let heldRequests: AsyncStream<Request>
    private let heldRequestsContinuation: AsyncStream<Request>.Continuation

    init() {
        (heldRequests, heldRequestsContinuation) = AsyncStream.makeStream()
    }

    func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        []
    }

    func place(for suggestion: PlaceSuggestion) async throws -> Place {
        throw PlaceSearchError.notFound
    }

    func townName(of place: Place) async throws -> String? {
        townNameRequests.append(place)
        if let error {
            throw error
        }
        guard holdsResponses else {
            return townName
        }
        let request = Request()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                request.continuation = continuation
                heldRequestsContinuation.yield(request)
            }
        } onCancel: {
            Task { @MainActor in
                request.cancel()
            }
        }
    }
}

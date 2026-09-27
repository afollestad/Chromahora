//
//  StubSolarDayProvider.swift
//  ChromahoraTests
//

import Foundation
@testable import Chromahora

struct StubError: Error {}

/// Stands in for a real provider. It answers with mock data right away, or while
/// `holdsResponses` is set, parks each request until the test answers it, so a
/// test decides exactly when, and in which order, responses arrive.
@MainActor
final class StubSolarDayProvider: SolarDayProvider {
    struct Request {
        let day: SolarDay
        fileprivate let continuation: CheckedContinuation<SolarDay, any Error>

        func answer() {
            continuation.resume(returning: day)
        }

        func fail(with error: any Error) {
            continuation.resume(throwing: error)
        }
    }

    var holdsResponses = false
    /// The day shape to answer each place with, so tests can tell places' days apart.
    var scenarios: [Place: MockScenario] = [:]
    /// Thrown for every request while set.
    var error: (any Error)?
    /// Every date asked for, in order, including ones that failed.
    private(set) var requestedDates: [Date] = []
    /// The place of each request, in the same order.
    private(set) var requestedPlaces: [Place] = []
    /// Requests parked while `holdsResponses` is set, in the order they arrived.
    let heldRequests: AsyncStream<Request>
    private let heldRequestsContinuation: AsyncStream<Request>.Continuation

    init() {
        (heldRequests, heldRequestsContinuation) = AsyncStream.makeStream()
    }

    func solarDay(for date: Date, at place: Place, calendar: Calendar) async throws -> SolarDay {
        requestedDates.append(date)
        requestedPlaces.append(place)
        if let error {
            throw error
        }
        let day = SolarDay.mock(scenarios[place] ?? .typical, for: date, calendar: calendar)
        guard holdsResponses else {
            return day
        }
        return try await withCheckedThrowingContinuation { continuation in
            heldRequestsContinuation.yield(Request(day: day, continuation: continuation))
        }
    }
}

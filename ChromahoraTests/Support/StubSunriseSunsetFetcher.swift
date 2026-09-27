//
//  StubSunriseSunsetFetcher.swift
//  ChromahoraTests
//

import Foundation
@testable import Chromahora

/// Stands in for the API. It answers every day of a month with daylight right away, or
/// while `holdsResponses` is set, parks each request until the test answers it.
@MainActor
final class StubSunriseSunsetFetcher: SunriseSunsetFetching {
    struct Request {
        let month: CalendarMonth
        let records: [SolarDayRecord]
        fileprivate let continuation: CheckedContinuation<[SolarDayRecord], any Error>

        func answer() {
            continuation.resume(returning: records)
        }
    }

    var holdsResponses = false
    /// Thrown for every request while set.
    var error: (any Error)?
    /// Days, as `yyyy-MM-dd`, to leave out of answers.
    var omittedDays: Set<String> = []
    /// Every month asked for, in order, including ones that failed.
    private(set) var requestedMonths: [CalendarMonth] = []
    let heldRequests: AsyncStream<Request>
    private let heldRequestsContinuation: AsyncStream<Request>.Continuation

    init() {
        (heldRequests, heldRequestsContinuation) = AsyncStream.makeStream()
    }

    func records(for month: CalendarMonth, at place: Place) async throws -> [SolarDayRecord] {
        requestedMonths.append(month)
        if let error {
            throw error
        }
        let records = Self.daylight(through: month).filter { !omittedDays.contains($0.date) }
        guard holdsResponses else {
            return records
        }
        return try await withCheckedThrowingContinuation { continuation in
            heldRequestsContinuation.yield(Request(month: month, records: records, continuation: continuation))
        }
    }

    /// A record for each day of `month`, with the sun above +6° all day.
    nonisolated static func daylight(through month: CalendarMonth) -> [SolarDayRecord] {
        let lastDay = Int(month.lastDay.suffix(2)) ?? 28
        let none = SolarDayRecord.Twilight(morning: .init(begin: nil, end: nil), evening: .init(begin: nil, end: nil))
        return (1...lastDay).map { day in
            SolarDayRecord(
                date: String(format: "%@-%02d", month.name, day),
                sunrise: nil,
                sunset: nil,
                goldenHour: none,
                blueHour: none,
                solarPosition: .init(solarNoonAltitude: 40)
            )
        }
    }
}
